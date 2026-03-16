//
//  GeminiService.swift
//  Sponge
//
//  Created by Claude on 2026-02-03.
//

import Foundation

/// Available Gemini models on the free tier
enum GeminiModel: String, CaseIterable, Identifiable {
    case flash = "gemini-2.5-flash"
    case flashLite = "gemini-2.5-flash-lite"
    case pro = "gemini-2.5-pro"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flash: return "Gemini 2.5 Flash"
        case .flashLite: return "Gemini 2.5 Flash-Lite"
        case .pro: return "Gemini 2.5 Pro"
        }
    }

    var subtitle: String {
        switch self {
        case .flash: return "Balanced — 250 req/day free"
        case .flashLite: return "Fastest — 1,000 req/day free"
        case .pro: return "Most capable — 100 req/day free"
        }
    }
}

class GeminiService {

    static let shared = GeminiService()

    private let apiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

    private init() {}

    // MARK: - Error Types

    enum GeminiError: LocalizedError {
        case noAPIKey
        case invalidResponse
        case networkError(Error)
        case apiError(String)

        var errorDescription: String? {
            switch self {
            case .noAPIKey:
                return "Gemini API key not found. Please add your API key in Settings."
            case .invalidResponse:
                return "Invalid response from Gemini API."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .apiError(let message):
                return "Gemini API error: \(message)"
            }
        }
    }

    // MARK: - Generate Class Notes

    func generateClassNotes(
        from transcript: String,
        userNotes: String = "",
        noteStyle: NoteStyle = .detailed,
        summaryLength: SummaryLength = .comprehensive
    ) async throws -> String {
        // Get API key from Keychain
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // Build user notes section if provided
        let userNotesSection: String
        if !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userNotesSection = """

            Here are the student's own notes taken during the lecture:

            \(userNotes)

            Please incorporate these notes and any specific points the student highlighted into the class notes.

            """
        } else {
            userNotesSection = ""
        }

        // Construct the prompt with customization
        let prompt = """
        You are an expert note-taker for college and high school students. Your task is to convert the following lecture transcription into well-organized class notes.

        \(noteStyle.promptModifier)

        \(summaryLength.promptModifier)

        Requirements:
        - Create clear, hierarchical notes with headers and subheaders
        - Capture important concepts, definitions, and explanations according to the length guidelines
        - Include specific examples, numbers, and details mentioned
        - Identify and list any action items, assignments, or deadlines
        - Use markdown formatting (bold with **, headers with ##)
        - Highlight key terms and important concepts
        - Maintain the logical flow of the lecture
        - If formulas or equations are mentioned, include them clearly

        Format the notes with clear sections:

        ## OVERVIEW
        (Brief summary of the lecture topic)

        ## KEY CONCEPTS
        (Main ideas and definitions)

        ## DETAILED NOTES
        (Notes organized by topic according to the chosen style)

        ## ACTION ITEMS
        (Homework, assignments, things to do, or review)
        \(userNotesSection)
        Here is the lecture transcription:

        \(transcript)
        """

