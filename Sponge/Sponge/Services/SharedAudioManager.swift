//
//  SharedAudioManager.swift
//  Sponge
//
//  Manages shared audio input on macOS to prevent conflicts between
//  AVAudioRecorder and AVAudioEngine when both recording and transcription
//  need microphone access simultaneously.
//

import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia
import Accelerate

/// Singleton that manages shared audio engine access on macOS
/// This prevents conflicts when both recording and transcription need the microphone
class SharedAudioManager {
    static let shared = SharedAudioManager()

    private(set) var audioEngine: AVAudioEngine?

    // Thread-safe state protected by audioStateQueue (accessed from audio thread via installTap)
    private let audioStateQueue = DispatchQueue(label: "com.sponge.sharedaudio.state")
    private var _audioFile: AVAudioFile?
    private var _isRecording = false
    private var _outputFormat: AVAudioFormat?

    private var audioFile: AVAudioFile? {
        get { audioStateQueue.sync { _audioFile } }
        set { audioStateQueue.sync { _audioFile = newValue } }
    }
    private var isRecording: Bool {
        get { audioStateQueue.sync { _isRecording } }
        set { audioStateQueue.sync { _isRecording = newValue } }
    }
    private var outputFormat: AVAudioFormat? {
        get { audioStateQueue.sync { _outputFormat } }
        set { audioStateQueue.sync { _outputFormat = newValue } }
    }

    private var recordingURL: URL?
    private var audioConverter: AVAudioConverter?

    // Meeting mode: captures system audio and mixes with mic
    private let systemAudioCapture = SystemAudioCaptureService()
    private let audioMixer = AudioMixer()

    // Callbacks for transcription service to receive audio buffers
    var transcriptionBufferHandler: ((AVAudioPCMBuffer) -> Void)?

    private init() {}

