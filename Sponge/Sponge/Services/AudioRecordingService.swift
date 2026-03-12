import Foundation
import AVFoundation

enum RecordingState {
    case idle
    case recording
    case paused
}

class AudioRecordingService: NSObject, ObservableObject {
    @Published var recordingState: RecordingState = .idle
    @Published var currentDuration: TimeInterval = 0
    @Published var lastError: String?

    private var timer: Timer?
    private var pausedDuration: TimeInterval = 0
    private var recordingStartTime: Date?

    private var currentFileURL: URL?

    override init() {
        super.init()
        setupRecordingsDirectory()
    }

    private func setupRecordingsDirectory() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")

        if !FileManager.default.fileExists(atPath: recordingsPath.path) {
            try? FileManager.default.createDirectory(at: recordingsPath, withIntermediateDirectories: true)
        }
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        default:
            completion(false)
        }
    }

    func startRecording(meetingMode: Bool = false) -> URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsPath = documentsPath.appendingPathComponent("Recordings")

        // Use .m4a format (AAC) which works well with macOS
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = recordingsPath.appendingPathComponent(fileName)

        print("AudioRecordingService: Attempting to start recording to \(fileURL.path) (meetingMode=\(meetingMode))")

        // Use SharedAudioManager to avoid conflicts with transcription's AVAudioEngine
        do {
            try SharedAudioManager.shared.startAudioEngine(recordingToURL: fileURL, meetingMode: meetingMode)

            currentFileURL = fileURL
            recordingState = .recording
            recordingStartTime = Date()
            pausedDuration = 0
            startTimer()

            print("AudioRecordingService: Recording started successfully")
            return fileURL
        } catch {
            let errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("AudioRecordingService: \(errorMessage)")
            lastError = errorMessage
            return nil
        }
    }

    func pauseRecording() {
        guard recordingState == .recording else { return }

        SharedAudioManager.shared.pauseAudioEngine()

        recordingState = .paused
        stopTimer()

        if recordingStartTime != nil {
            pausedDuration = currentDuration
        }
    }

    func resumeRecording() {
        guard recordingState == .paused else { return }

        try? SharedAudioManager.shared.resumeAudioEngine()

        recordingState = .recording
        recordingStartTime = Date()
        startTimer()
    }

    func stopRecording() -> (url: URL, duration: TimeInterval)? {
        guard let fileURL = SharedAudioManager.shared.stopAudioEngine() ?? currentFileURL else { return nil }

        stopTimer()
        let finalDuration = currentDuration

        recordingState = .idle
        currentDuration = 0
        pausedDuration = 0
        recordingStartTime = nil
        currentFileURL = nil

        return (fileURL, finalDuration)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentDuration = self.pausedDuration + Date().timeIntervalSince(startTime)
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
