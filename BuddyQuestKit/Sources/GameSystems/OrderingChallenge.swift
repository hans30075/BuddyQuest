import Foundation
import SpriteKit

// MARK: - Ordering Challenge (Multi-Question Round)

/// A challenge round that presents ordering/sequence questions.
/// Player arranges items in the correct order using keyboard grab-and-move.
/// After each submission, a brief feedback flash shows, then the next question loads.
/// After the final question, an aggregate result is returned to the engine.
public final class OrderingChallenge: Challenge, RoundChallenge {

    // MARK: - Ordering State Machine

    private enum OrderingState {
        case navigating              // Up/Down moves focus between items
        case grabbed(index: Int)     // Up/Down swaps the grabbed item with neighbors
        case submitFocused           // Focus is on the Submit button
    }

    // MARK: - Challenge Protocol

    public let subject: Subject
    public let difficulty: DifficultyLevel
    public let gradeLevel: GradeLevel
    public var questionText: String { questions[currentIndex].questionText }
    public private(set) var isComplete: Bool = false

    // MARK: - Round State

    private let questions: [Question]
    private var currentIndex: Int = 0

    /// Per-question results (for progression recording)
    public private(set) var perQuestionResults: [Bool] = []
    private var perQuestionXP: [Int] = []

    /// Track the player's final item ordering per question (display indices)
    private var perQuestionPlayerOrdering: [[Int]] = []

    /// Whether we're in the brief per-question feedback pause
    private var isShowingPerQuestionFeedback: Bool = false
    private var feedbackTimer: TimeInterval = 0

    // MARK: - Ordering State

    private var orderingState: OrderingState = .navigating
    private var focusedIndex: Int = 0

    /// Current item ordering: currentOrder[displayPosition] = original item index
    /// Starts as [0, 1, 2, ...] (matching the display order from the payload)
    private var currentOrder: [Int] = []

    /// The items text array for the current question
    private var currentItems: [String] = []

    /// The correct ordering from the payload
    private var currentCorrectOrder: [Int] = []

    /// Whether the player has made at least one swap (for submit button activation)
    private var hasMadeMove: Bool = false

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
    private let timerDuration: TimeInterval = 45
    private var remainingTime: TimeInterval = 45
    private var timerActive: Bool = true

    // UI nodes
    private var itemNodes: [SKShapeNode] = []
    private var itemLabels: [SKLabelNode] = []
    private var positionLabels: [SKLabelNode] = []
    private var submitNode: SKShapeNode?
    private var submitLabel: SKLabelNode?
    private var timerNode: SKShapeNode?
    private var timerLabel: SKLabelNode?
    private var questionContainer: SKNode?
    private var questionLabel: SKLabelNode?
    private var progressDots: [SKShapeNode] = []
    private var progressLabel: SKLabelNode?
    private var feedbackIcon: SKLabelNode?
    private var navHintLabel: SKLabelNode?

    // Layout
    private let panelWidth: CGFloat = 540
    private let panelHeight: CGFloat = 420
    private let itemHeight: CGFloat = 36
    private let itemGap: CGFloat = 8

    // MARK: - Init

