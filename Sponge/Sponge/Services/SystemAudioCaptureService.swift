import Foundation
import ScreenCaptureKit
import AVFoundation
import CoreMedia

/// Captures system audio (from any app) using ScreenCaptureKit.
/// Delivers raw CMSampleBuffer frames via `audioSampleBufferHandler`.
/// Does not capture video — audio only.
class SystemAudioCaptureService: NSObject {

    var audioSampleBufferHandler: ((CMSampleBuffer) -> Void)?

    private var stream: SCStream?
    private(set) var isCapturing = false

    // MARK: - Permission

    /// Returns true if Screen Recording permission is granted.
    /// On first call this triggers the system permission prompt.
    static func checkPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            print("SystemAudioCapture: Permission denied or unavailable: \(error)")
            return false
        }
    }

    // MARK: - Lifecycle

    func startCapture() async throws {
        guard !isCapturing else { return }

        // Must get shareable content to build a valid SCContentFilter.
        // This also triggers the permission prompt on first run.
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw NSError(domain: "SystemAudioCapture", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No display found for SCContentFilter"])
        }

        let filter = SCContentFilter(display: display, excludingWindows: [])

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true // Don't loop back Sponge's own audio
        config.sampleRate = 44100
        config.channelCount = 2

        // We don't need video — set minimal dimensions to reduce overhead
        config.width = 2
        config.height = 2

        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: DispatchQueue(label: "com.sponge.syscapture.audio"))
        try await newStream.startCapture()

        stream = newStream
        isCapturing = true
        print("SystemAudioCapture: Started capturing system audio")
    }

    func stopCapture() {
        guard isCapturing else { return }
        stream?.stopCapture { error in
            if let error = error {
                print("SystemAudioCapture: Error stopping stream: \(error)")
            }
        }
        stream = nil
        isCapturing = false
        print("SystemAudioCapture: Stopped")
    }
}

// MARK: - SCStreamOutput

extension SystemAudioCaptureService: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        guard CMSampleBufferIsValid(sampleBuffer) else { return }
        audioSampleBufferHandler?(sampleBuffer)
    }
}
