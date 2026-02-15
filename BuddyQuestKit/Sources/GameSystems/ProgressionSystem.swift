import Foundation

// MARK: - Progression System

/// Tracks player progression including difficulty adaptation,
/// per-subject performance, and challenge dispatch.
public final class ProgressionSystem {

    // MARK: - Per-Subject Tracking

    /// Rolling accuracy window per subject for difficulty adaptation
    private var recentResults: [Subject: [Bool]] = [:]

    /// Current difficulty per subject
    public private(set) var subjectDifficulty: [Subject: DifficultyLevel] = [
        .languageArts: .easy,
        .math: .easy,
        .science: .easy,
        .social: .easy
    ]

    /// Total challenges completed per subject
    public private(set) var subjectCompletedCount: [Subject: Int] = [
        .languageArts: 0,
        .math: 0,
        .science: 0,
        .social: 0
    ]

    /// Total correct answers per subject
    public private(set) var subjectCorrectCount: [Subject: Int] = [
        .languageArts: 0,
        .math: 0,
        .science: 0,
        .social: 0
    ]

    public init() {}

    // MARK: - Record Result

    /// Record a challenge result and adjust difficulty if needed.
    /// Returns true if difficulty changed.
    @discardableResult
    public func recordResult(subject: Subject, isCorrect: Bool) -> Bool {
        // Update counts
        subjectCompletedCount[subject, default: 0] += 1
        if isCorrect {
            subjectCorrectCount[subject, default: 0] += 1
        }

        // Add to rolling window
        var results = recentResults[subject] ?? []
        results.append(isCorrect)

        // Keep only the last N results
        let windowSize = GameConstants.difficultyWindowSize
        if results.count > windowSize {
            results = Array(results.suffix(windowSize))
        }
        recentResults[subject] = results

        // Only adapt after enough data
        guard results.count >= windowSize else { return false }

        // Calculate accuracy
        let correctCount = results.filter { $0 }.count
        let accuracy = Double(correctCount) / Double(results.count)

        let currentDifficulty = subjectDifficulty[subject] ?? .easy
        let oldDifficulty = currentDifficulty

        if accuracy >= GameConstants.difficultyIncreaseThreshold {
            // Player is acing it — increase difficulty
            subjectDifficulty[subject] = currentDifficulty.next
            // Reset window after adjustment
            recentResults[subject] = []
        } else if accuracy <= GameConstants.difficultyDecreaseThreshold {
            // Player is struggling — decrease difficulty
            subjectDifficulty[subject] = currentDifficulty.previous
            // Reset window after adjustment
            recentResults[subject] = []
        }

        return subjectDifficulty[subject] != oldDifficulty
    }

    /// Record a batch of results from a multi-question round
    public func recordResults(subject: Subject, results: [Bool]) {
        for isCorrect in results {
            recordResult(subject: subject, isCorrect: isCorrect)
        }
    }

    // MARK: - Get Next Challenge

    /// Get a random question appropriate for the player's current level in a subject
    public func nextQuestion(for subject: Subject) -> MultipleChoiceQuestion? {
        let difficulty = subjectDifficulty[subject] ?? .easy

        // Try current difficulty first
        if let q = QuestionBank.randomQuestion(subject: subject, difficulty: difficulty) {
            return q
        }

        // Fallback: try easier difficulty
        if let q = QuestionBank.randomQuestion(subject: subject, difficulty: difficulty.previous) {
            return q
        }

        // Fallback: try any difficulty
        for diff in [DifficultyLevel.beginner, .easy, .medium, .hard, .advanced] {
            if let q = QuestionBank.randomQuestion(subject: subject, difficulty: diff) {
                return q
            }
        }

        return nil
    }

    /// Pick a subject appropriate for the current zone
    public func subjectForZone(_ zoneId: String) -> Subject {
        switch zoneId {
        case "word_forest": return .languageArts
        case "number_peaks": return .math
        case "science_lab": return .science
        case "teamwork_arena": return .social
        default: return Subject.allCases.randomElement() ?? .languageArts
        }
    }

    // MARK: - Stats

    /// Overall accuracy for a subject (lifetime)
    public func accuracy(for subject: Subject) -> Double {
        let total = subjectCompletedCount[subject] ?? 0
        let correct = subjectCorrectCount[subject] ?? 0
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }

    /// Overall accuracy across all subjects
    public var overallAccuracy: Double {
        let total = subjectCompletedCount.values.reduce(0, +)
        let correct = subjectCorrectCount.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return Double(correct) / Double(total)
    }

    /// Total challenges completed across all subjects
    public var totalChallengesCompleted: Int {
        subjectCompletedCount.values.reduce(0, +)
    }

    // MARK: - Save/Load Support

    /// Restore difficulty level for a subject (called by SaveSystem)
    public func setDifficulty(_ level: DifficultyLevel, for subject: Subject) {
        subjectDifficulty[subject] = level
    }

    /// Restore completed count for a subject (called by SaveSystem)
    public func setCompletedCount(_ count: Int, for subject: Subject) {
        subjectCompletedCount[subject] = count
    }

    /// Restore correct count for a subject (called by SaveSystem)
    public func setCorrectCount(_ count: Int, for subject: Subject) {
        subjectCorrectCount[subject] = count
    }
}
