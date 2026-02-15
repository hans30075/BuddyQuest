import Foundation
import SpriteKit

// MARK: - Mixed Round Challenge (Multi-Type Orchestrator)

/// A challenge round that sequences through questions of MIXED types
/// (multipleChoice, trueFalse, ordering, matching) in a single round.
///
/// MixedRoundChallenge is purely an orchestrator -- it has no UI of its own.
/// For each question, it instantiates the appropriate single-question sub-challenge
/// and delegates all UI/input/update to it. When the sub-challenge completes,
/// it records the result, tears down the sub-challenge, and advances to the next.
public final class MixedRoundChallenge: Challenge, RoundChallenge {

    // MARK: - Challenge Protocol

    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel
    public var questionText: String {
        guard currentIndex < questions.count else { return "" }
        return questions[currentIndex].questionText
    }
    public private(set) var isComplete: Bool = false

    // MARK: - Round State

    private let questions: [Question]
    private var currentIndex: Int = 0
    private var currentSubChallenge: Challenge?

    /// Per-question correct/incorrect results in order
    public private(set) var perQuestionResults: [Bool] = []
    private var perQuestionXP: [Int] = []

    /// Stored correction info from each completed sub-challenge.
    /// Indexed by question index; nil if the question was answered correctly.
    private var perQuestionCorrectionInfo: [(playerAnswer: String, correctAnswer: String, explanation: String)?] = []

    // MARK: - Bond Abilities

    /// If true, buddy shows a hint at the start of each question (Good Buddy)
    public let showBuddyHints: Bool

    /// If true, player gets one second-chance retry per challenge (Best Buddy)
    public let hasSecondChance: Bool

    /// Callback to show a buddy speech bubble with a hint
    public var onBuddyHint: ((String) -> Void)?

    // MARK: - UI References

    /// The parent node passed to buildUI; kept so we can build sub-challenges on it
    private weak var parentNode: SKNode?
    private var viewSize: CGSize = .zero

    // MARK: - Init

    /// Create a mixed-type challenge round.
    /// The questions array can contain any combination of QuestionTypes.
    public init(
        questions: [Question],
        showBuddyHints: Bool = false,
        hasSecondChance: Bool = false
    ) {
        precondition(!questions.isEmpty, "MixedRoundChallenge requires at least one question")
        self.questions = questions
        let first = questions[0]
        self.subject = first.subject
        self.difficulty = first.difficulty
        self.gradeLevel = first.gradeLevel
        self.showBuddyHints = showBuddyHints
        self.hasSecondChance = hasSecondChance
    }

    // MARK: - Build UI

    public func buildUI(on parentNode: SKNode, viewSize: CGSize) {
        self.parentNode = parentNode
        self.viewSize = viewSize

        // Instantiate the first sub-challenge and build its UI
        instantiateSubChallenge(for: currentIndex)
        currentSubChallenge?.buildUI(on: parentNode, viewSize: viewSize)
    }

    // MARK: - Input

    public func handleInput(_ input: InputState) -> ChallengeResult? {
        guard !isComplete else { return nil }

        // Delegate to current sub-challenge
        let result = currentSubChallenge?.handleInput(input)

        // Check if the sub-challenge completed itself via input
        checkSubChallengeCompletion()

        // We never return a per-question result to ChallengeEngine;
        // the engine checks isComplete via the update loop.
        _ = result
        return nil
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval) {
        guard !isComplete else { return }

        currentSubChallenge?.update(deltaTime: deltaTime)

        // Check if the sub-challenge completed after its update
        checkSubChallengeCompletion()
    }

    // MARK: - Teardown

    public func teardown() {
        currentSubChallenge?.teardown()
        currentSubChallenge = nil
        parentNode = nil
    }

    // MARK: - RoundChallenge Protocol

    /// All questions in this round
    public var allRoundQuestions: [Question] {
        questions
    }

    /// Build the aggregate result for the entire round.
    /// Called by ChallengeEngine when `isComplete` is true.
    public func buildAggregateResult() -> ChallengeResult {
        let correctCount = perQuestionResults.filter { $0 }.count
        let totalXP = perQuestionXP.reduce(0, +)
        let majorityCorrect = correctCount > questions.count / 2

        let feedback = "You got \(correctCount) out of \(questions.count) correct!"

        return ChallengeResult(
            isCorrect: majorityCorrect,
            xpAwarded: totalXP,
            feedbackMessage: feedback,
            selectedAnswer: "\(correctCount)/\(questions.count)",
            correctAnswer: "\(questions.count)/\(questions.count)"
        )
    }

    /// Get correction info for a specific wrong-answer index.
    /// Returns the stored correction info captured when the sub-challenge completed.
    public func correctionInfo(for questionIndex: Int) -> (playerAnswer: String, correctAnswer: String, explanation: String)? {
        guard questionIndex < perQuestionCorrectionInfo.count else { return nil }
        return perQuestionCorrectionInfo[questionIndex]
    }

    // MARK: - Private: Sub-Challenge Lifecycle

    /// Check if the current sub-challenge has completed, and if so, record
    /// its results and advance to the next question (or mark the round complete).
    private func checkSubChallengeCompletion() {
        guard let sub = currentSubChallenge, sub.isComplete else { return }

        // Extract the result from the sub-challenge's RoundChallenge conformance
        if let roundSub = sub as? RoundChallenge {
            let wasCorrect = roundSub.perQuestionResults.last ?? false
            perQuestionResults.append(wasCorrect)

            // Compute XP from the sub-challenge's aggregate
            let subResult = roundSub.buildAggregateResult()
            perQuestionXP.append(subResult.xpAwarded)

            // Capture correction info if wrong
            if !wasCorrect {
                // The sub-challenge had only 1 question, so index 0
                let info = roundSub.correctionInfo(for: 0)
                perQuestionCorrectionInfo.append(info)
            } else {
                perQuestionCorrectionInfo.append(nil)
            }
        } else {
            // Fallback: sub-challenge doesn't conform to RoundChallenge
            perQuestionResults.append(false)
            perQuestionXP.append(GameConstants.xpPerWrongAnswer)
            perQuestionCorrectionInfo.append(nil)
        }

        // Tear down the current sub-challenge
        currentSubChallenge?.teardown()
        currentSubChallenge = nil

        // Advance to next question or mark round complete
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            instantiateSubChallenge(for: currentIndex)
            if let parent = parentNode {
                currentSubChallenge?.buildUI(on: parent, viewSize: viewSize)
            }
        } else {
            isComplete = true
        }
    }

    /// Create the appropriate single-question sub-challenge for the given index.
    private func instantiateSubChallenge(for index: Int) {
        let question = questions[index]

        switch question.questionType {
        case .multipleChoice:
            guard let mcQuestion = question.toMultipleChoiceQuestion() else { return }
            let challenge = MultipleChoiceChallenge(
                questions: [mcQuestion],
                showBuddyHints: showBuddyHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = onBuddyHint
            currentSubChallenge = challenge

        case .trueFalse:
            let challenge = TrueFalseChallenge(
                questions: [question],
                showBuddyHints: showBuddyHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = onBuddyHint
            currentSubChallenge = challenge

        case .ordering:
            let challenge = OrderingChallenge(
                questions: [question],
                showBuddyHints: showBuddyHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = onBuddyHint
            currentSubChallenge = challenge

        case .matching:
            let challenge = MatchingChallenge(
                questions: [question],
                showBuddyHints: showBuddyHints,
                hasSecondChance: hasSecondChance
            )
            challenge.onBuddyHint = onBuddyHint
            currentSubChallenge = challenge
        }
    }
}
