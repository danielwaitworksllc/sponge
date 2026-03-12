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

        // Cancel any previous results loop before starting a new one.
        // Without this, calling startTranscribing() twice would run two loops in parallel,
        // both writing to transcribedText and causing duplication.
        resultsTask?.cancel()
        resultsTask = nil

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
                if let negotiatedFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [newTranscriber]) {
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
                                // Distinguish a true window slide from a model revision:
                                // - Window slide: the transcriber resets its context and the new result
                                //   is dramatically shorter (typically just the last few seconds of speech)
                                // - Model revision: the model tweaks its hypothesis, text stays similar length
                                //
                                // Using < 50% of previous length as the threshold. Any shorter result
                                // that doesn't meet this bar is treated as a revision and overwrites
                                // the current window without duplicating into baseTranscript.
                                let isWindowSlide = newText.count < (self.lastResultLength / 2) && self.lastResultLength > 20

                                if isWindowSlide && !self.transcribedText.isEmpty {
                                    self.baseTranscript = self.transcribedText
                                }

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

    // MARK: - Offline File Transcription

    /// Transcribes a saved audio file using the `.offlineTranscription` preset, which uses full
    /// bidirectional context for higher accuracy than the live progressive pass.
    /// This is a static-style method — it creates its own isolated analyzer and does not
    /// affect any live transcription session in progress.
    func transcribeFile(at fileURL: URL) async throws -> String {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw NSError(domain: "SpeechAnalyzerService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Audio file not found at \(fileURL.path)"])
        }

        print("SpeechAnalyzerService: Starting offline transcription of \(fileURL.lastPathComponent)")

        let offlineTranscriber = SpeechTranscriber(locale: Locale.current, preset: .transcription)

        let audioFile = try AVAudioFile(forReading: fileURL)
        let sourceFormat = audioFile.processingFormat
        print("SpeechAnalyzerService: Audio file — frames=\(audioFile.length), sourceFormat=\(sourceFormat)")

        let targetFormat: AVAudioFormat
        if let negotiated = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [offlineTranscriber], considering: sourceFormat
        ) {
            targetFormat = negotiated
            print("SpeechAnalyzerService: Negotiated target format: \(targetFormat)")
        } else if let fallback = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 16000, channels: 1, interleaved: false) {
            targetFormat = fallback
            print("SpeechAnalyzerService: Using fallback 16kHz int16 format")
        } else {
            throw NSError(domain: "SpeechAnalyzerService", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create audio format for offline transcription"])
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else {
            throw NSError(domain: "SpeechAnalyzerService", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Could not create audio converter from \(sourceFormat) to \(targetFormat)"])
        }

        let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()

        let offlineAnalyzer = SpeechAnalyzer(inputSequence: inputSequence, modules: [offlineTranscriber])
        try await offlineAnalyzer.prepareToAnalyze(in: targetFormat)
        print("SpeechAnalyzerService: Analyzer prepared, feeding audio...")

        // Collect results in a concurrent child task so it runs while we feed audio below.
        // Using Task instead of async let to avoid ambiguity with the immediately-invoked closure.
        let resultsCollector = Task<String, Never> {
            var accumulated = ""
            var baseTranscript = ""
            var lastResultLength = 0
            do {
                for try await result in offlineTranscriber.results {
                    let newText = String(result.text.characters)
                    guard !newText.isEmpty else { continue }
                    // Same window-slide accumulation as the live pass:
                    // when the new result is dramatically shorter than the last, the
                    // transcriber has slid its context window — save what we have and
                    // start a fresh window segment.
                    let isWindowSlide = newText.count < (lastResultLength / 2) && lastResultLength > 20
                    if isWindowSlide {
                        baseTranscript = accumulated
                    }
                    accumulated = baseTranscript.isEmpty ? newText : baseTranscript + " " + newText
                    lastResultLength = newText.count
                    print("SpeechAnalyzerService: Got result (\(newText.count) chars, total \(accumulated.count))")
                }
            } catch {
                print("SpeechAnalyzerService: Results error: \(error)")
            }
            print("SpeechAnalyzerService: Results sequence ended, accumulated.count=\(accumulated.count)")
            return accumulated
        }

        // Feed audio file into the analyzer in chunks
        let readBufferSize: AVAudioFrameCount = 4096
        let readBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: readBufferSize)!
        var framesYielded = 0

        while audioFile.framePosition < audioFile.length {
            let framesToRead = min(readBufferSize, AVAudioFrameCount(audioFile.length - audioFile.framePosition))
            readBuffer.frameLength = framesToRead
            try audioFile.read(into: readBuffer, frameCount: framesToRead)

            let outputCapacity = AVAudioFrameCount(Double(framesToRead) * targetFormat.sampleRate / sourceFormat.sampleRate) + 1
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outputCapacity) else { continue }

            var hasData = true
            var convertError: NSError?
            converter.convert(to: convertedBuffer, error: &convertError) { _, outStatus in
                if hasData {
                    hasData = false
                    outStatus.pointee = .haveData
                    return readBuffer
                }
                outStatus.pointee = .noDataNow
                return nil
            }

            if let err = convertError {
                print("SpeechAnalyzerService: Converter error at frame \(framesYielded): \(err)")
                continue
            }

            if convertedBuffer.frameLength > 0 {
                inputContinuation.yield(AnalyzerInput(buffer: convertedBuffer))
                framesYielded += Int(convertedBuffer.frameLength)
            }
        }

        print("SpeechAnalyzerService: Finished feeding \(framesYielded) frames, closing stream")

        // Close the input stream — the analyzer processes remaining audio and finalizes,
        // which terminates the results sequence and unblocks resultsCollector.
        inputContinuation.finish()

        // Guard against the results sequence never terminating (e.g. analyzer internal failure).
        // After 3 minutes we cancel the collector and return whatever was accumulated.
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(180))
            resultsCollector.cancel()
        }

        let result = await resultsCollector.value
        timeoutTask.cancel()
        print("SpeechAnalyzerService: Offline transcription complete — \(result.count) chars")
        return result
    }
}
