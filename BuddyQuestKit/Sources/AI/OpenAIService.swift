import Foundation

/// OpenAI GPT service via URLSession (BYOT — user provides their own API key)
public final class OpenAIService: AIServiceProtocol {
    public let provider: AIProvider = .openAI

    private var apiKey: String?
    private let model = "gpt-4o-mini"
    private let baseURL = "https://api.openai.com/v1/chat/completions"
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
        let json = try await chatCompletion(system: prompts.system, user: prompts.user)
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
        let json = try await chatCompletion(system: prompts.system, user: prompts.user)
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
        let json = try await chatCompletion(system: prompts.system, user: prompts.user)
        return try parseHintJSON(json, hintLevel: hintLevel)
    }

    // MARK: - Buddy Dialogue

    public func generateBuddyDialogue(
        buddyName: String, buddyPersonality: String, context: BuddyDialogueContext
    ) async throws -> AIBuddyDialogue {
        let prompts = PromptTemplates.buddyDialogue(
            buddyName: buddyName, buddyPersonality: buddyPersonality, context: context
        )
        let json = try await chatCompletion(system: prompts.system, user: prompts.user)
        return try parseDialogueJSON(json)
    }

    // MARK: - OpenAI Chat Completion API

    private func chatCompletion(system: String, user: String) async throws -> [String: Any] {
        guard let apiKey = apiKey, !apiKey.isEmpty else {
            throw AIServiceError.notConfigured
        }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = timeoutSeconds

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "temperature": 0.7,
            "max_tokens": 500,
            "response_format": ["type": "json_object"]
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
            throw AIServiceError.unknownError("OpenAI API error \(httpResponse.statusCode): \(errorBody)")
        }

        // Parse the OpenAI response envelope
        guard let envelope = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = envelope["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.parsingError("Invalid OpenAI response structure")
        }

        // Parse the content JSON
        guard let contentData = content.data(using: .utf8),
              let json = try JSONSerialization.jsonObject(with: contentData) as? [String: Any] else {
            throw AIServiceError.parsingError("Failed to parse JSON from content: \(content)")
        }

        return json
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
