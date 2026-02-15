import Foundation
import SpriteKit

// MARK: - Matching Challenge (Multi-Question Round)

/// A challenge round that presents matching-pairs questions.
/// Player connects items from a left column to a right column using keyboard navigation.
/// After submission, a brief feedback flash shows, then the next question loads.
/// After the final question, an aggregate result is returned to the engine.
public final class MatchingChallenge: Challenge, RoundChallenge {

    // MARK: - Matching State Machine

    /// Which UI region currently has focus
    private enum FocusRegion {
        case leftColumn
        case rightColumn
        case submitButton
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

    /// Track the player's final mapping per question
    private var perQuestionPlayerMapping: [[Int?]] = []

    /// Whether we're in the brief per-question feedback pause
    private var isShowingPerQuestionFeedback: Bool = false
    private var feedbackTimer: TimeInterval = 0

    // MARK: - Matching State

    private var focusRegion: FocusRegion = .leftColumn
    private var leftFocusIndex: Int = 0
    private var rightFocusIndex: Int = 0

    /// Currently selected left item awaiting a right-column partner (nil = no selection)
    private var selectedLeftIndex: Int? = nil

    /// Player's current mapping: playerMapping[leftIndex] = rightIndex or nil
    private var playerMapping: [Int?] = []

    /// Current question data
    private var currentLeftItems: [String] = []
    private var currentRightItems: [String] = []
    private var currentCorrectMapping: [Int] = []

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
    private var leftPillNodes: [SKShapeNode] = []
    private var rightPillNodes: [SKShapeNode] = []
    private var leftLabels: [SKLabelNode] = []
    private var rightLabels: [SKLabelNode] = []
    private var connectorLines: [SKShapeNode] = []
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
    private let pillHeight: CGFloat = 32
    private let pillGap: CGFloat = 8
    private let columnGap: CGFloat = 100  // horizontal gap between columns

    // Connector line color palette
    private let connectorColors: [SKColor] = [
        SKColor(red: 0.3, green: 0.7, blue: 1.0, alpha: 0.9),   // Light blue
        SKColor(red: 1.0, green: 0.6, blue: 0.3, alpha: 0.9),   // Orange
        SKColor(red: 0.5, green: 0.9, blue: 0.5, alpha: 0.9),   // Green
        SKColor(red: 0.9, green: 0.5, blue: 0.9, alpha: 0.9),   // Pink
        SKColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 0.9),   // Yellow
    ]

    // MARK: - Init

    /// Create a matching challenge round with multiple questions.
    /// All questions must have `.matching` payloads.
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
        container.name = "matchingChallenge"
        parentNode.addChild(container)
        questionContainer = container