    /// Starts the shared audio engine and optionally begins recording to file.
    /// Set `meetingMode: true` to also capture system audio via ScreenCaptureKit.
    func startAudioEngine(recordingToURL url: URL?, meetingMode: Bool = false) throws {
        // Stop any existing engine
        _ = stopAudioEngine()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw NSError(domain: "SharedAudioManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"])
        }

        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        print("SharedAudioManager: Input format - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)")

        // Validate input format
        guard inputFormat.sampleRate > 0 && inputFormat.channelCount > 0 else {
            throw NSError(domain: "SharedAudioManager", code: -2,
                         userInfo: [NSLocalizedDescriptionKey: "Invalid input format - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount)"])
        }

        // If recording, create the audio file
        if let url = url {
            print("SharedAudioManager: Creating audio file at \(url.path)")
            print("SharedAudioManager: Input format details - sampleRate: \(inputFormat.sampleRate), channels: \(inputFormat.channelCount), commonFormat: \(inputFormat.commonFormat.rawValue), interleaved: \(inputFormat.isInterleaved)")

            // Use M4A/AAC format which works better with sandboxed apps
            // This avoids the HAL proxy issues with PCM recording
            let fileSettings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                AVEncoderBitRateKey: 128000
            ]

            print("SharedAudioManager: File settings: \(fileSettings)")

            // Create a processing format for writing - must be PCM for the tap
            guard let processingFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false) else {
                throw NSError(domain: "SharedAudioManager", code: -3,
                             userInfo: [NSLocalizedDescriptionKey: "Failed to create processing format"])
            }

            outputFormat = processingFormat

            // Create converter from input format to processing format
            if inputFormat.sampleRate != processingFormat.sampleRate || inputFormat.channelCount != processingFormat.channelCount {
                audioConverter = AVAudioConverter(from: inputFormat, to: processingFormat)
                print("SharedAudioManager: Created audio converter")
            }

            audioFile = try AVAudioFile(forWriting: url, settings: fileSettings, commonFormat: .pcmFormatFloat32, interleaved: false)
            recordingURL = url
            isRecording = true
            print("SharedAudioManager: Audio file created successfully")
        }

        // Capture values for closure
        let inputSampleRate = inputFormat.sampleRate

        // Install tap that handles both recording and transcription
        inputNode.installTap(onBus: 0, bufferSize: 8192, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Snapshot thread-safe state once per callback
            let (recording, file, outFormat): (Bool, AVAudioFile?, AVAudioFormat?) = self.audioStateQueue.sync {
                (self._isRecording, self._audioFile, self._outputFormat)
            }

            // Mix system audio into mic buffer if meeting mode is active
            let mixedBuffer = self.audioMixer.mix(micBuffer: buffer)

            // Write to file if recording
            if recording, let audioFile = file, let outFormat = outFormat {
                do {
                    // Convert buffer if necessary
                    if let converter = self.audioConverter {
                        let ratio = outFormat.sampleRate / inputSampleRate
                        let frameCount = AVAudioFrameCount(Double(mixedBuffer.frameLength) * ratio)
                        guard frameCount > 0,
                              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: frameCount) else { return }

                        var error: NSError?
                        var hasData = true
                        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                            if hasData {
                                hasData = false
                                outStatus.pointee = .haveData
                                return mixedBuffer
                            } else {
                                outStatus.pointee = .noDataNow
                                return nil
                            }
                        }

                        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

                        if let error = error {
                            print("SharedAudioManager: Conversion error: \(error)")
                        } else if convertedBuffer.frameLength > 0 {
                            try audioFile.write(from: convertedBuffer)
                        }
                    } else {
                        try audioFile.write(from: mixedBuffer)
                    }
                } catch {
                    print("SharedAudioManager: Error writing to file: \(error)")
                }
            }

            // Send mixed buffer to transcription handler
            self.transcriptionBufferHandler?(mixedBuffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        print("SharedAudioManager: Audio engine started successfully")

        // Start system audio capture AFTER engine is running (consumer before producer)
        if meetingMode {
            audioMixer.isMixingEnabled = true
            systemAudioCapture.audioSampleBufferHandler = { [weak self] cmBuffer in
                self?.handleSystemAudioBuffer(cmBuffer)
            }
            Task {
                do {
                    try await systemAudioCapture.startCapture()
                    print("SharedAudioManager: System audio capture started")
                } catch {
                    print("SharedAudioManager: Failed to start system audio capture: \(error)")
                }
            }
        } else {
            audioMixer.isMixingEnabled = false
        }
    }

    /// Pauses audio capture (for pause recording functionality)
    func pauseAudioEngine() {
        audioEngine?.pause()
    }

    /// Resumes audio capture after pause
    func resumeAudioEngine() throws {
        try audioEngine?.start()
    }

    /// Stops the audio engine and finalizes any recording
    @discardableResult
    func stopAudioEngine() -> URL? {
        // Stop system audio producer before stopping engine consumer
        systemAudioCapture.stopCapture()
        systemAudioCapture.audioSampleBufferHandler = nil
        audioMixer.reset()
        audioMixer.isMixingEnabled = false

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil

        let url = recordingURL
        audioFile = nil
        recordingURL = nil
        isRecording = false
        outputFormat = nil
        audioConverter = nil

        return url
    }

    // MARK: - System Audio Handling

    /// Converts a CMSampleBuffer from SCStream to AVAudioPCMBuffer,
    /// downmixes stereo to mono, and feeds into the AudioMixer ring buffer.
    private func handleSystemAudioBuffer(_ cmBuffer: CMSampleBuffer) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(cmBuffer) else { return }

        let streamFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)
        guard var asbd = streamFormat?.pointee else { return }

        // Build AVAudioFormat from the actual stream format (may be 44.1kHz or 48kHz stereo)
        guard let sourceFormat = AVAudioFormat(streamDescription: &asbd) else { return }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(cmBuffer))
        guard frameCount > 0 else { return }

        // Copy PCM data from CMSampleBuffer into an AVAudioPCMBuffer
        guard let sourcePCM = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else { return }
        sourcePCM.frameLength = frameCount

        var audioBufferList = AudioBufferList()
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            cmBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
            blockBufferOut: &blockBuffer
        )

        guard status == noErr else {
            print("SharedAudioManager: Failed to get audio buffer list: \(status)")
            return
        }

        // Copy channel data
        let channelCount = Int(asbd.mChannelsPerFrame)
        guard let mBuffers = UnsafeMutableAudioBufferListPointer(&audioBufferList).first,
              let srcData = mBuffers.mData else { return }

        // Downmix stereo to mono: mono[i] = (L[i] + R[i]) * 0.5
        // For interleaved stereo: samples are [L0, R0, L1, R1, ...]
        guard let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: asbd.mSampleRate,
                                             channels: 1,
                                             interleaved: false),
              let monoPCM = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: frameCount),
              let monoData = monoPCM.floatChannelData?[0] else { return }
        monoPCM.frameLength = frameCount

        let srcFloats = srcData.bindMemory(to: Float.self, capacity: Int(frameCount) * channelCount)

        if channelCount == 2 {
            // Deinterleave and mix L+R * 0.5
            for i in 0..<Int(frameCount) {
                monoData[i] = (srcFloats[i * 2] + srcFloats[i * 2 + 1]) * 0.5
            }
        } else {
            // Already mono — copy directly
            for i in 0..<Int(frameCount) {
                monoData[i] = srcFloats[i]
            }
        }

        audioMixer.appendSystemAudio(monoPCM)
    }

    /// Returns the input format for transcription services to use
    var inputFormat: AVAudioFormat? {
        return audioEngine?.inputNode.outputFormat(forBus: 0)
    }
}
