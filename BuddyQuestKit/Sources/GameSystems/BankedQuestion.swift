import Foundation

// MARK: - Banked Question

/// A question stored in the adaptive question bank with tracking metadata.
/// Wraps the core question fields (flattened for Codable) with usage and mastery data.
public struct BankedQuestion: Codable, Identifiable {
    public let id: UUID

    // Core question data (flattened from MultipleChoiceQuestion, which is not Codable)
    public let question: String
    public let options: [String]            // Exactly 4
    public let correctIndex: Int            // 0-3
    public let explanation: String
    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel

    // Tracking metadata
    public var timesShown: Int
    public var timesCorrect: Int
    public var lastShownDate: Date?
    public let addedDate: Date
    public let source: QuestionSource

    public enum QuestionSource: String, Codable {
        case staticBank      // From QuestionBank.swift
        case aiGenerated     // From QuestionGenerator via AI
    }

    // MARK: - Computed Properties

    /// Whether the player has mastered this question (answered correctly enough times).
    public var isMastered: Bool {
        timesCorrect >= GameConstants.bankMasteryThreshold
    }

    /// Accuracy rate (0.0 - 1.0) for this question.
    public var accuracyRate: Double {
        guard timesShown > 0 else { return 0 }
        return Double(timesCorrect) / Double(timesShown)
    }

    // MARK: - Initializers

    /// Create from a MultipleChoiceQuestion (used when seeding or adding new questions).
    public init(from mcq: MultipleChoiceQuestion, source: QuestionSource) {
        self.id = UUID()
        self.question = mcq.question
        self.options = mcq.options
        self.correctIndex = mcq.correctIndex
        self.explanation = mcq.explanation
        self.subject = mcq.subject
        self.difficulty = mcq.difficulty
        self.gradeLevel = mcq.gradeLevel
        self.timesShown = 0
        self.timesCorrect = 0
        self.lastShownDate = nil
        self.addedDate = Date()
        self.source = source
    }

    /// Convert back to MultipleChoiceQuestion for use in challenges.
    public func toMultipleChoiceQuestion() -> MultipleChoiceQuestion {
        MultipleChoiceQuestion(
            question: question,
            options: options,
            correctIndex: correctIndex,
            explanation: explanation,
            subject: subject,
            difficulty: difficulty,
            gradeLevel: gradeLevel
        )
    }
}

// MARK: - Question Bank Data

/// Persistent question bank data for a single player profile.
/// Serialized as a separate JSON file per profile.
public struct QuestionBankData: Codable {
    /// Questions keyed by Subject.rawValue.
    public var banks: [String: [BankedQuestion]]

    /// Last time each subject's bank was replenished via AI.
    public var lastReplenishDate: [String: Date]

    /// Data format version for future migration.
    public var version: Int

    public init() {
        self.banks = [:]
        self.lastReplenishDate = [:]
        self.version = 1
    }

    /// Get all questions for a subject.
    public func questions(for subject: Subject) -> [BankedQuestion] {
        banks[subject.rawValue] ?? []
    }

    /// Replace the question list for a subject.
    public mutating func setQuestions(_ questions: [BankedQuestion], for subject: Subject) {
        banks[subject.rawValue] = questions
    }
}
