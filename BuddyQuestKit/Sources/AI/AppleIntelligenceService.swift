import Foundation

// MARK: - Apple Intelligence Service
//
// Uses Apple's Foundation Models framework (iOS 26+ / macOS 26+)
// for free, on-device, privacy-preserving AI.
//
// When compiled with Xcode 26+ SDK targeting iOS 26+/macOS 26+,
// the #if canImport(FoundationModels) branch activates and provides
// full on-device AI via LanguageModelSession + @Generable structs.
//
// On older SDKs/targets, the fallback branch compiles — isAvailable
// returns false and all methods throw .notAvailable, so the
// AIServiceManager gracefully falls through to the next provider.

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Types for Structured Output

@available(iOS 26, macOS 26, *)
@Generable
struct GeneratedQuestionResponse {
    @Guide(description: "The subject this question tests (must match the requested subject exactly)")
    var subject: String
    @Guide(description: "The question text, age-appropriate and clear. Must be about the specified subject only.")
    var question: String
    @Guide(description: "Exactly 4 multiple-choice options as full text strings")
    var options: [String]
    @Guide(description: "Zero-based index of the correct option (0-3)")
    var correctIndex: Int
    @Guide(description: "Brief encouraging explanation of the correct answer")
    var explanation: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct GradingResponse {
    @Guide(description: "Score from 0 to 100")
    var score: Int
    @Guide(description: "True if the answer is correct or substantially correct")
    var isCorrect: Bool
    @Guide(description: "Short encouraging feedback for the student")
    var feedback: String
    @Guide(description: "Brief explanation of the correct answer")
    var explanation: String
}

@available(iOS 26, macOS 26, *)
@Generable
struct HintResponse {
    @Guide(description: "A hint delivered in the buddy's voice and personality")
    var hintText: String
    @Guide(description: "The hint level (1-4)")
    var hintLevel: Int
}

@available(iOS 26, macOS 26, *)
@Generable
struct DialogueResponse {
    @Guide(description: "1-2 sentence dialogue line in character")
    var dialogue: String
    @Guide(description: "The buddy's emotion: happy, thinking, excited, or encouraging")
    var emotion: String
}

// MARK: - Service with availability-gated implementation

public final class AppleIntelligenceService: AIServiceProtocol {
    public let provider: AIProvider = .appleIntelligence

    public var isAvailable: Bool {
        if #available(iOS 26, macOS 26, *) {
            return _checkAvailability()
        }
        return false
    }

