//
//  WhisperKitService.swift
//  Sponge
//
//  Offline transcription using WhisperKit (openai/whisper-small).
//  Replaces the Apple SpeechAnalyzer offline pass for higher accuracy.
//

import Foundation
import WhisperKit

/// A Codable mirror of WhisperKit's TranscriptionSegment, stored per-recording for future use
/// (e.g. timestamped transcript display, audio playback sync, precise catch-up summaries).
struct WhisperSegment: Codable {
    let start: Float   // seconds from start of audio
    let end: Float     // seconds from start of audio
    let text: String
}

@MainActor
class WhisperKitService: ObservableObject {
    static let shared = WhisperKitService()

    @Published var isDownloadingModel: Bool = false
    @Published var downloadProgress: Double = 0
    @Published var modelReady: Bool = false

    private var pipe: WhisperKit?
    private let modelName = "openai_whisper-small"

    private init() {}

    /// Loads the model if not already loaded. Downloads on first call (~600MB, cached after).
    func loadModelIfNeeded() async throws {
        guard pipe == nil else { return }

        isDownloadingModel = true
        downloadProgress = 0

        defer { isDownloadingModel = false }

        let config = WhisperKitConfig(model: modelName)
        let kit = try await WhisperKit(config)
        pipe = kit
        modelReady = true
    }

    /// Transcribes the audio file at the given URL. Loads the model first if needed.
    /// Returns the clean transcript text and segment-level timestamps for future use.
    func transcribe(audioURL: URL) async throws -> (text: String, segments: [WhisperSegment]) {
        try await loadModelIfNeeded()

        guard let pipe else {
            throw TranscriptionError.modelNotLoaded
        }

        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.fileNotFound
        }

        let options = DecodingOptions(
            task: .transcribe,
            language: "en",
            skipSpecialTokens: true,   // removes <|startoftranscript|>, <|0.00|>, etc.
            withoutTimestamps: false    // keep timestamps in segments (not in text)
        )

        print("WhisperKitService: Transcribing \(audioURL.lastPathComponent)...")
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)

        // Build clean text by joining segment text (avoids timestamp tokens leaking into prose)
        let segments: [WhisperSegment] = results.flatMap { result in
            result.segments.map { seg in
                WhisperSegment(
                    start: seg.start,
                    end: seg.end,
                    text: seg.text.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        }

        let text = segments
            .map(\.text)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        print("WhisperKitService: Done — \(text.count) chars, \(segments.count) segments")
        return (text: text, segments: segments)
    }

    enum TranscriptionError: LocalizedError {
        case modelNotLoaded
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded: return "Whisper model failed to load."
            case .fileNotFound: return "Audio file not found."
            }
        }
    }
}
