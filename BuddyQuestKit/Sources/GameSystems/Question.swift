import Foundation

// MARK: - Question Type

/// Identifies the kind of question in a challenge round
public enum QuestionType: String, Codable, CaseIterable, Sendable {
    case multipleChoice
    case trueFalse
    case ordering
    case matching
}

// MARK: - Question Payload

/// Type-specific data for each question kind.
/// Each case carries the fields unique to that type.
public enum QuestionPayload: Sendable {

    /// Standard 4-option multiple choice
    case multipleChoice(options: [String], correctIndex: Int)

    /// Binary true/false statement
    case trueFalse(correctAnswer: Bool)

    /// Arrange items in the correct order
    case ordering(
        items: [String],             // Items in DISPLAY order (pre-shuffled)
        correctOrder: [Int]          // correctOrder[displayPos] = original index
    )

    /// Match items from left column to right column
    case matching(
        leftItems: [String],
        rightItems: [String],        // Display order (pre-shuffled)
        correctMapping: [Int]        // correctMapping[leftIndex] = rightIndex
    )
}

// MARK: - QuestionPayload Codable

extension QuestionPayload: Codable {

    private enum CodingKeys: String, CodingKey {
        case type
        case options, correctIndex
        case correctAnswer
        case items, correctOrder
        case leftItems, rightItems, correctMapping
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .multipleChoice(let options, let correctIndex):
            try container.encode("multipleChoice", forKey: .type)
            try container.encode(options, forKey: .options)
            try container.encode(correctIndex, forKey: .correctIndex)

        case .trueFalse(let correctAnswer):
            try container.encode("trueFalse", forKey: .type)
            try container.encode(correctAnswer, forKey: .correctAnswer)

        case .ordering(let items, let correctOrder):
            try container.encode("ordering", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encode(correctOrder, forKey: .correctOrder)

        case .matching(let leftItems, let rightItems, let correctMapping):
            try container.encode("matching", forKey: .type)
            try container.encode(leftItems, forKey: .leftItems)
            try container.encode(rightItems, forKey: .rightItems)
            try container.encode(correctMapping, forKey: .correctMapping)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "multipleChoice":
            let options = try container.decode([String].self, forKey: .options)
            let correctIndex = try container.decode(Int.self, forKey: .correctIndex)
            self = .multipleChoice(options: options, correctIndex: correctIndex)

        case "trueFalse":
            let correctAnswer = try container.decode(Bool.self, forKey: .correctAnswer)
            self = .trueFalse(correctAnswer: correctAnswer)

        case "ordering":
            let items = try container.decode([String].self, forKey: .items)
            let correctOrder = try container.decode([Int].self, forKey: .correctOrder)
            self = .ordering(items: items, correctOrder: correctOrder)

        case "matching":
            let leftItems = try container.decode([String].self, forKey: .leftItems)
            let rightItems = try container.decode([String].self, forKey: .rightItems)
            let correctMapping = try container.decode([Int].self, forKey: .correctMapping)
            self = .matching(leftItems: leftItems, rightItems: rightItems, correctMapping: correctMapping)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unknown question payload type: \(type)"
            )
        }
    }
}

// MARK: - Question

/// Universal question struct used throughout the system.
/// All question types flow through this — the specific data lives in `payload`.
public struct Question: Sendable {
    public let questionText: String
    public let payload: QuestionPayload
    public let explanation: String
    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel

    /// Convenience: which type of question this is
    public var questionType: QuestionType {
        switch payload {
        case .multipleChoice: return .multipleChoice
        case .trueFalse: return .trueFalse
        case .ordering: return .ordering
        case .matching: return .matching
        }
    }

    public init(
        questionText: String,
        payload: QuestionPayload,
        explanation: String,
        subject: Subject,
        difficulty: DifficultyLevel,
        gradeLevel: GradeLevel
    ) {
        self.questionText = questionText
        self.payload = payload
        self.explanation = explanation
        self.subject = subject
        self.difficulty = difficulty
        self.gradeLevel = gradeLevel
    }
}

// MARK: - Safe Array Subscript

extension Array {
    /// Returns the element at the specified index if it's within bounds, otherwise nil.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Bridging: MultipleChoiceQuestion ↔ Question

public extension MultipleChoiceQuestion {
    /// Convert a legacy MC question to the universal Question type
    func toQuestion() -> Question {
        Question(
            questionText: question,
            payload: .multipleChoice(options: options, correctIndex: correctIndex),
            explanation: explanation,
            subject: subject,
            difficulty: difficulty,
            gradeLevel: gradeLevel
        )
    }
}

public extension Question {
    /// Convert back to an MC question if this is a multiple-choice payload.
    /// Returns nil for other question types.
    func toMultipleChoiceQuestion() -> MultipleChoiceQuestion? {
        guard case .multipleChoice(let options, let correctIndex) = payload else { return nil }
        return MultipleChoiceQuestion(
            question: questionText,
            options: options,
            correctIndex: correctIndex,
            explanation: explanation,
            subject: subject,
            difficulty: difficulty,
            gradeLevel: gradeLevel
        )
    }
}