    public var unavailableReason: String? {
        if #available(iOS 26, macOS 26, *) {
            return _getUnavailableReason()
        }
        return "Requires iOS 26+ or macOS 26+ with Apple Intelligence"
    }

    public init() {}

    public func generateQuestion(
        subject: String, topic: String?, gradeLevel: Int, difficulty: Int
    ) async throws -> AIGeneratedQuestion {
        if #available(iOS 26, macOS 26, *) {
            return try await _generateQuestion(subject: subject, topic: topic,
                                                gradeLevel: gradeLevel, difficulty: difficulty)
        }
        throw AIServiceError.notAvailable(reason: "Requires iOS 26+ or macOS 26+")
    }

    public func gradeAnswer(
        question: String, correctAnswer: String, studentAnswer: String, subject: String
    ) async throws -> AIGradingResult {
        if #available(iOS 26, macOS 26, *) {
            return try await _gradeAnswer(question: question, correctAnswer: correctAnswer,
                                           studentAnswer: studentAnswer, subject: subject)
        }
        throw AIServiceError.notAvailable(reason: "Requires iOS 26+ or macOS 26+")
    }

    public func generateHint(
        question: String, options: [String], correctIndex: Int,
        hintLevel: Int, buddyName: String, buddyPersonality: String
    ) async throws -> AIHint {
        if #available(iOS 26, macOS 26, *) {
            return try await _generateHint(question: question, options: options,
                                            correctIndex: correctIndex, hintLevel: hintLevel,
                                            buddyName: buddyName, buddyPersonality: buddyPersonality)
        }
        throw AIServiceError.notAvailable(reason: "Requires iOS 26+ or macOS 26+")
    }

    public func generateBuddyDialogue(
        buddyName: String, buddyPersonality: String, context: BuddyDialogueContext
    ) async throws -> AIBuddyDialogue {
        if #available(iOS 26, macOS 26, *) {
            return try await _generateBuddyDialogue(buddyName: buddyName,
                                                     buddyPersonality: buddyPersonality, context: context)
        }
        throw AIServiceError.notAvailable(reason: "Requires iOS 26+ or macOS 26+")
    }

    // MARK: - Private Implementation (iOS 26+ / macOS 26+)

    @available(iOS 26, macOS 26, *)
    private func _checkAvailability() -> Bool {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available: return true
        default: return false
        }
    }

    @available(iOS 26, macOS 26, *)
    private func _getUnavailableReason() -> String? {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available: return nil
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible: return "This device doesn't support Apple Intelligence"
            case .appleIntelligenceNotEnabled: return "Please enable Apple Intelligence in Settings"
            case .modelNotReady: return "Apple Intelligence model is still downloading"
            @unknown default: return "Apple Intelligence is not available"
            }
        @unknown default: return "Apple Intelligence is not available"
        }
    }

    @available(iOS 26, macOS 26, *)
    private func _generateQuestion(subject: String, topic: String?, gradeLevel: Int, difficulty: Int) async throws -> AIGeneratedQuestion {
        let prompts = PromptTemplates.questionGeneration(
            subject: subject, topic: topic, gradeLevel: gradeLevel, difficulty: difficulty
        )
        let session = LanguageModelSession(instructions: prompts.system)
        let result = try await session.respond(to: prompts.user, generating: GeneratedQuestionResponse.self)
        let response = result.content
        return AIGeneratedQuestion(
            question: response.question, options: response.options,
            correctIndex: response.correctIndex, explanation: response.explanation,
            difficulty: difficulty, subject: subject, gradeLevel: gradeLevel
        )
    }

    @available(iOS 26, macOS 26, *)
    private func _gradeAnswer(question: String, correctAnswer: String, studentAnswer: String, subject: String) async throws -> AIGradingResult {
        let prompts = PromptTemplates.answerGrading(
            question: question, correctAnswer: correctAnswer,
            studentAnswer: studentAnswer, subject: subject
        )
        let session = LanguageModelSession(instructions: prompts.system)
        let result = try await session.respond(to: prompts.user, generating: GradingResponse.self)
        let response = result.content
        return AIGradingResult(score: response.score, isCorrect: response.isCorrect,
                               feedback: response.feedback, explanation: response.explanation)
    }

    @available(iOS 26, macOS 26, *)
    private func _generateHint(question: String, options: [String], correctIndex: Int,
                                hintLevel: Int, buddyName: String, buddyPersonality: String) async throws -> AIHint {
        let prompts = PromptTemplates.socraticHint(
            question: question, options: options, correctIndex: correctIndex,
            hintLevel: hintLevel, buddyName: buddyName, buddyPersonality: buddyPersonality
        )
        let session = LanguageModelSession(instructions: prompts.system)
        let result = try await session.respond(to: prompts.user, generating: HintResponse.self)
        let response = result.content
        return AIHint(hintText: response.hintText, hintLevel: response.hintLevel)
    }

    @available(iOS 26, macOS 26, *)
    private func _generateBuddyDialogue(buddyName: String, buddyPersonality: String,
                                          context: BuddyDialogueContext) async throws -> AIBuddyDialogue {
        let prompts = PromptTemplates.buddyDialogue(
            buddyName: buddyName, buddyPersonality: buddyPersonality, context: context
        )
        let session = LanguageModelSession(instructions: prompts.system)
        let result = try await session.respond(to: prompts.user, generating: DialogueResponse.self)
        let response = result.content
        return AIBuddyDialogue(dialogue: response.dialogue, emotion: response.emotion)
    }
}

#else
// MARK: - Fallback for SDKs without FoundationModels

public final class AppleIntelligenceService: AIServiceProtocol {
    public let provider: AIProvider = .appleIntelligence
    public var isAvailable: Bool { false }
    public var unavailableReason: String? { "Requires iOS 26+ or macOS 26+ with Apple Intelligence" }

    public init() {}

    public func generateQuestion(subject: String, topic: String?, gradeLevel: Int, difficulty: Int) async throws -> AIGeneratedQuestion {
        throw AIServiceError.notAvailable(reason: unavailableReason!)
    }
    public func gradeAnswer(question: String, correctAnswer: String, studentAnswer: String, subject: String) async throws -> AIGradingResult {
        throw AIServiceError.notAvailable(reason: unavailableReason!)
    }
    public func generateHint(question: String, options: [String], correctIndex: Int, hintLevel: Int, buddyName: String, buddyPersonality: String) async throws -> AIHint {
        throw AIServiceError.notAvailable(reason: unavailableReason!)
    }
    public func generateBuddyDialogue(buddyName: String, buddyPersonality: String, context: BuddyDialogueContext) async throws -> AIBuddyDialogue {
        throw AIServiceError.notAvailable(reason: unavailableReason!)
    }
}
#endif
