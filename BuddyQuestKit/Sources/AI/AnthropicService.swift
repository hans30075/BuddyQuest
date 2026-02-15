import Foundation

/// Anthropic Claude service via URLSession (BYOT — user provides their own API key)
public final class AnthropicService: AIServiceProtocol {
    public let provider: AIProvider = .anthropic

    private var apiKey: String?
    private let model = "claude-3-5-haiku-latest"
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private let timeoutSeconds: TimeInterval = 15

    public var isAvailable: Bool { apiKey != nil && !apiKey!.isEmpty }

    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }

    public func setAPIKey(_ key: String?) {
        self.apiKey = key
    }

    // MARK: - Question Generation

    public func generateQuestion(
        subject: String, topic: String?, gradeLevel: Int, difficulty: Int
    ) async throws -> AIGeneratedQuestion {
        let prompts = PromptTemplates.questionGeneration(
            subject: subject, topic: topic, gradeLevel: gradeLevel, difficulty: difficulty
        )
        let json = try await messagesAPI(system: prompts.system, user: prompts.user)
        return try parseQuestionJSON(json, subject: subject, gradeLevel: gradeLevel, difficulty: difficulty)
    }

    // MARK: - Answer Grading

    public func gradeAnswer(
        question: String, correctAnswer: String, studentAnswer: String, subject: String
    ) async throws -> AIGradingResult {
        let prompts = PromptTemplates.answerGrading(
            question: question, correctAnswer: correctAnswer,
            studentAnswer: studentAnswer, subject: subject
        )
        let json = try await messagesAPI(system: prompts.system, user: prompts.user)
        return try parseGradingJSON(json)
    }

    // MARK: - Hints

    public func generateHint(
        question: String, options: [String], correctIndex: Int,
        hintLevel: Int, buddyName: String, buddyPersonality: String
    ) async throws -> AIHint {
        let prompts = PromptTemplates.socraticHint(
            question: question, options: options, correctIndex: correctIndex,
            hintLevel: hintLevel, buddyName: buddyName, buddyPersonality: buddyPersonality
        )
        let json = try await messagesAPI(system: prompts.system, user: prompts.user)
        return try parseHintJSON(json, hintLevel: hintLevel)
    }

    // MARK: - Buddy Dialogue

    public func generateBuddyDialogue(
        buddyName: String, buddyPersonality: String, context: BuddyDialogueContext
    ) async throws -> AIBuddyDialogue {
        let prompts = PromptTemplates.buddyDialogue(
            buddyName: buddyName, buddyPersonality: buddyPersonality, context: context
        )
        let json = try await messagesAPI(system: prompts.system, user: prompts.user)
        return try parseDialogueJSON(json)
    }

    // MARK: - Anthropic Messages API

    private func messagesAPI(system: String, user: String) async throws -> [String: Any] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.notConfigured
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = timeoutSeconds

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 500,
            "system": system,
            "messages": [
                ["role": "user", "content": user + "\n\nRespond with valid JSON only, no markdown."]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.networkError(URLError(.badServerResponse))
        }

        if httpResponse.statusCode == 401 {
            throw AIServiceError.invalidAPIKey
        }
        if httpResponse.statusCode == 429 {
            throw AIServiceError.rateLimited
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.unknownError("Anthropic API error \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse the Anthropic response envelope
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = envelope["content"] as? [[String: Any]],
              let firstBlock = content.first,
              let text = firstBlock["text"] as? String else {
            throw AIServiceError.parsingError("Invalid Anthropic response structure")
        }

        // Extract JSON from the text (may be wrapped in markdown code block)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw AIServiceError.parsingError("Failed to parse JSON from content: \(text)")
        }

        return json
    }

    /// Extract JSON from a string that might be wrapped in markdown code blocks
    private func extractJSON(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to extract from ```json ... ``` or ``` ... ```
        if let jsonStart = trimmed.range(of: "```json"),
           let jsonEnd = trimmed.range(of: "```", range: jsonStart.upperBound..<trimmed.endIndex) {
            return String(trimmed[jsonStart.upperBound..<jsonEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let jsonStart = trimmed.range(of: "```"),
           let jsonEnd = trimmed.range(of: "```", range: jsonStart.upperBound..<trimmed.endIndex) {
            return String(trimmed[jsonStart.upperBound..<jsonEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Try finding raw JSON (starts with { and ends with })
        if let firstBrace = trimmed.firstIndex(of: "{"),
           let lastBrace = trimmed.lastIndex(of: "}") {
            return String(trimmed[firstBrace...lastBrace])
        }

        return trimmed
    }

    // MARK: - JSON Parsing Helpers

    private func parseQuestionJSON(_ json: [String: Any], subject: String, gradeLevel: Int, difficulty: Int) throws -> AIGeneratedQuestion {
        guard let question = json["question"] as? String,
              let options = json["options"] as? [String],
              let correctIndex = json["correctIndex"] as? Int,
              let explanation = json["explanation"] as? String else {
            throw AIServiceError.parsingError("Missing fields in question JSON")
        }
        return AIGeneratedQuestion(
            question: question, options: options, correctIndex: correctIndex,
            explanation: explanation, difficulty: difficulty, subject: subject, gradeLevel: gradeLevel
        )
    }

    private func parseGradingJSON(_ json: [String: Any]) throws -> AIGradingResult {
        guard let score = json["score"] as? Int,
              let isCorrect = json["isCorrect"] as? Bool,
              let feedback = json["feedback"] as? String,
              let explanation = json["explanation"] as? String else {
            throw AIServiceError.parsingError("Missing fields in grading JSON")
        }
        return AIGradingResult(score: score, isCorrect: isCorrect, feedback: feedback, explanation: explanation)
    }

    private func parseHintJSON(_ json: [String: Any], hintLevel: Int) throws -> AIHint {
        guard let hintText = json["hintText"] as? String else {
            throw AIServiceError.parsingError("Missing hintText in hint JSON")
        }
        return AIHint(hintText: hintText, hintLevel: json["hintLevel"] as? Int ?? hintLevel)
    }

    private func parseDialogueJSON(_ json: [String: Any]) throws -> AIBuddyDialogue {
        guard let dialogue = json["dialogue"] as? String else {
            throw AIServiceError.parsingError("Missing dialogue in response JSON")
        }
        return AIBuddyDialogue(dialogue: dialogue, emotion: json["emotion"] as? String ?? "happy")
    }
}