        buildQuestionUI(on: container)
    }

    /// Build (or rebuild) the UI for the current question index
    private func buildQuestionUI(on container: SKNode) {
        // Clear previous question nodes
        container.removeAllChildren()
        leftPillNodes.removeAll()
        rightPillNodes.removeAll()
        leftLabels.removeAll()
        rightLabels.removeAll()
        connectorLines.removeAll()
        submitNode = nil
        submitLabel = nil

        let q = questions[currentIndex]

        // Extract matching payload
        guard case .matching(let leftItems, let rightItems, let correctMapping) = q.payload else { return }
        currentLeftItems = leftItems
        currentRightItems = rightItems
        currentCorrectMapping = correctMapping
        playerMapping = Array(repeating: nil, count: leftItems.count)

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

        // Compute columns layout
        let questionTextHeight = qLabel.frame.height
        let questionBottomY = (panelHeight / 2 - 40) - questionTextHeight
        let itemCount = max(leftItems.count, rightItems.count)
        let itemsBlockHeight = CGFloat(itemCount) * pillHeight + CGFloat(itemCount - 1) * pillGap
        let submitAreaHeight: CGFloat = 56
        let idealStartY = questionBottomY - 16
        let minStartY = -panelHeight / 2 + 30 + submitAreaHeight + itemsBlockHeight
        let startY = max(idealStartY, minStartY)

        let pillWidth: CGFloat = (panelWidth - columnGap - 80) / 2  // Each column width
        let leftCenterX = -columnGap / 2 - pillWidth / 2
        let rightCenterX = columnGap / 2 + pillWidth / 2

        // Column headers
        let leftHeader = SKLabelNode(fontNamed: "AvenirNext-Bold")
        leftHeader.text = "Items"
        leftHeader.fontSize = 11
        leftHeader.fontColor = subjectColor.withAlphaComponent(0.8)
        leftHeader.verticalAlignmentMode = .bottom
        leftHeader.horizontalAlignmentMode = .center
        leftHeader.position = CGPoint(x: leftCenterX, y: startY + pillHeight / 2 + 4)
        container.addChild(leftHeader)

        let rightHeader = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rightHeader.text = "Matches"
        rightHeader.fontSize = 11
        rightHeader.fontColor = subjectColor.withAlphaComponent(0.8)
        rightHeader.verticalAlignmentMode = .bottom
        rightHeader.horizontalAlignmentMode = .center
        rightHeader.position = CGPoint(x: rightCenterX, y: startY + pillHeight / 2 + 4)
        container.addChild(rightHeader)

        // Build left column pills
        let letterLabels = ["A", "B", "C", "D", "E"]
        for i in 0..<leftItems.count {
            let y = startY - CGFloat(i) * (pillHeight + pillGap)

            let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
            pill.name = "leftItem_\(i)"
            pill.position = CGPoint(x: leftCenterX, y: y)

            let prefix = i < letterLabels.count ? letterLabels[i] : "\(i + 1)"
            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = "\(prefix). \(leftItems[i])"
            label.fontSize = 11
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.preferredMaxLayoutWidth = pillWidth - 20
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.position = CGPoint(x: -pillWidth / 2 + 12, y: 0)
            pill.addChild(label)

            container.addChild(pill)
            leftPillNodes.append(pill)
            leftLabels.append(label)
        }

        // Build right column pills
        for i in 0..<rightItems.count {
            let y = startY - CGFloat(i) * (pillHeight + pillGap)

            let pill = SKShapeNode(rectOf: CGSize(width: pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
            pill.name = "rightItem_\(i)"
            pill.position = CGPoint(x: rightCenterX, y: y)

            let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
            label.text = "\(i + 1). \(rightItems[i])"
            label.fontSize = 11
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .left
            label.preferredMaxLayoutWidth = pillWidth - 20
            label.numberOfLines = 1
            label.lineBreakMode = .byTruncatingTail
            label.position = CGPoint(x: -pillWidth / 2 + 12, y: 0)
            pill.addChild(label)

            container.addChild(pill)
            rightPillNodes.append(pill)
            rightLabels.append(label)
        }

        // Submit button pill (below items)
        let lastItemY = startY - CGFloat(itemCount - 1) * (pillHeight + pillGap)
        let submitY = lastItemY - pillHeight / 2 - 20

        let submitPill = SKShapeNode(rectOf: CGSize(width: 160, height: 30), cornerRadius: 15)
        submitPill.name = "submitMatches"
        submitPill.position = CGPoint(x: 0, y: submitY)
        container.addChild(submitPill)
        submitNode = submitPill

        let subLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        subLabel.text = "Submit Matches"
        subLabel.fontSize = 12
        subLabel.verticalAlignmentMode = .center
        subLabel.horizontalAlignmentMode = .center
        subLabel.position = .zero
        submitPill.addChild(subLabel)
        submitLabel = subLabel

        // Navigation hint
        let navHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        #if os(iOS)
        navHint.text = "Tap left item, then tap right item to match  \u{2022}  Tap Submit"
        #else
        navHint.text = "\u{2190}\u{2192} Column  \u{2022}  \u{2191}\u{2193} Move  \u{2022}  E Match  \u{2022}  Submit to check"
        #endif
        navHint.fontSize = 10
        navHint.fontColor = SKColor(white: 0.5, alpha: 1)
        navHint.verticalAlignmentMode = .center
        navHint.position = CGPoint(x: 0, y: -panelHeight / 2 + 16)
        container.addChild(navHint)
        navHintLabel = navHint

        // Reset state
        focusRegion = .leftColumn
        leftFocusIndex = 0
        rightFocusIndex = 0
        selectedLeftIndex = nil
        isShowingSecondChance = false
        updateAllHighlights()
        updateSubmitButton()

        // Trigger buddy hint if unlocked
        if showBuddyHints {
            let hint = generateHint(for: q)
            onBuddyHint?(hint)
        }
    }

    /// Generate a simple hint for a matching question
    private func generateHint(for q: Question) -> String {
        guard case .matching(let leftItems, let rightItems, let correctMapping) = q.payload,
              !correctMapping.isEmpty else {
            return "Try to find the pairs that go together!"
        }
        // Hint: reveal the first correct pair
        let firstLeftIdx = 0
        let firstRightIdx = correctMapping[firstLeftIdx]
        if firstLeftIdx < leftItems.count, firstRightIdx < rightItems.count {
            return "I think \"\(leftItems[firstLeftIdx])\" matches with \"\(rightItems[firstRightIdx])\"..."
        }
        return "Look for connections between the items!"
    }

    // MARK: - Input

    public func handleInput(_ input: InputState) -> ChallengeResult? {
        // Block input during feedback
        if isShowingPerQuestionFeedback { return nil }
        if isComplete { return nil }

        switch focusRegion {
        case .leftColumn:
            handleLeftColumnInput(input)
        case .rightColumn:
            handleRightColumnInput(input)
        case .submitButton:
            handleSubmitFocusedInput(input)
        }

        return nil
    }

    private func handleLeftColumnInput(_ input: InputState) {
        let itemCount = currentLeftItems.count

        if input.isPressed(.moveUp) {
            if leftFocusIndex > 0 {
                leftFocusIndex -= 1
            }
            updateAllHighlights()
        }

        if input.isPressed(.moveDown) {
            if leftFocusIndex < itemCount - 1 {
                leftFocusIndex += 1
                updateAllHighlights()
            } else {
                // Past last item -> focus submit button
                focusRegion = .submitButton
                updateAllHighlights()
                updateSubmitButton()
            }
        }

        if input.isPressed(.moveRight) {
            // Switch to right column
            focusRegion = .rightColumn
            updateAllHighlights()
        }

        // Select a left item (or toggle off)
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            if selectedLeftIndex == leftFocusIndex {
                // Deselect
                selectedLeftIndex = nil
            } else {
                // If this item is already matched, un-match it first
                if playerMapping[leftFocusIndex] != nil {
                    removeMatch(leftIndex: leftFocusIndex)
                }
                // Select and jump to right column
                selectedLeftIndex = leftFocusIndex
                focusRegion = .rightColumn
            }
            updateAllHighlights()
            redrawConnectorLines()
        }
    }

    private func handleRightColumnInput(_ input: InputState) {
        let itemCount = currentRightItems.count

        if input.isPressed(.moveUp) {
            if rightFocusIndex > 0 {
                rightFocusIndex -= 1
            }
            updateAllHighlights()
        }

        if input.isPressed(.moveDown) {
            if rightFocusIndex < itemCount - 1 {
                rightFocusIndex += 1
                updateAllHighlights()
            } else {
                // Past last item -> focus submit button
                focusRegion = .submitButton
                updateAllHighlights()
                updateSubmitButton()
            }
        }

        if input.isPressed(.moveLeft) {
            // Switch to left column
            focusRegion = .leftColumn
            updateAllHighlights()
        }

        // Confirm a match (or re-match)
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            if let leftIdx = selectedLeftIndex {
                // Un-match any left item already pointing to this right item
                for i in 0..<playerMapping.count {
                    if playerMapping[i] == rightFocusIndex {
                        playerMapping[i] = nil
                    }
                }
                // Create the match
                playerMapping[leftIdx] = rightFocusIndex
                selectedLeftIndex = nil
                // Return focus to left column
                focusRegion = .leftColumn
            } else {
                // No left item selected -- if this right item is already matched,
                // find and un-match it
                for i in 0..<playerMapping.count {
                    if playerMapping[i] == rightFocusIndex {
                        removeMatch(leftIndex: i)
                        break
                    }
                }
            }
            updateAllHighlights()
            redrawConnectorLines()
            updateSubmitButton()
        }
    }

    private func handleSubmitFocusedInput(_ input: InputState) {
        if input.isPressed(.moveUp) {
            // Back to last item in left column
            focusRegion = .leftColumn
            leftFocusIndex = currentLeftItems.count - 1
            updateAllHighlights()
            updateSubmitButton()
        }

        if input.isPressed(.moveLeft) {
            focusRegion = .leftColumn
            updateAllHighlights()
            updateSubmitButton()
        }

        if input.isPressed(.moveRight) {
            focusRegion = .rightColumn
            updateAllHighlights()
            updateSubmitButton()
        }

        if input.isPressed(.interact) || input.isPressed(.confirm) {
            // Remove second chance overlay if present
            questionContainer?.childNode(withName: "secondChanceOverlay")?.removeFromParent()
            submitCurrentAnswer()
        }
    }

    // MARK: - Touch Input (iOS)

    public func handleTouch(at location: CGPoint, in scene: SKScene) {
        guard !isShowingPerQuestionFeedback, !isComplete else { return }
        guard let container = questionContainer else { return }

        let localPoint = container.convert(location, from: scene)

        // Check submit button tap
        if let submitNode = container.childNode(withName: "submitMatches") as? SKShapeNode,
           submitNode.frame.contains(localPoint) {
            container.childNode(withName: "secondChanceOverlay")?.removeFromParent()
            submitCurrentAnswer()
            return
        }

        // Check left column taps
        for i in 0..<currentLeftItems.count {
            if let node = container.childNode(withName: "leftItem_\(i)") as? SKShapeNode,
               node.frame.contains(localPoint) {
                leftFocusIndex = i
                focusRegion = .leftColumn

                if selectedLeftIndex == i {
                    // Deselect
                    selectedLeftIndex = nil
                } else {
                    // If already matched, un-match first
                    if playerMapping[i] != nil {
                        removeMatch(leftIndex: i)
                    }
                    // Select and wait for right column tap
                    selectedLeftIndex = i
                }
                updateAllHighlights()
                redrawConnectorLines()
                return
            }
        }

        // Check right column taps
        for i in 0..<currentRightItems.count {
            if let node = container.childNode(withName: "rightItem_\(i)") as? SKShapeNode,
               node.frame.contains(localPoint) {
                rightFocusIndex = i
                focusRegion = .rightColumn

                if let leftIdx = selectedLeftIndex {
                    // Un-match any left item already pointing to this right item
                    for j in 0..<playerMapping.count {
                        if playerMapping[j] == i {
                            playerMapping[j] = nil
                        }
                    }
                    // Create the match
                    playerMapping[leftIdx] = i
                    selectedLeftIndex = nil
                    focusRegion = .leftColumn
                } else {
                    // No left selected — un-match any item pointing to this right item
                    for j in 0..<playerMapping.count {
                        if playerMapping[j] == i {
                            removeMatch(leftIndex: j)
                            break
                        }
                    }
                }
                updateAllHighlights()
                redrawConnectorLines()
                updateSubmitButton()
                return
            }
        }
    }

    // MARK: - Match Management

    private func removeMatch(leftIndex: Int) {
        playerMapping[leftIndex] = nil
    }

    /// Whether all left items have been matched
    private var allMatched: Bool {
        playerMapping.allSatisfy { $0 != nil }
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
        leftPillNodes.removeAll()
        rightPillNodes.removeAll()
        leftLabels.removeAll()
        rightLabels.removeAll()
        connectorLines.removeAll()
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
        let isCorrect = checkMapping()

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
        perQuestionPlayerMapping.append(playerMapping)

        // Highlight correct/wrong matches
        highlightMatchingResult(isCorrect: isCorrect)

        // Show inline feedback icon
        showPerQuestionFeedback(isCorrect: isCorrect)

        // Start feedback pause
        isShowingPerQuestionFeedback = true
        feedbackTimer = 0
    }

    /// Check if the player's mapping matches the correct mapping
    private func checkMapping() -> Bool {
        guard playerMapping.count == currentCorrectMapping.count else { return false }
        for i in 0..<playerMapping.count {
            guard let playerRight = playerMapping[i] else { return false }
            if playerRight != currentCorrectMapping[i] {
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
        label.text = "\u{2764}\u{FE0F} Your buddy gives you another chance! Fix your matches and resubmit!"
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

        // Go back to navigating so the player can fix matches
        focusRegion = .leftColumn
        leftFocusIndex = 0
        selectedLeftIndex = nil
        updateAllHighlights()
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

    private func highlightMatchingResult(isCorrect: Bool) {
        if isCorrect {
            // All pills green
            for pill in leftPillNodes {
                pill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                pill.strokeColor = GameColors.correctGreen.skColor
            }
            for pill in rightPillNodes {
                pill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                pill.strokeColor = GameColors.correctGreen.skColor
            }
        } else {
            // Highlight each pair: green if correct, red if not
            for i in 0..<playerMapping.count {
                guard i < leftPillNodes.count else { continue }
                let leftPill = leftPillNodes[i]
                let playerRight = playerMapping[i]
                let correctRight = currentCorrectMapping[i]

                if playerRight == correctRight {
                    leftPill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                    leftPill.strokeColor = GameColors.correctGreen.skColor
                } else {
                    leftPill.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.3)
                    leftPill.strokeColor = GameColors.incorrectRed.skColor
                }
            }
            // Highlight right items based on whether they're correctly matched
            for j in 0..<currentRightItems.count {
                guard j < rightPillNodes.count else { continue }
                let rightPill = rightPillNodes[j]
                // Check if any correct mapping points to j and the player also has it correct
                let isCorrectlyMatched = playerMapping.enumerated().contains { idx, val in
                    val == j && currentCorrectMapping[idx] == j
                }
                if isCorrectlyMatched {
                    rightPill.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.3)
                    rightPill.strokeColor = GameColors.correctGreen.skColor
                } else {
                    rightPill.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.3)
                    rightPill.strokeColor = GameColors.incorrectRed.skColor
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
            leftFocusIndex = 0
            rightFocusIndex = 0
            focusRegion = .leftColumn
            selectedLeftIndex = nil

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
              questionIndex < perQuestionPlayerMapping.count else { return nil }

        let q = questions[questionIndex]
        guard case .matching(_, let rightItems, let correctMapping) = q.payload else { return nil }

        let playerMap = perQuestionPlayerMapping[questionIndex]
        let letterLabels = ["A", "B", "C", "D", "E"]

        // Build "Your matches: A->2, B->1, C->3" string
        let playerMatchStr = playerMap.enumerated().map { idx, rightIdx in
            let prefix = idx < letterLabels.count ? letterLabels[idx] : "\(idx + 1)"
            if let rIdx = rightIdx, rIdx < rightItems.count {
                return "\(prefix)\u{2192}\(rIdx + 1)"
            } else {
                return "\(prefix)\u{2192}?"
            }
        }.joined(separator: ", ")

        // Build "Correct: A->1, B->3, C->2" string
        let correctMatchStr = correctMapping.enumerated().map { idx, rightIdx in
            let prefix = idx < letterLabels.count ? letterLabels[idx] : "\(idx + 1)"
            if rightIdx < rightItems.count {
                return "\(prefix)\u{2192}\(rightIdx + 1)"
            } else {
                return "\(prefix)\u{2192}?"
            }
        }.joined(separator: ", ")

        return (
            playerAnswer: playerMatchStr,
            correctAnswer: correctMatchStr,
            explanation: q.explanation
        )
    }

    // MARK: - Private: Connector Lines

    /// Redraw all connector lines between matched pairs
    private func redrawConnectorLines() {
        guard let container = questionContainer else { return }

        // Remove existing connector lines
        for line in connectorLines {
            line.removeFromParent()
        }
        connectorLines.removeAll()

        // Draw a line for each active match
        for (leftIdx, rightIdx) in playerMapping.enumerated() {
            guard let rIdx = rightIdx else { continue }
            guard leftIdx < leftPillNodes.count, rIdx < rightPillNodes.count else { continue }

            let leftPill = leftPillNodes[leftIdx]
            let rightPill = rightPillNodes[rIdx]

            let pillWidth = leftPill.frame.width
            let startX = leftPill.position.x + pillWidth / 2
            let startY = leftPill.position.y
            let endX = rightPill.position.x - rightPill.frame.width / 2
            let endY = rightPill.position.y

            let path = CGMutablePath()
            path.move(to: CGPoint(x: startX, y: startY))
            path.addLine(to: CGPoint(x: endX, y: endY))

            let lineNode = SKShapeNode(path: path)
            let colorIndex = leftIdx % connectorColors.count
            lineNode.strokeColor = connectorColors[colorIndex]
            lineNode.lineWidth = 2
            lineNode.zPosition = 1
            lineNode.name = "connector_\(leftIdx)_\(rIdx)"
            container.addChild(lineNode)
            connectorLines.append(lineNode)
        }
    }

    // MARK: - Private: UI Helpers

    private func updateAllHighlights() {
        let isSubmitFocused = focusRegion == .submitButton

        // Left column pills
        for (i, pill) in leftPillNodes.enumerated() {
            let isMatched = playerMapping[i] != nil

            if selectedLeftIndex == i {
                // Currently selected for matching — bright highlight
                pill.fillColor = subjectColor.withAlphaComponent(0.35)
                pill.strokeColor = subjectColor
                pill.lineWidth = 2.5
            } else if focusRegion == .leftColumn && i == leftFocusIndex && !isSubmitFocused {
                // Focused
                pill.fillColor = subjectColor.withAlphaComponent(0.15)
                pill.strokeColor = subjectColor.withAlphaComponent(0.8)
                pill.lineWidth = 1.5
            } else if isMatched {
                // Matched item — dimmed with connector color tint
                let colorIndex = i % connectorColors.count
                pill.fillColor = connectorColors[colorIndex].withAlphaComponent(0.12)
                pill.strokeColor = connectorColors[colorIndex].withAlphaComponent(0.5)
                pill.lineWidth = 1
            } else {
                // Default
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
                pill.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
                pill.lineWidth = 1
            }
        }

        // Right column pills
        for (j, pill) in rightPillNodes.enumerated() {
            // Check if this right item is matched
            let matchingLeftIdx = playerMapping.firstIndex(where: { $0 == j })

            if focusRegion == .rightColumn && j == rightFocusIndex && !isSubmitFocused {
                // Focused
                pill.fillColor = subjectColor.withAlphaComponent(0.15)
                pill.strokeColor = subjectColor.withAlphaComponent(0.8)
                pill.lineWidth = 1.5
            } else if let leftIdx = matchingLeftIdx {
                // Matched item — dimmed with connector color tint
                let colorIndex = leftIdx % connectorColors.count
                pill.fillColor = connectorColors[colorIndex].withAlphaComponent(0.12)
                pill.strokeColor = connectorColors[colorIndex].withAlphaComponent(0.5)
                pill.lineWidth = 1
            } else {
                // Default
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
                pill.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
                pill.lineWidth = 1
            }
        }
    }

    private func updateSubmitButton() {
        guard let submitPill = submitNode, let subLabel = submitLabel else { return }

        let isSubmitFocused = focusRegion == .submitButton

        if isSubmitFocused {
            // Focused submit button
            submitPill.fillColor = subjectColor.withAlphaComponent(0.3)
            submitPill.strokeColor = subjectColor
            submitPill.lineWidth = 2
            subLabel.fontColor = .white
        } else if allMatched {
            // All items matched but not focused
            submitPill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
            submitPill.strokeColor = subjectColor.withAlphaComponent(0.5)
            submitPill.lineWidth = 1
            subLabel.fontColor = SKColor(white: 0.8, alpha: 1)
        } else {
            // Dimmed (not all matched yet)
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
