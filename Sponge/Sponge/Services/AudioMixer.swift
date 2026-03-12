import AVFoundation
import Accelerate

/// Mixes microphone and system audio sample-by-sample using vDSP.
/// Thread-safe: system audio is written from the SCStream delegate thread,
/// mic buffers are read and mixed from the AVAudioEngine tap thread.
class AudioMixer {

    /// When false, `mix()` returns the mic buffer unchanged (lecture mode passthrough).
    var isMixingEnabled: Bool = false

    // Ring buffer: ~1.5 seconds at 44.1kHz (65536 frames)
    private let ringCapacity = 65536
    private var ringBuffer: [Float]
    private var writeIndex = 0
    private var readIndex = 0
    private var framesAvailable = 0

    private let queue = DispatchQueue(label: "com.sponge.audiomixer", attributes: .concurrent)

    init() {
        ringBuffer = [Float](repeating: 0, count: 65536)
    }

    // MARK: - System Audio Input (SCStream thread)

    /// Called from the SCStream delegate thread with downmixed mono Float32 frames.
    func appendSystemAudio(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        queue.async(flags: .barrier) { [self] in
            for i in 0..<frameCount {
                if framesAvailable == ringCapacity {
                    // Overrun: drop oldest sample by advancing read pointer
                    readIndex = (readIndex + 1) % ringCapacity
                    framesAvailable -= 1
                }
                ringBuffer[writeIndex] = channelData[i]
                writeIndex = (writeIndex + 1) % ringCapacity
                framesAvailable += 1
            }
        }
    }

    // MARK: - Mixed Output (AVAudioEngine tap thread)

    /// Mixes `micBuffer` with available system audio frames.
    /// Returns a new PCMBuffer containing the mix. Fills silence for underrun.
    func mix(micBuffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        guard isMixingEnabled,
              let micData = micBuffer.floatChannelData?[0] else {
            return micBuffer
        }

        let frameCount = Int(micBuffer.frameLength)
        guard frameCount > 0 else { return micBuffer }

        // Read system audio frames from ring buffer (may be fewer than frameCount on underrun)
        var systemFrames = [Float](repeating: 0, count: frameCount)
        queue.sync {
            let available = min(framesAvailable, frameCount)
            for i in 0..<available {
                systemFrames[i] = ringBuffer[readIndex]
                readIndex = (readIndex + 1) % ringCapacity
            }
            framesAvailable -= available
            // Frames beyond `available` stay 0 (silence = underrun fill)
        }

        // Create output buffer with same format as mic
        guard let output = AVAudioPCMBuffer(pcmFormat: micBuffer.format, frameCapacity: micBuffer.frameCapacity),
              let outData = output.floatChannelData?[0] else {
            return micBuffer
        }
        output.frameLength = micBuffer.frameLength

        // Mix: output = mic + system, then clamp to [-1, 1]
        systemFrames.withUnsafeBufferPointer { systemPtr in
            vDSP_vadd(micData, 1, systemPtr.baseAddress!, 1, outData, 1, vDSP_Length(frameCount))
        }

        var lowerBound: Float = -1.0
        var upperBound: Float = 1.0
        vDSP_vclip(outData, 1, &lowerBound, &upperBound, outData, 1, vDSP_Length(frameCount))

        return output
    }

    // MARK: - Reset

    func reset() {
        queue.async(flags: .barrier) { [self] in
            writeIndex = 0
            readIndex = 0
            framesAvailable = 0
            // No need to zero the buffer — framesAvailable=0 means all reads return silence
        }
    }
}
