import Foundation
import SpriteKit

// MARK: - True/False Challenge (Multi-Question Round)

/// A challenge round that presents true/false statements in sequence.
/// After each answer, a brief feedback flash shows, then the next question loads.
/// After the final question, an aggregate result is returned to the engine.
public final class TrueFalseChallenge: Challenge, RoundChallenge {

    // MARK: - Challenge Protocol

    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel
    public var questionText: String { questions[currentIndex].questionText }
    public private(set) var isComplete: Bool = false

    // MARK: - Round State

    private let questions: [Question]
    private var currentIndex: Int = 0
    private var selectedIndex: Int = 0   // 0 = TRUE, 1 = FALSE

    /// Per-question results (for progression recording)
    public private(set) var perQuestionResults: [Bool] = []
    private var perQuestionXP: [Int] = []

    /// Track which option the player selected for each question (0=TRUE, 1=FALSE)
    public private(set) var perQuestionSelectedIndex: [Int] = []

    /// Whether we're in the brief per-question feedback pause
    private var isShowingPerQuestionFeedback: Bool = false
    private var feedbackTimer: TimeInterval = 0
    private var pendingAdvance: Bool = false

    // MARK: - Bond Abilities

    /// If true, buddy shows a hint at the start of each question (Good Buddy)
    public let showBuddyHints: Bool

    /// If true, player gets one second-chance retry per challenge (Best Buddy)
    public let hasSecondChance: Bool
    private var secondChanceUsed: Bool = false
    private var isShowingSecondChance: Bool = false

    /// Callback to show a buddy speech bubble with a hint
    public var onBuddyHint: ((String) -> Void)?

    // Timer
    private let timerDuration: TimeInterval = 20
    private var remainingTime: TimeInterval
    private var timerActive: Bool = true

    // UI nodes
    private var optionNodes: [SKNode] = []
    private var timerNode: SKShapeNode?
    private var timerLabel: SKLabelNode?
    private var questionContainer: SKNode?   // The whole challenge panel
    private var questionLabel: SKLabelNode?
    private var progressDots: [SKShapeNode] = []
    private var progressLabel: SKLabelNode?
    private var feedbackIcon: SKLabelNode?

    // Layout
    private let panelWidth: CGFloat = 540
    private let panelHeight: CGFloat = 420
    private let optionHeight: CGFloat = 48
    private let optionGap: CGFloat = 12

    // MARK: - Init

    /// Create a challenge round with multiple true/false questions.
    /// All questions must have `.trueFalse` payloads.
    public init(
        questions: [Question],
        showBuddyHints: Bool = false,
        hasSecondChance: Bool = false
    ) {
        self.questions = questions
        let first = questions[0]
        self.subject = first.subject
        self.difficulty = first.difficulty
        self.gradeLevel = first.gradeLevel
        self.remainingTime = 20
        self.showBuddyHints = showBuddyHints
        self.hasSecondChance = hasSecondChance
    }

    // MARK: - Build UI

    public func buildUI(on parentNode: SKNode, viewSize: CGSize) {
        let container = SKNode()
        container.name = "tfChallenge"
        parentNode.addChild(container)
        questionContainer = container

        buildQuestionUI(on: container)
    }

    /// Build (or rebuild) the UI for the current question index
    private func buildQuestionUI(on container: SKNode) {
        // Clear previous question nodes (keep container)
        container.removeAllChildren()
        optionNodes.removeAll()

        let q = questions[currentIndex]

        // Main panel (z=-1 so labels/pills render above it)
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1.0)
        panel.strokeColor = subjectColor.withAlphaComponent(0.7)
        panel.lineWidth = 2
        panel.zPosition = -1
        container.addChild(panel)

        // Progress indicator (top-left): "Q 2/5"
        let progLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        progLabel.text = "Q \(currentIndex + 1)/\(questions.count)"
        progLabel.fontSize = 12
        progLabel.fontColor = .white
        progLabel.horizontalAlignmentMode = .left
        progLabel.verticalAlignmentMode = .top
        progLabel.position = CGPoint(x: -panelWidth / 2 + 20, y: panelHeight / 2 - 14)
        container.addChild(progLabel)
        progressLabel = progLabel

        // Progress dots (next to label)
        let dotStartX = -panelWidth / 2 + 80
        let dotY = panelHeight / 2 - 18
        progressDots.removeAll()
        for i in 0..<questions.count {
            let dot = SKShapeNode(circleOfRadius: 4)
            if i < perQuestionResults.count {
                // Already answered
                dot.fillColor = perQuestionResults[i]
                    ? GameColors.correctGreen.skColor
                    : GameColors.incorrectRed.skColor
                dot.strokeColor = .clear
            } else if i == currentIndex {
                // Current question
                dot.fillColor = subjectColor
                dot.strokeColor = .clear
            } else {
                // Upcoming
                dot.fillColor = SKColor(white: 0.25, alpha: 1)
                dot.strokeColor = .clear
            }
            dot.position = CGPoint(x: dotStartX + CGFloat(i) * 14, y: dotY)
            container.addChild(dot)
            progressDots.append(dot)
        }