        // Construct request body
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 8192
            ]
        ]

        // Create URL with API key
        guard var urlComponents = URLComponents(string: apiEndpoint) else {
            throw GeminiError.invalidResponse
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw GeminiError.invalidResponse
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)

        // Check HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Enhanced Summaries

    /// Generates enhanced summaries with optional marker-focused content
    func generateEnhancedSummaries(
        from transcript: String,
        markers: [IntentMarker],
        userNotes: String
    ) async throws -> EnhancedSummary {
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // Prepare marker context strings
        let confusedMarkers = markers.filter { $0.type == .confused }
        let examMarkers = markers.filter { $0.type == .examRelevant || $0.type == .important }

        var confusedContext = ""
        if !confusedMarkers.isEmpty {
            confusedContext = confusedMarkers.map { marker in
                "- At \(marker.formattedTimestamp): \"\(marker.transcriptSnapshot ?? "No context")\""
            }.joined(separator: "\n")
        }

        var examContext = ""
        if !examMarkers.isEmpty {
            examContext = examMarkers.map { marker in
                "- At \(marker.formattedTimestamp) (\(marker.type.displayName)): \"\(marker.transcriptSnapshot ?? "No context")\""
            }.joined(separator: "\n")
        }

        // Build the prompt
        var prompt = """
        You are an expert educational assistant helping students understand lecture content.

        Here is a lecture transcript:

        \(transcript)

        """

        if !userNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            prompt += """

            The student also took these notes during the lecture:

            \(userNotes)

            """
        }

        prompt += """

        Please generate the following summaries in JSON format:

        1. "generalOverview": A comprehensive overview of the lecture covering the main topics, key concepts, and important points. This should be 3-5 paragraphs.

        """

        if !confusedMarkers.isEmpty {
            prompt += """

        2. "confusionFocused": The student marked these moments as confusing:
        \(confusedContext)

        Please provide a focused explanation that:
        - Clarifies each confusing concept in simple terms
        - Provides additional context and examples
        - Connects these concepts to the broader lecture content

        """
        }

        if !examMarkers.isEmpty {
            prompt += """

        \(confusedMarkers.isEmpty ? "2" : "3"). "examOriented": The student marked these moments as important/exam-relevant:
        \(examContext)

        Please provide an exam-focused summary that:
        - Highlights the key points that are likely to be tested
        - Provides clear definitions and explanations
        - Suggests how these concepts might appear on an exam

        """
        }

        prompt += """

        Respond ONLY with valid JSON in this format:
        {
            "generalOverview": "...",
            "confusionFocused": "..." or null,
            "examOriented": "..." or null
        }
        """

        let text = try await makeGeminiRequest(prompt: prompt, apiKey: apiKey)

        // Parse JSON response
        return try parseEnhancedSummaryJSON(text)
    }

    // MARK: - Catch-Up Summary

    /// Generates a quick catch-up summary for when the student missed part of the lecture
    func generateCatchUpSummary(
        recentTranscript: String,
        previousContext: String
    ) async throws -> String {
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        let prompt = """
        You are helping a student who briefly lost focus during a lecture and needs to quickly catch up.

        Here's what was covered earlier (for context):
        \(previousContext.isEmpty ? "(Beginning of lecture)" : previousContext)

        Here's what the student missed (the recent content they need to catch up on):
        \(recentTranscript)

        Provide a very brief catch-up summary (2-3 sentences maximum) that:
        - States the single most important concept that was just covered
        - Explains why it matters

        Keep it extremely concise - the student needs to quickly get back on track without reading much.
        """

        return try await makeGeminiRequest(prompt: prompt, apiKey: apiKey)
    }

    // MARK: - Recall Prompts

    /// Generates recall questions for post-lecture review
    func generateRecallPrompts(
        from transcript: String,
        markers: [IntentMarker]
    ) async throws -> RecallPrompts {
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // Prepare marker context for weighted question generation
        var markerContext = ""
        if !markers.isEmpty {
            let markerDescriptions = markers.map { marker in
                "- \(marker.type.displayName) at \(marker.formattedTimestamp): \"\(marker.transcriptSnapshot ?? "No context")\""
            }
            markerContext = """

            The student marked these moments as significant during the lecture:
            \(markerDescriptions.joined(separator: "\n"))

            Weight your questions toward these marked moments, as the student found them important.

            """
        }

        let prompt = """
        You are an expert educator creating recall questions to help a student retain lecture content.

        Here is the lecture transcript:

        \(transcript)
        \(markerContext)
        Generate 6-10 recall questions across these four types:
        1. "definition" - What is...? questions testing terminology
        2. "conceptual" - Why/How does...? questions testing understanding
        3. "applied" - How would you use...? questions testing application
        4. "connection" - How does X relate to Y? questions testing synthesis

        Respond ONLY with valid JSON in this format:
        {
            "questions": [
                {
                    "question": "What is...?",
                    "type": "definition",
                    "suggestedAnswer": "A clear, concise answer..."
                },
                ...
            ]
        }

        Ensure a good mix of question types with emphasis on marked moments if any.
        """

        let text = try await makeGeminiRequest(prompt: prompt, apiKey: apiKey)

        return try parseRecallPromptsJSON(text)
    }

    // MARK: - Helper Methods

    /// Makes a request to the Gemini API and returns the text response
    private func makeGeminiRequest(prompt: String, apiKey: String) async throws -> String {
        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.3,
                "maxOutputTokens": 8192
            ]
        ]

        guard var urlComponents = URLComponents(string: apiEndpoint) else {
            throw GeminiError.invalidResponse
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]

        guard let url = urlComponents.url else {
            throw GeminiError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("HTTP \(httpResponse.statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parses the enhanced summary JSON response
    private func parseEnhancedSummaryJSON(_ text: String) throws -> EnhancedSummary {
        // Extract JSON from potential markdown code blocks
        let jsonString = extractJSON(from: text)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GeminiError.invalidResponse
        }

        return EnhancedSummary(
            generalOverview: json["generalOverview"] as? String,
            confusionFocused: json["confusionFocused"] as? String,
            examOriented: json["examOriented"] as? String
        )
    }

    /// Parses the recall prompts JSON response
    private func parseRecallPromptsJSON(_ text: String) throws -> RecallPrompts {
        let jsonString = extractJSON(from: text)

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let questionsArray = json["questions"] as? [[String: Any]] else {
            throw GeminiError.invalidResponse
        }

        let questions = questionsArray.compactMap { dict -> RecallQuestion? in
            guard let question = dict["question"] as? String,
                  let typeString = dict["type"] as? String,
                  let type = RecallQuestionType(rawValue: typeString) else {
                return nil
            }

            return RecallQuestion(
                question: question,
                type: type,
                suggestedAnswer: dict["suggestedAnswer"] as? String
            )
        }

        return RecallPrompts(questions: questions)
    }

    // MARK: - Audio Transcription (Gemini Files API)

    /// Uploads an M4A lecture recording to the Gemini Files API and returns a high-quality
    /// transcript with punctuation, capitalization, and paragraph breaks.
    /// Cost: ~$0.03–$0.08 per lecture hour.
    func transcribeAudioFile(at fileURL: URL, vocabulary: [String] = []) async throws -> String {
        guard let apiKey = KeychainHelper.shared.getGeminiAPIKey(), !apiKey.isEmpty else {
            throw GeminiError.noAPIKey
        }

        // MARK: Step 1 — Upload file to Files API
        // Load audio data on a background thread to avoid blocking the cooperative thread pool
        let audioData = try await Task.detached(priority: .userInitiated) {
            try Data(contentsOf: fileURL)
        }.value
        let mimeType = "audio/m4a"
        let boundary = "sponge_boundary_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        // Build multipart body
        var body = Data()
        let metadataJSON = "{\"file\": {\"display_name\": \"\(fileURL.lastPathComponent)\"}}"
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n".data(using: .utf8)!)
        body.append(metadataJSON.data(using: .utf8)!)
        body.append("\r\n--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        guard let uploadURL = URL(string: "https://generativelanguage.googleapis.com/upload/v1beta/files?key=\(apiKey)") else {
            throw GeminiError.invalidResponse
        }

        var uploadRequest = URLRequest(url: uploadURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
        uploadRequest.httpBody = body

        print("GeminiAudio: Uploading \(audioData.count / 1024)KB audio file...")
        let (uploadData, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)

        guard let uploadHTTP = uploadResponse as? HTTPURLResponse, uploadHTTP.statusCode == 200 else {
            let statusCode = (uploadResponse as? HTTPURLResponse)?.statusCode ?? -1
            throw GeminiError.apiError("File upload failed with HTTP \(statusCode)")
        }

        guard let uploadJSON = try? JSONSerialization.jsonObject(with: uploadData) as? [String: Any],
              let fileDict = uploadJSON["file"] as? [String: Any],
              let fileURI = fileDict["uri"] as? String else {
            throw GeminiError.invalidResponse
        }
        print("GeminiAudio: File uploaded, URI: \(fileURI)")

        // MARK: Step 2 — Generate transcript from audio file

        let vocabularySection = vocabulary.isEmpty ? "" : """

        Course-specific vocabulary and proper nouns to ensure correct spelling:
        \(vocabulary.joined(separator: ", "))

        """

        let systemPrompt = """
        You are a professional academic transcriptionist. Your task is to produce a verbatim, word-for-word transcript of the lecture audio. Follow these strict rules:

        1. Transcribe every spoken word exactly as heard — do not summarize, paraphrase, or omit content.
        2. Add correct punctuation (periods, commas, question marks) based on the speaker's prosody and natural sentence boundaries.
        3. Capitalize the first word of each sentence and proper nouns.
        4. Start a new paragraph whenever the speaker clearly shifts to a new topic or after a notable pause.
        5. If multiple speakers are detectable, prefix each speaker's lines with "Speaker 1:", "Speaker 2:", etc.
        6. Do NOT add any commentary, headers, or content that was not spoken.\(vocabularySection)
        Output only the transcript text with no preamble.
        """

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        ["fileData": ["mimeType": mimeType, "fileUri": fileURI]]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.0,
                "maxOutputTokens": 32768
            ]
        ]

        guard var urlComponents = URLComponents(string: apiEndpoint) else {
            throw GeminiError.invalidResponse
        }
        urlComponents.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let generateURL = urlComponents.url else { throw GeminiError.invalidResponse }

        var generateRequest = URLRequest(url: generateURL)
        generateRequest.httpMethod = "POST"
        generateRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        generateRequest.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        generateRequest.timeoutInterval = 180 // 3 minutes for long audio

        print("GeminiAudio: Requesting transcript generation...")
        let (generateData, generateResponse) = try await URLSession.shared.data(for: generateRequest)

        guard let generateHTTP = generateResponse as? HTTPURLResponse, generateHTTP.statusCode == 200 else {
            let statusCode = (generateResponse as? HTTPURLResponse)?.statusCode ?? -1
            if let errorJSON = try? JSONSerialization.jsonObject(with: generateData) as? [String: Any],
               let error = errorJSON["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            throw GeminiError.apiError("Transcript generation failed with HTTP \(statusCode)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: generateData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }

        print("GeminiAudio: Transcript received (\(text.count) chars)")

        // MARK: Step 3 — Delete the uploaded file (cleanup)
        // fileURI is the full resource name like "files/abc123"; build the REST path using URLComponents
        var deleteComponents = URLComponents(string: "https://generativelanguage.googleapis.com")
        deleteComponents?.path = "/v1beta/\(fileURI)"
        deleteComponents?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        if let deleteURL = deleteComponents?.url {
            var deleteRequest = URLRequest(url: deleteURL)
            deleteRequest.httpMethod = "DELETE"
            _ = try? await URLSession.shared.data(for: deleteRequest)
            print("GeminiAudio: File deleted from Files API")
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extracts JSON from a string that may contain markdown code blocks
    private func extractJSON(from text: String) -> String {
        // Check for markdown code block
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Check for generic code block
        if let jsonStart = text.range(of: "```"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Assume the whole string is JSON
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
