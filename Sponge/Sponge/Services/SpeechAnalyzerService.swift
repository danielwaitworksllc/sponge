//
//  SpeechAnalyzerService.swift
//  Sponge
//
//  Voice Memos-level transcription using macOS 26+ SpeechAnalyzer API
//

import Foundation
import Speech
import AVFoundation

class SpeechAnalyzerService: ObservableObject {
    @Published var transcribedText: String = ""
    @Published var isTranscribing: Bool = false
    @Published var error: String?

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?
    private var isStoppingIntentionally = false

    // Audio format conversion
    private var audioConverter: AVAudioConverter?
    private var analyzerFormat: AVAudioFormat?

    // Accumulates text across transcriber restarts to prevent words from disappearing
    private var baseTranscript: String = ""
    private var lastResultLength: Int = 0

    init() {
        // Format will be negotiated dynamically via SpeechAnalyzer.bestAvailableAudioFormat in startTranscribing()
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                completion(status == .authorized)
            }
        }
    }

    /// Called by TranscriptionService to feed audio buffers from SharedAudioManager
    func appendBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let analyzerFormat = analyzerFormat else { return }

        // Create converter lazily based on the incoming buffer format
        if audioConverter == nil {
            let inputFormat = buffer.format
            audioConverter = AVAudioConverter(from: inputFormat, to: analyzerFormat)
            if audioConverter == nil {
                print("SpeechAnalyzer: Failed to create audio converter from \(inputFormat) to \(analyzerFormat)")
                return
            }
        }

        guard let converter = audioConverter else { return }

        // Convert to analyzer format (16-bit PCM, 16 kHz, mono)
        let inputFormat = buffer.format
        let frameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * analyzerFormat.sampleRate / inputFormat.sampleRate)
        guard frameCapacity > 0,
              let convertedBuffer = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: frameCapacity) else {
            return
        }

        var error: NSError?
        var hasData = true
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)

        if let error = error {
            print("SpeechAnalyzer: Conversion error: \(error)")
            return
        }

        // Send converted buffer to analyzer
        inputContinuation?.yield(AnalyzerInput(buffer: convertedBuffer))
    }

    func startTranscribing() {
        isStoppingIntentionally = false
        transcribedText = ""
        baseTranscript = ""
        lastResultLength = 0
        error = nil
        audioConverter = nil // Reset converter for fresh format detection

        Task {
            do {
                print("SpeechAnalyzer: Starting transcription...")

                // Create transcriber using the progressive preset for continuous live audio ingestion
                let newTranscriber = SpeechTranscriber(
                    locale: Locale.current,
                    preset: .progressiveTranscription
                )
                transcriber = newTranscriber

                print("SpeechAnalyzer: Transcriber created")

                // Negotiate the best audio format the neural engine expects — avoids format-mismatch crashes
                if let negotiatedFormat = try? await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [newTranscriber]) {
                    analyzerFormat = negotiatedFormat
                    print("SpeechAnalyzer: Negotiated audio format: \(negotiatedFormat)")
                } else {
                    // Fallback to known-good format if negotiation fails
                    let fallback = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false)
                    guard fallback != nil else {
                        await MainActor.run { self.error = "Could not create audio format for transcription." }
                        return
                    }
                    analyzerFormat = fallback
                    print("SpeechAnalyzer: Using fallback audio format 16kHz PCM Int16")
                }

                // Reset converter so appendBuffer() picks up the new format
                audioConverter = nil

                // Create input stream
                let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
                self.inputContinuation = inputContinuation

                print("SpeechAnalyzer: Input stream created")

                // Create analyzer with input sequence
                let newAnalyzer = SpeechAnalyzer(
                    inputSequence: inputSequence,
                    modules: [newTranscriber]
                )
                analyzer = newAnalyzer

                print("SpeechAnalyzer: Analyzer created")

                // Start processing results
                resultsTask = Task { [weak self] in
                    guard let self = self else { return }

                    do {
                        for try await result in newTranscriber.results {
                            let newText = String(result.text.characters)
                            await MainActor.run {
                                // SpeechAnalyzer may reset its internal state periodically
                                // If the new text is shorter than what we had, it means a restart occurred
                                // In that case, save current text and append new results
                                if newText.count < self.lastResultLength && !self.transcribedText.isEmpty {
                                    // Transcriber restarted - save accumulated text
                                    self.baseTranscript = self.transcribedText
                                }

                                // Combine base transcript with new text
                                if self.baseTranscript.isEmpty {
                                    self.transcribedText = newText
                                } else {
                                    self.transcribedText = self.baseTranscript + " " + newText
                                }

                                self.lastResultLength = newText.count
                            }
                        }
                    } catch {
                        print("SpeechAnalyzer: Results error: \(error)")
                        await MainActor.run {
                            self.error = "Transcription error: \(error.localizedDescription)"
                        }
                    }
                }

                // Prepare analyzer
                print("SpeechAnalyzer: Preparing analyzer...")
                try await newAnalyzer.prepareToAnalyze(in: nil)
                print("SpeechAnalyzer: Analyzer prepared")

                // Audio buffers will be fed via appendBuffer() from TranscriptionService/SharedAudioManager
                print("SpeechAnalyzer: Ready to receive audio buffers from SharedAudioManager")

                await MainActor.run {
                    self.isTranscribing = true
                }

            } catch {
                print("SpeechAnalyzer: Fatal error: \(error)")
                await MainActor.run {
                    self.error = "Failed to start transcription: \(error.localizedDescription)"
                }
            }
        }
    }

    func pauseTranscribing() {
        // SharedAudioManager handles audio engine pause
    }

    func resumeTranscribing() {
        // SharedAudioManager handles audio engine resume
    }

    func stopTranscribing() {
        isStoppingIntentionally = true

        // Finish input stream
        inputContinuation?.finish()
        inputContinuation = nil

        // Cancel results task
        resultsTask?.cancel()
        resultsTask = nil

        // Clean up converter
        audioConverter = nil

        // Clean up analyzer and transcriber
        Task { @MainActor in
            analyzer = nil
            transcriber = nil
            isTranscribing = false
        }
    }

    func reset() {
        isStoppingIntentionally = true
        stopTranscribing()

        DispatchQueue.main.async {
            self.transcribedText = ""
            self.baseTranscript = ""
            self.lastResultLength = 0
            self.error = nil
        }
    }
}