        // Subject badge
        let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
        badge.text = subject.rawValue
        badge.fontSize = 10
        badge.fontColor = subjectColor
        badge.horizontalAlignmentMode = .center
        badge.verticalAlignmentMode = .top
        badge.position = CGPoint(x: 0, y: panelHeight / 2 - 14)
        container.addChild(badge)

        // Timer bar (top-right)
        let timerBarWidth: CGFloat = 100
        let timerBarHeight: CGFloat = 8
        let timerBg = SKShapeNode(rectOf: CGSize(width: timerBarWidth, height: timerBarHeight), cornerRadius: 4)
        timerBg.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
        timerBg.strokeColor = .clear
        timerBg.position = CGPoint(x: panelWidth / 2 - 70, y: panelHeight / 2 - 18)
        container.addChild(timerBg)

        let fraction = CGFloat(remainingTime / timerDuration)
        let fillWidth = max(timerBarWidth * fraction, 1)
        let timerFill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: timerBarHeight - 2), cornerRadius: 3)
        timerFill.fillColor = remainingTime < 10
            ? GameColors.incorrectRed.skColor
            : GameColors.xpBarFill.skColor
        timerFill.strokeColor = .clear
        timerFill.position = CGPoint(
            x: timerBg.position.x - (timerBarWidth - fillWidth) / 2,
            y: timerBg.position.y
        )
        container.addChild(timerFill)
        timerNode = timerFill

        let timerLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        timerLbl.text = "\(Int(ceil(remainingTime)))s"
        timerLbl.fontSize = 10
        timerLbl.fontColor = remainingTime < 5 ? GameColors.incorrectRed.skColor : .white
        timerLbl.verticalAlignmentMode = .center
        timerLbl.position = CGPoint(x: panelWidth / 2 - 16, y: panelHeight / 2 - 18)
        container.addChild(timerLbl)
        timerLabel = timerLbl

        // Statement text (the question)
        let qLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        qLabel.text = q.questionText
        qLabel.fontSize = 16
        qLabel.fontColor = .white
        qLabel.horizontalAlignmentMode = .center
        qLabel.verticalAlignmentMode = .top
        qLabel.preferredMaxLayoutWidth = panelWidth - 60
        qLabel.numberOfLines = 0
        qLabel.lineBreakMode = .byWordWrapping
        qLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 50)
        container.addChild(qLabel)
        questionLabel = qLabel

        // Dynamically compute where options start based on actual question text height
        let questionTextHeight = qLabel.frame.height
        let questionBottomY = (panelHeight / 2 - 50) - questionTextHeight

        // Two pill buttons stacked vertically: TRUE and FALSE
        let optionLabels = ["\u{2713} TRUE", "\u{2717} FALSE"]
        let optionWidth = panelWidth - 120
        let optionsBlockHeight = CGFloat(optionLabels.count) * optionHeight + CGFloat(optionLabels.count - 1) * optionGap
        let idealStartY = questionBottomY - 24
        let minStartY = -panelHeight / 2 + 30 + optionsBlockHeight
        let startY = max(idealStartY, minStartY)

        for (i, optionText) in optionLabels.enumerated() {
            let y = startY - CGFloat(i) * (optionHeight + optionGap)

            let pill = SKShapeNode(rectOf: CGSize(width: optionWidth, height: optionHeight), cornerRadius: optionHeight / 2)
            pill.name = "option_\(i)"
            pill.position = CGPoint(x: 0, y: y)

            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = optionText
            label.fontSize = 16
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: 0)
            pill.addChild(label)

            container.addChild(pill)
            optionNodes.append(pill)
        }

        // Navigation hint
        let navHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        navHint.text = "\u{2191}\u{2193} Select  \u{2022}  E/Enter Confirm"
        navHint.fontSize = 10
        navHint.fontColor = SKColor(white: 0.5, alpha: 1)
        navHint.verticalAlignmentMode = .center
        navHint.position = CGPoint(x: 0, y: -panelHeight / 2 + 16)
        container.addChild(navHint)

        // Reset selection
        selectedIndex = 0
        isShowingSecondChance = false
        updateOptionHighlight()

        // Trigger buddy hint if unlocked
        if showBuddyHints {
            let hint = generateHint(for: q)
            onBuddyHint?(hint)
        }
    }

    /// Generate a simple hint for the question (based on the correct answer)
    private func generateHint(for q: Question) -> String {
        guard case .trueFalse(let correctAnswer) = q.payload else {
            return "Hmm, I have a feeling about this one!"
        }
        if correctAnswer {
            return "I think this statement might be right..."
        } else {
            return "Something about this doesn't seem quite right..."
        }
    }

    // MARK: - Input

    public func handleInput(_ input: InputState) -> ChallengeResult? {
        // If showing per-question feedback, block input (auto-advances via timer)
        if isShowingPerQuestionFeedback {
            return nil
        }

        // If round is complete, return nil
        if isComplete {
            return nil
        }

        // Navigate
        if input.isPressed(.moveUp) {
            selectedIndex = (selectedIndex - 1 + 2) % 2
            updateOptionHighlight()
        }
        if input.isPressed(.moveDown) {
            selectedIndex = (selectedIndex + 1) % 2
            updateOptionHighlight()
        }

        // Confirm selection
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            // Remove second chance overlay if present
            questionContainer?.childNode(withName: "secondChanceOverlay")?.removeFromParent()
            submitCurrentAnswer()
        }

        return nil
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval) {
        guard !isComplete else { return }

        // Per-question feedback timer (brief feedback flash)
        if isShowingPerQuestionFeedback {
            feedbackTimer += deltaTime
            if feedbackTimer >= GameConstants.perQuestionFeedbackDuration {
                advanceToNextQuestion()
            }
            return
        }

        // Main challenge timer
        if timerActive {
            remainingTime -= deltaTime
            if remainingTime <= 0 {
                remainingTime = 0
                timerActive = false
                // Time's up — auto-submit current selection
                submitCurrentAnswer()
            }

            // Update timer visuals
            updateTimerUI()
        }
    }

    // MARK: - Teardown

    public func teardown() {
        questionContainer?.removeFromParent()
        questionContainer = nil
        optionNodes.removeAll()
        progressDots.removeAll()
        timerNode = nil
        timerLabel = nil
        questionLabel = nil
        progressLabel = nil
        feedbackIcon = nil
    }

    // MARK: - Private: Answer Submission

    private func submitCurrentAnswer() {
        let q = questions[currentIndex]

        guard case .trueFalse(let correctAnswer) = q.payload else {
            // Should not happen — all questions must be trueFalse
            perQuestionResults.append(false)
            perQuestionXP.append(GameConstants.xpPerWrongAnswer)
            perQuestionSelectedIndex.append(selectedIndex)
            showPerQuestionFeedback(isCorrect: false)
            isShowingPerQuestionFeedback = true
            feedbackTimer = 0
            return
        }

        // selectedIndex 0 = TRUE, 1 = FALSE
        let playerAnswer = (selectedIndex == 0)
        let isCorrect = (playerAnswer == correctAnswer)

        // Second chance: if wrong and not yet used, offer retry
        if !isCorrect && hasSecondChance && !secondChanceUsed && !isShowingSecondChance {
            isShowingSecondChance = true
            secondChanceUsed = true
            showSecondChancePrompt()
            return
        }

        let timeBonus = remainingTime > 15 ? 2 : (remainingTime > 8 ? 1 : 0)
        let baseXP = isCorrect ? GameConstants.xpPerCorrectAnswer : GameConstants.xpPerWrongAnswer
        let xp = baseXP + (isCorrect ? timeBonus : 0)

        // Record
        perQuestionResults.append(isCorrect)
        perQuestionXP.append(xp)
        perQuestionSelectedIndex.append(selectedIndex)

        // Highlight correct/wrong
        let correctIndex = correctAnswer ? 0 : 1
        highlightAnswer(selected: selectedIndex, correct: correctIndex)

        // Show inline feedback icon
        showPerQuestionFeedback(isCorrect: isCorrect)

        // Start feedback pause
        isShowingPerQuestionFeedback = true
        feedbackTimer = 0
    }

    /// Show a "Try Again?" overlay for the second chance ability
    private func showSecondChancePrompt() {
        guard let container = questionContainer else { return }

        // Dim wrong answer option
        if selectedIndex < optionNodes.count,
           let pill = optionNodes[selectedIndex] as? SKShapeNode {
            pill.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.2)
            pill.strokeColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.4)
        }

        // Show "Try Again!" overlay
        let overlay = SKNode()
        overlay.name = "secondChanceOverlay"
        overlay.zPosition = 5

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "\u{2764}\u{FE0F} Your buddy gives you another chance! Try again!"
        label.fontSize = 13
        label.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.7, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: -panelHeight / 2 + 36)
        overlay.addChild(label)

        // Pulse animation
        label.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))

        container.addChild(overlay)

        // Flip selection to the other option
        selectedIndex = (selectedIndex + 1) % 2
        updateOptionHighlight()
    }

    private func showPerQuestionFeedback(isCorrect: Bool) {
        guard let container = questionContainer else { return }

        // Big checkmark/cross overlay — brief flash
        let icon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        icon.text = isCorrect ? "\u{2713}" : "\u{2717}"
        icon.fontSize = 54
        icon.fontColor = isCorrect
            ? GameColors.correctGreen.skColor
            : GameColors.incorrectRed.skColor
        icon.verticalAlignmentMode = .center
        icon.horizontalAlignmentMode = .center
        icon.position = CGPoint(x: panelWidth / 2 - 50, y: 0)
        icon.alpha = 0
        icon.setScale(0.5)
        icon.run(.group([
            .fadeAlpha(to: 0.9, duration: 0.15),
            .scale(to: 1.2, duration: 0.15)
        ]))
        icon.name = "feedbackIcon"
        container.addChild(icon)
        feedbackIcon = icon

        // Update the current progress dot
        if currentIndex < progressDots.count {
            progressDots[currentIndex].fillColor = isCorrect
                ? GameColors.correctGreen.skColor
                : GameColors.incorrectRed.skColor
        }
    }

    private func advanceToNextQuestion() {
        isShowingPerQuestionFeedback = false

        // Remove feedback icon
        feedbackIcon?.removeFromParent()
        feedbackIcon = nil

        if currentIndex + 1 < questions.count {
            // More questions — load next
            currentIndex += 1
            selectedIndex = 0

            // Reset timer for next question
            remainingTime = timerDuration
            timerActive = true

            // Rebuild the question UI
            if let container = questionContainer {
                buildQuestionUI(on: container)
            }
        } else {
            // Round complete — mark as done so ChallengeEngine can show final result
            isComplete = true
        }
    }

    // MARK: - Aggregate Result

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

    // MARK: - RoundChallenge Protocol

    /// All questions in this round (as universal Question type)
    public var allRoundQuestions: [Question] {
        questions
    }

    /// Get correction info for a specific wrong-answer index
    public func correctionInfo(for questionIndex: Int) -> (playerAnswer: String, correctAnswer: String, explanation: String)? {
        guard questionIndex < questions.count,
              questionIndex < perQuestionSelectedIndex.count else { return nil }
        let q = questions[questionIndex]
        guard case .trueFalse(let correctAnswer) = q.payload else { return nil }
        let selectedIdx = perQuestionSelectedIndex[questionIndex]
        let playerAnswerStr = selectedIdx == 0 ? "True" : "False"
        let correctAnswerStr = correctAnswer ? "True" : "False"
        return (playerAnswer: playerAnswerStr, correctAnswer: correctAnswerStr, explanation: q.explanation)
    }

    // MARK: - Private: UI Helpers

    private func highlightAnswer(selected: Int, correct: Int) {
        for (i, node) in optionNodes.enumerated() {
            guard let pill = node as? SKShapeNode else { continue }
            if i == correct {
                pill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                pill.strokeColor = GameColors.correctGreen.skColor
            } else if i == selected && selected != correct {
                pill.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.3)
                pill.strokeColor = GameColors.incorrectRed.skColor
            } else {
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.15, alpha: 0.5)
                pill.strokeColor = SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.4)
            }
        }
    }

    private func updateOptionHighlight() {
        for (i, node) in optionNodes.enumerated() {
            guard let pill = node as? SKShapeNode else { continue }
            if i == selectedIndex {
                pill.fillColor = subjectColor.withAlphaComponent(0.15)
                pill.strokeColor = subjectColor.withAlphaComponent(0.8)
                pill.lineWidth = 1.5
            } else {
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
                pill.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
                pill.lineWidth = 1
            }
        }
    }

    private func updateTimerUI() {
        guard let container = questionContainer else { return }

        let timerBarWidth: CGFloat = 100
        let fraction = CGFloat(remainingTime / timerDuration)
        let fillWidth = max(timerBarWidth * fraction, 1)

        timerNode?.removeFromParent()
        let newFill = SKShapeNode(rectOf: CGSize(width: fillWidth, height: 6), cornerRadius: 3)
        newFill.fillColor = remainingTime < 10
            ? GameColors.incorrectRed.skColor
            : GameColors.xpBarFill.skColor
        newFill.strokeColor = .clear
        newFill.position = CGPoint(
            x: panelWidth / 2 - 70 - (timerBarWidth - fillWidth) / 2,
            y: panelHeight / 2 - 18
        )
        container.addChild(newFill)
        timerNode = newFill

        timerLabel?.text = "\(Int(ceil(remainingTime)))s"
        if remainingTime < 5 {
            timerLabel?.fontColor = GameColors.incorrectRed.skColor
        }
    }

    private var subjectColor: SKColor {
        switch subject {
        case .math: return GameColors.numberPeaksPrimary.skColor
        case .languageArts: return GameColors.wordForestPrimary.skColor
        case .science: return GameColors.scienceLabPrimary.skColor
        case .social: return GameColors.teamworkArenaPrimary.skColor
        }
    }
}