    /// Create an ordering challenge round with multiple questions
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
        self.remainingTime = timerDuration
        self.showBuddyHints = showBuddyHints
        self.hasSecondChance = hasSecondChance
    }

    // MARK: - Build UI

    public func buildUI(on parentNode: SKNode, viewSize: CGSize) {
        let container = SKNode()
        container.name = "orderingChallenge"
        parentNode.addChild(container)
        questionContainer = container

        buildQuestionUI(on: container)
    }

    /// Build (or rebuild) the UI for the current question index
    private func buildQuestionUI(on container: SKNode) {
        // Clear previous question nodes
        container.removeAllChildren()
        itemNodes.removeAll()
        itemLabels.removeAll()
        positionLabels.removeAll()
        submitNode = nil
        submitLabel = nil

        let q = questions[currentIndex]

        // Extract ordering payload
        guard case .ordering(let items, let correctOrder) = q.payload else { return }
        currentItems = items
        currentCorrectOrder = correctOrder
        currentOrder = Array(0..<items.count)
        hasMadeMove = false

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

        // Progress dots
        let dotStartX = -panelWidth / 2 + 80
        let dotY = panelHeight / 2 - 18
        progressDots.removeAll()
        for i in 0..<questions.count {
            let dot = SKShapeNode(circleOfRadius: 4)
            if i < perQuestionResults.count {
                dot.fillColor = perQuestionResults[i]
                    ? GameColors.correctGreen.skColor
                    : GameColors.incorrectRed.skColor
                dot.strokeColor = .clear
            } else if i == currentIndex {
                dot.fillColor = subjectColor
                dot.strokeColor = .clear
            } else {
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

        // Question/instruction text
        let qLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        qLabel.text = q.questionText
        qLabel.fontSize = 15
        qLabel.fontColor = .white
        qLabel.horizontalAlignmentMode = .center
        qLabel.verticalAlignmentMode = .top
        qLabel.preferredMaxLayoutWidth = panelWidth - 60
        qLabel.numberOfLines = 0
        qLabel.lineBreakMode = .byWordWrapping
        qLabel.position = CGPoint(x: 0, y: panelHeight / 2 - 40)
        container.addChild(qLabel)
        questionLabel = qLabel

        // Compute item list layout
        let questionTextHeight = qLabel.frame.height
        let questionBottomY = (panelHeight / 2 - 40) - questionTextHeight
        let itemCount = items.count
        let itemsBlockHeight = CGFloat(itemCount) * itemHeight + CGFloat(itemCount - 1) * itemGap
        // Leave room for submit button + nav hint below items
        let submitAreaHeight: CGFloat = 56
        let idealStartY = questionBottomY - 16
        let minStartY = -panelHeight / 2 + 30 + submitAreaHeight + itemsBlockHeight
        let startY = max(idealStartY, minStartY)
        let itemWidth = panelWidth - 80

        // Build item pills
        for i in 0..<itemCount {
            let y = startY - CGFloat(i) * (itemHeight + itemGap)

            let pill = SKShapeNode(rectOf: CGSize(width: itemWidth, height: itemHeight), cornerRadius: itemHeight / 2)
            pill.name = "orderItem_\(i)"
            pill.position = CGPoint(x: 0, y: y)

            // Position number label on left
            let posLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
            posLabel.text = "\(i + 1)."
            posLabel.fontSize = 13
            posLabel.fontColor = subjectColor
            posLabel.verticalAlignmentMode = .center
            posLabel.horizontalAlignmentMode = .left
            posLabel.position = CGPoint(x: -itemWidth / 2 + 16, y: 0)
            pill.addChild(posLabel)

            // Item text label
            let itemLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
            itemLabel.text = items[currentOrder[i]]
            itemLabel.fontSize = 12
            itemLabel.fontColor = .white
            itemLabel.verticalAlignmentMode = .center
            itemLabel.horizontalAlignmentMode = .left
            itemLabel.preferredMaxLayoutWidth = itemWidth - 60
            itemLabel.numberOfLines = 1
            itemLabel.lineBreakMode = .byTruncatingTail
            itemLabel.position = CGPoint(x: -itemWidth / 2 + 44, y: 0)
            pill.addChild(itemLabel)

            container.addChild(pill)
            itemNodes.append(pill)
            itemLabels.append(itemLabel)
            positionLabels.append(posLabel)
        }

        // Submit button pill (below items)
        let lastItemY = startY - CGFloat(itemCount - 1) * (itemHeight + itemGap)
        let submitY = lastItemY - itemHeight / 2 - 20

        let submitPill = SKShapeNode(rectOf: CGSize(width: 160, height: 30), cornerRadius: 15)
        submitPill.name = "submitOrder"
        submitPill.position = CGPoint(x: 0, y: submitY)
        container.addChild(submitPill)
        submitNode = submitPill

        let subLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        subLabel.text = "Submit Order"
        subLabel.fontSize = 12
        subLabel.verticalAlignmentMode = .center
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = .zero
        submitPill.addChild(subLabel)
        submitLabel = subLabel

        // Navigation hint
        let navHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        navHint.text = "\u{2191}\u{2193} Move  \u{2022}  E Grab/Drop  \u{2022}  Submit to check"
        navHint.fontSize = 10
        navHint.fontColor = SKColor(white: 0.5, alpha: 1)
        navHint.verticalAlignmentMode = .center
        navHint.position = CGPoint(x: 0, y: -panelHeight / 2 + 16)
        container.addChild(navHint)
        navHintLabel = navHint

        // Reset state
        focusedIndex = 0
        orderingState = .navigating
        isShowingSecondChance = false
        updateItemHighlights()
        updateSubmitButton()

        // Trigger buddy hint if unlocked
        if showBuddyHints {
            let hint = generateHint(for: q)
            onBuddyHint?(hint)
        }
    }

    /// Generate a simple hint for an ordering question
    private func generateHint(for q: Question) -> String {
        guard case .ordering(let items, let correctOrder) = q.payload,
              !correctOrder.isEmpty else {
            return "Think carefully about the correct order!"
        }
        // Hint: reveal the first item in the correct sequence
        let firstCorrectItemIndex = correctOrder[0]
        if firstCorrectItemIndex < items.count {
            let firstItem = items[firstCorrectItemIndex]
            return "I think \"\(firstItem)\" goes first..."
        }
        return "Think about what comes first!"
    }

    // MARK: - Input

    public func handleInput(_ input: InputState) -> ChallengeResult? {
        // Block input during feedback
        if isShowingPerQuestionFeedback { return nil }
        if isComplete { return nil }

        switch orderingState {
        case .navigating:
            handleNavigatingInput(input)
        case .grabbed(let grabbedIndex):
            handleGrabbedInput(input, grabbedIndex: grabbedIndex)
        case .submitFocused:
            handleSubmitFocusedInput(input)
        }

        return nil
    }

    private func handleNavigatingInput(_ input: InputState) {
        let itemCount = currentItems.count

        if input.isPressed(.moveUp) {
            if focusedIndex > 0 {
                focusedIndex -= 1
            }
            updateItemHighlights()
            updateSubmitButton()
        }

        if input.isPressed(.moveDown) {
            if focusedIndex < itemCount - 1 {
                focusedIndex += 1
                updateItemHighlights()
                updateSubmitButton()
            } else {
                // Past last item -> focus submit button
                orderingState = .submitFocused
                updateItemHighlights()
                updateSubmitButton()
            }
        }

        // Grab the focused item
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            orderingState = .grabbed(index: focusedIndex)
            updateItemHighlights()
        }
    }

    private func handleGrabbedInput(_ input: InputState, grabbedIndex: Int) {
        let itemCount = currentItems.count

        if input.isPressed(.moveUp) {
            if grabbedIndex > 0 {
                swapItems(at: grabbedIndex, with: grabbedIndex - 1)
                focusedIndex = grabbedIndex - 1
                orderingState = .grabbed(index: grabbedIndex - 1)
                hasMadeMove = true
                updateItemHighlights()
                updateSubmitButton()
            }
        }

        if input.isPressed(.moveDown) {
            if grabbedIndex < itemCount - 1 {
                swapItems(at: grabbedIndex, with: grabbedIndex + 1)
                focusedIndex = grabbedIndex + 1
                orderingState = .grabbed(index: grabbedIndex + 1)
                hasMadeMove = true
                updateItemHighlights()
                updateSubmitButton()
            }
        }

        // Drop the item
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            orderingState = .navigating
            updateItemHighlights()
        }
    }

    private func handleSubmitFocusedInput(_ input: InputState) {
        if input.isPressed(.moveUp) {
            // Back to last item
            focusedIndex = currentItems.count - 1
            orderingState = .navigating
            updateItemHighlights()
            updateSubmitButton()
        }

        if input.isPressed(.interact) || input.isPressed(.confirm) {
            // Remove second chance overlay if present
            questionContainer?.childNode(withName: "secondChanceOverlay")?.removeFromParent()
            submitCurrentAnswer()
        }
    }

    // MARK: - Item Swapping

    private func swapItems(at indexA: Int, with indexB: Int) {
        guard indexA >= 0, indexA < currentOrder.count,
              indexB >= 0, indexB < currentOrder.count else { return }

        // Swap in the order array
        currentOrder.swapAt(indexA, indexB)

        // Animate the two pills trading positions
        guard indexA < itemNodes.count, indexB < itemNodes.count else { return }

        let nodeA = itemNodes[indexA]
        let nodeB = itemNodes[indexB]
        let posA = nodeA.position
        let posB = nodeB.position

        let moveA = SKAction.move(to: posB, duration: 0.15)
        let moveB = SKAction.move(to: posA, duration: 0.15)
        moveA.timingMode = .easeInEaseOut
        moveB.timingMode = .easeInEaseOut

        nodeA.run(moveA)
        nodeB.run(moveB)

        // Swap the node references so indices stay aligned with visual positions
        itemNodes.swapAt(indexA, indexB)
        itemLabels.swapAt(indexA, indexB)
        positionLabels.swapAt(indexA, indexB)

        // Update text labels to reflect new ordering
        updateItemTexts()
    }

    private func updateItemTexts() {
        for i in 0..<currentOrder.count {
            guard i < itemLabels.count, i < positionLabels.count else { continue }
            let itemIndex = currentOrder[i]
            if itemIndex < currentItems.count {
                itemLabels[i].text = currentItems[itemIndex]
            }
            positionLabels[i].text = "\(i + 1)."
        }
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval) {
        guard !isComplete else { return }

        // Per-question feedback timer
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
                // Time's up -- auto-submit
                submitCurrentAnswer()
            }

            updateTimerUI()
        }
    }

    // MARK: - Teardown

    public func teardown() {
        questionContainer?.removeFromParent()
        questionContainer = nil
        itemNodes.removeAll()
        itemLabels.removeAll()
        positionLabels.removeAll()
        progressDots.removeAll()
        submitNode = nil
        submitLabel = nil
        timerNode = nil
        timerLabel = nil
        questionLabel = nil
        progressLabel = nil
        feedbackIcon = nil
        navHintLabel = nil
    }

    // MARK: - Private: Answer Submission

    private func submitCurrentAnswer() {
        let isCorrect = checkOrdering()

        // Second chance: if wrong and not yet used, offer retry
        if !isCorrect && hasSecondChance && !secondChanceUsed && !isShowingSecondChance {
            isShowingSecondChance = true
            secondChanceUsed = true
            showSecondChancePrompt()
            return
        }

        let timeBonus = remainingTime > 20 ? 2 : (remainingTime > 10 ? 1 : 0)
        let baseXP = isCorrect ? GameConstants.xpPerCorrectAnswer : GameConstants.xpPerWrongAnswer
        let xp = baseXP + (isCorrect ? timeBonus : 0)

        // Record
        perQuestionResults.append(isCorrect)
        perQuestionXP.append(xp)
        perQuestionPlayerOrdering.append(currentOrder)

        // Highlight correct/wrong items
        highlightOrderingResult(isCorrect: isCorrect)

        // Show inline feedback icon
        showPerQuestionFeedback(isCorrect: isCorrect)

        // Start feedback pause
        isShowingPerQuestionFeedback = true
        feedbackTimer = 0
    }

    /// Check if the player's current ordering matches the correct ordering
    private func checkOrdering() -> Bool {
        guard currentOrder.count == currentCorrectOrder.count else { return false }
        for i in 0..<currentOrder.count {
            if currentOrder[i] != currentCorrectOrder[i] {
                return false
            }
        }
        return true
    }

    /// Show a "Try Again?" overlay for the second chance ability
    private func showSecondChancePrompt() {
        guard let container = questionContainer else { return }

        let overlay = SKNode()
        overlay.name = "secondChanceOverlay"
        overlay.zPosition = 5

        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = "\u{2764}\u{FE0F} Your buddy gives you another chance! Rearrange and resubmit!"
        label.fontSize = 13
        label.fontColor = SKColor(red: 1.0, green: 0.5, blue: 0.7, alpha: 1)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.preferredMaxLayoutWidth = panelWidth - 60
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.position = CGPoint(x: 0, y: -panelHeight / 2 + 36)
        overlay.addChild(label)

        // Pulse animation
        label.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.5, duration: 0.6),
            .fadeAlpha(to: 1.0, duration: 0.6)
        ])))

        container.addChild(overlay)

        // Go back to navigating so the player can rearrange
        orderingState = .navigating
        focusedIndex = 0
        updateItemHighlights()
        updateSubmitButton()
    }

    private func showPerQuestionFeedback(isCorrect: Bool) {
        guard let container = questionContainer else { return }

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

    private func highlightOrderingResult(isCorrect: Bool) {
        if isCorrect {
            // All items green
            for pill in itemNodes {
                pill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                pill.strokeColor = GameColors.correctGreen.skColor
            }
        } else {
            // Highlight each item: green if in correct position, red if not
            for i in 0..<currentOrder.count {
                guard i < itemNodes.count else { continue }
                let pill = itemNodes[i]
                if currentOrder[i] == currentCorrectOrder[i] {
                    pill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                    pill.strokeColor = GameColors.correctGreen.skColor
                } else {
                    pill.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.3)
                    pill.strokeColor = GameColors.incorrectRed.skColor
                }
            }
        }
    }

    private func advanceToNextQuestion() {
        isShowingPerQuestionFeedback = false

        // Remove feedback icon
        feedbackIcon?.removeFromParent()
        feedbackIcon = nil

        if currentIndex + 1 < questions.count {
            // More questions -- load next
            currentIndex += 1
            focusedIndex = 0
            orderingState = .navigating

            // Reset timer for next question
            remainingTime = timerDuration
            timerActive = true

            // Rebuild the question UI
            if let container = questionContainer {
                buildQuestionUI(on: container)
            }
        } else {
            // Round complete
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

    /// All questions in this round (already universal Question type)
    public var allRoundQuestions: [Question] {
        questions
    }

    /// Get correction info for a specific wrong-answer index
    public func correctionInfo(for questionIndex: Int) -> (playerAnswer: String, correctAnswer: String, explanation: String)? {
        guard questionIndex < questions.count,
              questionIndex < perQuestionPlayerOrdering.count else { return nil }

        let q = questions[questionIndex]
        guard case .ordering(let items, let correctOrder) = q.payload else { return nil }

        let playerOrder = perQuestionPlayerOrdering[questionIndex]

        // Build "Your order: A, B, C" string
        let playerOrderStr = playerOrder.map { idx in
            idx < items.count ? items[idx] : "?"
        }.joined(separator: ", ")

        // Build "Correct: C, A, B" string
        let correctOrderStr = correctOrder.map { idx in
            idx < items.count ? items[idx] : "?"
        }.joined(separator: ", ")

        return (
            playerAnswer: playerOrderStr,
            correctAnswer: correctOrderStr,
            explanation: q.explanation
        )
    }

    // MARK: - Private: UI Helpers

    private func updateItemHighlights() {
        let isSubmitFocused: Bool
        if case .submitFocused = orderingState {
            isSubmitFocused = true
        } else {
            isSubmitFocused = false
        }

        for (i, pill) in itemNodes.enumerated() {
            switch orderingState {
            case .grabbed(let grabbedIdx) where i == grabbedIdx:
                // Grabbed item: brighter glow, scale up
                pill.fillColor = subjectColor.withAlphaComponent(0.3)
                pill.strokeColor = subjectColor
                pill.lineWidth = 2.5
                pill.setScale(1.05)
            case .navigating where i == focusedIndex && !isSubmitFocused:
                // Focused item: subject-colored border
                pill.fillColor = subjectColor.withAlphaComponent(0.15)
                pill.strokeColor = subjectColor.withAlphaComponent(0.8)
                pill.lineWidth = 1.5
                pill.setScale(1.0)
            case .grabbed where i == focusedIndex:
                // This shouldn't occur since grabbed always matches focusedIndex,
                // but handle gracefully
                pill.fillColor = subjectColor.withAlphaComponent(0.15)
                pill.strokeColor = subjectColor.withAlphaComponent(0.8)
                pill.lineWidth = 1.5
                pill.setScale(1.0)
            default:
                // Default unfocused style
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
                pill.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
                pill.lineWidth = 1
                pill.setScale(1.0)
            }
        }
    }

    private func updateSubmitButton() {
        guard let submitPill = submitNode, let subLabel = submitLabel else { return }

        let isSubmitFocused: Bool
        if case .submitFocused = orderingState {
            isSubmitFocused = true
        } else {
            isSubmitFocused = false
        }

        if isSubmitFocused {
            // Focused submit button
            submitPill.fillColor = subjectColor.withAlphaComponent(0.3)
            submitPill.strokeColor = subjectColor
            submitPill.lineWidth = 2
            subLabel.fontColor = .white
        } else if hasMadeMove {
            // Active but not focused
            submitPill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
            submitPill.strokeColor = subjectColor.withAlphaComponent(0.5)
            submitPill.lineWidth = 1
            subLabel.fontColor = SKColor(white: 0.8, alpha: 1)
        } else {
            // Dimmed (no moves yet)
            submitPill.fillColor = SKColor(red: 0.08, green: 0.08, blue: 0.14, alpha: 0.5)
            submitPill.strokeColor = SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.3)
            submitPill.lineWidth = 1
            subLabel.fontColor = SKColor(white: 0.4, alpha: 1)
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
