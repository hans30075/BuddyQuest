import Foundation
import SpriteKit

// MARK: - Fill-in-the-Blank Challenge (Multi-Question Round)

/// A challenge round that presents fill-in-the-blank questions in sequence.
/// The player uses an on-screen character grid (navigated with arrow keys) to
/// build their answer, then submits. After each answer a brief feedback flash
/// shows, then the next question loads.
public final class FillInBlankChallenge: Challenge, RoundChallenge {

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

    /// Per-question results (for progression recording)
    public private(set) var perQuestionResults: [Bool] = []
    private var perQuestionXP: [Int] = []

    /// Track the player's typed answer for each question (for summary)
    private var perQuestionPlayerAnswer: [String] = []

    // MARK: - Answer Buffer

    /// The characters the player has entered so far for the current question
    private var answerBuffer: String = ""

    // MARK: - On-Screen Keyboard State

    /// The characters displayed on the keyboard grid
    private var keyboardCharacters: [String] = []

    /// Grid dimensions
    private var gridColumns: Int = 0
    private var gridRows: Int = 0

    /// Currently highlighted key index (flat index into keyboardCharacters)
    private var selectedKeyIndex: Int = 0

    // MARK: - Feedback State

    private var isShowingPerQuestionFeedback: Bool = false
    private var feedbackTimer: TimeInterval = 0

    // MARK: - Bond Abilities

    /// If true, buddy shows a hint at the start of each question (Good Buddy)
    public let showBuddyHints: Bool

    /// If true, player gets one second-chance retry per challenge (Best Buddy)
    public let hasSecondChance: Bool
    private var secondChanceUsed: Bool = false
    private var isShowingSecondChance: Bool = false

    /// Callback to show a buddy speech bubble with a hint
    public var onBuddyHint: ((String) -> Void)?

    /// Optional reference to the InputManager (set by MixedRoundChallenge / ChallengeEngine)
    public var inputManager: InputManager?

    // MARK: - Timer

    private var remainingTime: TimeInterval
    private let timePerQuestion: TimeInterval = 45
    private var timerActive: Bool = true

    // MARK: - UI Nodes

    private var questionContainer: SKNode?
    private var questionLabel: SKLabelNode?
    private var promptLabel: SKLabelNode?
    private var answerFieldNode: SKShapeNode?
    private var answerLabel: SKLabelNode?
    private var keyNodes: [SKShapeNode] = []
    private var keyLabels: [SKLabelNode] = []
    private var progressDots: [SKShapeNode] = []
    private var progressLabel: SKLabelNode?
    private var timerNode: SKShapeNode?
    private var timerLabel: SKLabelNode?
    private var feedbackIcon: SKLabelNode?

    // MARK: - Layout Constants

    private let panelWidth: CGFloat = 540
    private let panelHeight: CGFloat = 420
    private let keySize: CGFloat = 30
    private let keyGap: CGFloat = 4

    // MARK: - Init

    /// Create a fill-in-the-blank challenge round with multiple questions.
    /// All questions must have `.fillInBlank` payloads.
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
        self.remainingTime = 45
        self.showBuddyHints = showBuddyHints
        self.hasSecondChance = hasSecondChance
    }

    // MARK: - Build UI

    public func buildUI(on parentNode: SKNode, viewSize: CGSize) {
        let container = SKNode()
        container.name = "fibChallenge"
        parentNode.addChild(container)
        questionContainer = container

        buildQuestionUI(on: container)
    }

    /// Build (or rebuild) the UI for the current question index
    private func buildQuestionUI(on container: SKNode) {
        // Clear previous question nodes
        container.removeAllChildren()
        keyNodes.removeAll()
        keyLabels.removeAll()
        progressDots.removeAll()
        answerBuffer = ""

        let q = questions[currentIndex]

        // Determine the prompt string from the payload
        let promptText: String
        if case .fillInBlank(let prompt, _, _) = q.payload {
            promptText = prompt
        } else {
            promptText = q.questionText
        }

        // Build keyboard characters based on subject
        buildKeyboardLayout()

        // ── Main panel (z=-1 so labels/keys render above it) ──
        let panel = SKShapeNode(rectOf: CGSize(width: panelWidth, height: panelHeight), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 1.0)
        panel.strokeColor = subjectColor.withAlphaComponent(0.7)
        panel.lineWidth = 2
        panel.zPosition = -1
        container.addChild(panel)

        // ── Progress indicator (top-left): "Q 2/5" ──
        let progLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        progLabel.text = "Q \(currentIndex + 1)/\(questions.count)"
        progLabel.fontSize = 12
        progLabel.fontColor = .white
        progLabel.horizontalAlignmentMode = .left
        progLabel.verticalAlignmentMode = .top
        progLabel.position = CGPoint(x: -panelWidth / 2 + 20, y: panelHeight / 2 - 14)
        container.addChild(progLabel)
        progressLabel = progLabel

        // ── Progress dots ──
        let dotStartX = -panelWidth / 2 + 80
        let dotY = panelHeight / 2 - 18
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

        // ── Subject badge (top-center) ──
        let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
        badge.text = subject.rawValue
        badge.fontSize = 10
        badge.fontColor = subjectColor
        badge.horizontalAlignmentMode = .center
        badge.verticalAlignmentMode = .top
        badge.position = CGPoint(x: 0, y: panelHeight / 2 - 14)
        container.addChild(badge)

        // ── Timer bar (top-right) ──
        let timerBarWidth: CGFloat = 100
        let timerBarHeight: CGFloat = 8
        let timerBg = SKShapeNode(rectOf: CGSize(width: timerBarWidth, height: timerBarHeight), cornerRadius: 4)
        timerBg.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 0.8)
        timerBg.strokeColor = .clear
        timerBg.position = CGPoint(x: panelWidth / 2 - 70, y: panelHeight / 2 - 18)
        container.addChild(timerBg)

        let fraction = CGFloat(remainingTime / timePerQuestion)
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

        // ── Question text (center-top) ──
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

        // ── Prompt with blank highlighted ──
        let pLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
        pLabel.text = promptText
        pLabel.fontSize = 14
        pLabel.fontColor = subjectColor
        pLabel.horizontalAlignmentMode = .center
        pLabel.verticalAlignmentMode = .top
        pLabel.preferredMaxLayoutWidth = panelWidth - 60
        pLabel.numberOfLines = 0
        pLabel.lineBreakMode = .byWordWrapping

        let questionTextHeight = qLabel.frame.height
        let promptY = (panelHeight / 2 - 40) - questionTextHeight - 10
        pLabel.position = CGPoint(x: 0, y: promptY)
        container.addChild(pLabel)
        promptLabel = pLabel

        // ── Answer display field ──
        let answerFieldWidth: CGFloat = 260
        let answerFieldHeight: CGFloat = 34
        let promptBottom = promptY - max(pLabel.frame.height, 16)
        let answerFieldY = promptBottom - 14

        let aField = SKShapeNode(rectOf: CGSize(width: answerFieldWidth, height: answerFieldHeight), cornerRadius: 8)
        aField.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.20, alpha: 1)
        aField.strokeColor = subjectColor.withAlphaComponent(0.6)
        aField.lineWidth = 1.5
        aField.position = CGPoint(x: 0, y: answerFieldY)
        container.addChild(aField)
        answerFieldNode = aField

        let aLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        aLabel.text = "_"
        aLabel.fontSize = 16
        aLabel.fontColor = .white
        aLabel.verticalAlignmentMode = .center
        aLabel.horizontalAlignmentMode = .center
        aLabel.position = CGPoint(x: 0, y: answerFieldY)
        container.addChild(aLabel)
        answerLabel = aLabel

        // ── On-screen keyboard grid ──
        let keyboardTopY = answerFieldY - answerFieldHeight / 2 - 14
        buildKeyboardNodes(on: container, topY: keyboardTopY)

        // ── Navigation hint ──
        let navHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        navHint.text = "Type answer  \u{2022}  Enter Submit  \u{2022}  \u{2190}\u{2192}\u{2191}\u{2193} On-screen keys"
        navHint.fontSize = 10
        navHint.fontColor = SKColor(white: 0.5, alpha: 1)
        navHint.verticalAlignmentMode = .center
        navHint.position = CGPoint(x: 0, y: -panelHeight / 2 + 16)
        container.addChild(navHint)

        // Reset selection
        selectedKeyIndex = 0
        isShowingSecondChance = false
        updateKeyHighlight()
        updateAnswerDisplay()

        // Trigger buddy hint if unlocked
        if showBuddyHints {
            let hint = generateHint(for: q)
            onBuddyHint?(hint)
        }
    }

    // MARK: - Keyboard Layout

    /// Build the keyboardCharacters array and grid dimensions based on subject
    private func buildKeyboardLayout() {
        if subject == .math {
            // Math: digits 0-9, decimal point, minus sign (3 rows of 4, then Backspace + Submit)
            // Row 1: 1 2 3 4
            // Row 2: 5 6 7 8
            // Row 3: 9 0 .  -
            // Row 4: [Backspace] [Space] [Submit]
            keyboardCharacters = [
                "1", "2", "3", "4",
                "5", "6", "7", "8",
                "9", "0", ".", "-",
                "\u{232B}", " ", "\u{2713}", ""
            ]
            gridColumns = 4
            gridRows = 4
        } else {
            // ELA / Science / Social: A-Z in 3 rows of 9, then utility row
            // Row 1: A B C D E F G H I
            // Row 2: J K L M N O P Q R
            // Row 3: S T U V W X Y Z [space placeholder]
            // Row 4: [Backspace] [Space] [Submit] ... (padded to 9 cols)
            var chars: [String] = []
            for code in UnicodeScalar("A").value...UnicodeScalar("Z").value {
                chars.append(String(UnicodeScalar(code)!))
            }
            // Pad row 3 to 9 (26 = 2*9 + 8, so row 3 has 8 chars; add one spacer)
            chars.append("")  // placeholder in position 27 (row 3, col 9)

            // Row 4: utility keys, padded to 9 columns
            chars.append(contentsOf: ["\u{232B}", " ", "\u{2713}", "", "", "", "", "", ""])

            keyboardCharacters = chars
            gridColumns = 9
            gridRows = 4
        }
    }

    /// Lay out keyboard key nodes on the container
    private func buildKeyboardNodes(on container: SKNode, topY: CGFloat) {
        keyNodes.removeAll()
        keyLabels.removeAll()

        let totalGridWidth = CGFloat(gridColumns) * keySize + CGFloat(gridColumns - 1) * keyGap
        let startX = -totalGridWidth / 2 + keySize / 2

        for i in 0..<keyboardCharacters.count {
            let char = keyboardCharacters[i]
            guard !char.isEmpty else {
                // Empty placeholder — still reserve space for layout, but invisible
                let placeholder = SKShapeNode(rectOf: CGSize(width: keySize, height: keySize), cornerRadius: 6)
                placeholder.fillColor = .clear
                placeholder.strokeColor = .clear
                let row = i / gridColumns
                let col = i % gridColumns
                placeholder.position = CGPoint(
                    x: startX + CGFloat(col) * (keySize + keyGap),
                    y: topY - CGFloat(row) * (keySize + keyGap)
                )
                container.addChild(placeholder)
                keyNodes.append(placeholder)
                let emptyLabel = SKLabelNode()
                keyLabels.append(emptyLabel)
                continue
            }

            let row = i / gridColumns
            let col = i % gridColumns

            // Determine if this is a special key
            let isBackspace = (char == "\u{232B}")
            let isSubmit = (char == "\u{2713}")
            let isSpace = (char == " ")
            let displayWidth: CGFloat = (isBackspace || isSubmit || isSpace) ? keySize * 1.5 : keySize

            let key = SKShapeNode(rectOf: CGSize(width: displayWidth, height: keySize), cornerRadius: 6)
            key.name = "key_\(i)"
            key.position = CGPoint(
                x: startX + CGFloat(col) * (keySize + keyGap),
                y: topY - CGFloat(row) * (keySize + keyGap)
            )
            key.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.2, alpha: 0.8)
            key.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
            key.lineWidth = 1
            container.addChild(key)
            keyNodes.append(key)

            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            if isBackspace {
                label.text = "\u{232B}"
                label.fontSize = 14
            } else if isSubmit {
                label.text = "OK"
                label.fontSize = 12
            } else if isSpace {
                label.text = "\u{2423}"  // open box / space symbol
                label.fontSize = 14
            } else {
                label.text = char
                label.fontSize = 13
            }
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.position = .zero
            key.addChild(label)
            keyLabels.append(label)
        }
    }

    // MARK: - Input

    public func handleInput(_ input: InputState) -> ChallengeResult? {
        // Block input during per-question feedback
        if isShowingPerQuestionFeedback { return nil }

        // Round complete — nothing to do
        if isComplete { return nil }

        // ── Direct keyboard typing (macOS) ──
        // Process typed characters from the physical keyboard first.
        // This allows players to type answers directly without the on-screen grid.
        if !input.typedCharacters.isEmpty {
            for char in input.typedCharacters {
                if char == "\u{08}" {
                    // Backspace
                    if !answerBuffer.isEmpty {
                        answerBuffer.removeLast()
                    }
                } else {
                    answerBuffer.append(char)
                }
            }
            updateAnswerDisplay()
        }

        // ── On-screen keyboard navigation (arrow keys) ──
        if input.isPressed(.moveLeft) {
            moveSelection(dx: -1, dy: 0)
        }
        if input.isPressed(.moveRight) {
            moveSelection(dx: 1, dy: 0)
        }
        if input.isPressed(.moveUp) {
            moveSelection(dx: 0, dy: -1)
        }
        if input.isPressed(.moveDown) {
            moveSelection(dx: 0, dy: 1)
        }

        // ── Submit via Return/Enter when text input is active ──
        // When the InputManager has text input active, Return key submits the answer directly
        if input.isPressed(.confirm) && inputManager?.isTextInputActive == true {
            questionContainer?.childNode(withName: "secondChanceOverlay")?.removeFromParent()
            submitCurrentAnswer()
            return nil
        }

        // ── On-screen keyboard character selection (E / Enter via grid) ──
        if input.isPressed(.interact) || input.isPressed(.confirm) {
            // Remove second chance overlay if present
            questionContainer?.childNode(withName: "secondChanceOverlay")?.removeFromParent()

            let char = keyboardCharacters[safe: selectedKeyIndex] ?? ""
            if char == "\u{232B}" {
                // Backspace
                if !answerBuffer.isEmpty {
                    answerBuffer.removeLast()
                    updateAnswerDisplay()
                }
            } else if char == "\u{2713}" {
                // Submit
                submitCurrentAnswer()
            } else if char == " " {
                // Space
                answerBuffer.append(" ")
                updateAnswerDisplay()
            } else if !char.isEmpty {
                // Regular character
                answerBuffer.append(char)
                updateAnswerDisplay()
            }
        }

        return nil
    }

    // MARK: - Grid Navigation

    /// Move selection by (dx, dy) in grid coordinates, skipping empty cells
    private func moveSelection(dx: Int, dy: Int) {
        let currentRow = selectedKeyIndex / gridColumns
        let currentCol = selectedKeyIndex % gridColumns

        var newCol = currentCol + dx
        var newRow = currentRow + dy

        // Wrap around
        if newCol < 0 { newCol = gridColumns - 1 }
        if newCol >= gridColumns { newCol = 0 }
        if newRow < 0 { newRow = gridRows - 1 }
        if newRow >= gridRows { newRow = 0 }

        var newIndex = newRow * gridColumns + newCol

        // Skip empty cells — scan forward in the movement direction
        let maxAttempts = gridColumns * gridRows
        var attempts = 0
        while attempts < maxAttempts {
            if newIndex >= 0, newIndex < keyboardCharacters.count,
               !keyboardCharacters[newIndex].isEmpty {
                break
            }
            // Move one step further in the same direction
            if dx != 0 {
                newCol += (dx > 0 ? 1 : -1)
                if newCol < 0 { newCol = gridColumns - 1; newRow = (newRow - 1 + gridRows) % gridRows }
                if newCol >= gridColumns { newCol = 0; newRow = (newRow + 1) % gridRows }
            } else {
                newRow += (dy > 0 ? 1 : -1)
                if newRow < 0 { newRow = gridRows - 1 }
                if newRow >= gridRows { newRow = 0 }
            }
            newIndex = newRow * gridColumns + newCol
            attempts += 1
        }

        if newIndex >= 0, newIndex < keyboardCharacters.count,
           !keyboardCharacters[newIndex].isEmpty {
            selectedKeyIndex = newIndex
            updateKeyHighlight()
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
                // Time's up — auto-submit current answer (likely wrong)
                submitCurrentAnswer()
            }
            updateTimerUI()
        }
    }

    // MARK: - Teardown

    public func teardown() {
        inputManager?.isTextInputActive = false
        questionContainer?.removeFromParent()
        questionContainer = nil
        keyNodes.removeAll()
        keyLabels.removeAll()
        progressDots.removeAll()
        timerNode = nil
        timerLabel = nil
        questionLabel = nil
        promptLabel = nil
        answerFieldNode = nil
        answerLabel = nil
        progressLabel = nil
        feedbackIcon = nil
    }

    // MARK: - Private: Answer Submission

    private func submitCurrentAnswer() {
        let q = questions[currentIndex]
        let isCorrect = checkAnswer(answerBuffer, against: q.payload)

        // Second chance: if wrong and not yet used, offer retry
        if !isCorrect && hasSecondChance && !secondChanceUsed && !isShowingSecondChance {
            isShowingSecondChance = true
            secondChanceUsed = true
            showSecondChancePrompt()
            return
        }

        let timeBonus = remainingTime > 30 ? 2 : (remainingTime > 15 ? 1 : 0)
        let baseXP = isCorrect ? GameConstants.xpPerCorrectAnswer : GameConstants.xpPerWrongAnswer
        let xp = baseXP + (isCorrect ? timeBonus : 0)

        // Record
        perQuestionResults.append(isCorrect)
        perQuestionXP.append(xp)
        perQuestionPlayerAnswer.append(answerBuffer)

        // Highlight answer field correct/wrong
        highlightAnswerField(isCorrect: isCorrect)

        // Show inline feedback icon
        showPerQuestionFeedback(isCorrect: isCorrect)

        // Start feedback pause
        isShowingPerQuestionFeedback = true
        feedbackTimer = 0
    }

    // MARK: - Answer Validation

    private func checkAnswer(_ playerAnswer: String, against payload: QuestionPayload) -> Bool {
        guard case .fillInBlank(_, let acceptedAnswers, let isCaseSensitive) = payload else { return false }
        let trimmed = playerAnswer.trimmingCharacters(in: .whitespaces)
        for accepted in acceptedAnswers {
            let acceptedTrimmed = accepted.trimmingCharacters(in: .whitespaces)
            // Case comparison
            if isCaseSensitive {
                if trimmed == acceptedTrimmed { return true }
            } else {
                if trimmed.lowercased() == acceptedTrimmed.lowercased() { return true }
            }
            // Numeric comparison (for math)
            if let playerNum = Double(trimmed), let acceptedNum = Double(acceptedTrimmed) {
                if abs(playerNum - acceptedNum) < 0.01 { return true }
            }
        }
        return false
    }

    // MARK: - Hint Generation

    private func generateHint(for q: Question) -> String {
        guard case .fillInBlank(_, let acceptedAnswers, _) = q.payload,
              let correct = acceptedAnswers.first else {
            return "Hmm, I have a feeling about this one!"
        }
        if correct.count > 2 {
            let firstLetter = String(correct.prefix(1)).uppercased()
            return "I think the answer starts with \"\(firstLetter)\"..."
        } else if correct.count > 0 {
            return "The answer has \(correct.count) character\(correct.count == 1 ? "" : "s")."
        } else {
            return "Hmm, I have a feeling about this one!"
        }
    }

    // MARK: - Second Chance

    private func showSecondChancePrompt() {
        guard let container = questionContainer else { return }

        // Flash the answer field red briefly
        answerFieldNode?.strokeColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.8)

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

        // Clear the answer so the player can retry
        answerBuffer = ""
        updateAnswerDisplay()
        answerFieldNode?.strokeColor = subjectColor.withAlphaComponent(0.6)
    }

    // MARK: - Per-Question Feedback

    private func showPerQuestionFeedback(isCorrect: Bool) {
        guard let container = questionContainer else { return }

        // Big feedback icon
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

    private func highlightAnswerField(isCorrect: Bool) {
        answerFieldNode?.strokeColor = isCorrect
            ? GameColors.correctGreen.skColor
            : GameColors.incorrectRed.skColor
        answerFieldNode?.lineWidth = 2.5
    }

    // MARK: - Advance to Next Question

    private func advanceToNextQuestion() {
        isShowingPerQuestionFeedback = false

        // Remove feedback icon
        feedbackIcon?.removeFromParent()
        feedbackIcon = nil

        if currentIndex + 1 < questions.count {
            currentIndex += 1
            answerBuffer = ""

            // Reset timer for next question
            remainingTime = timePerQuestion
            timerActive = true

            // Rebuild UI
            if let container = questionContainer {
                buildQuestionUI(on: container)
            }
        } else {
            // Round complete
            isComplete = true
        }
    }

    // MARK: - Aggregate Result

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

    public var allRoundQuestions: [Question] {
        questions
    }

    public func correctionInfo(for questionIndex: Int) -> (playerAnswer: String, correctAnswer: String, explanation: String)? {
        guard questionIndex < questions.count,
              questionIndex < perQuestionPlayerAnswer.count else { return nil }
        let q = questions[questionIndex]
        let playerAns = perQuestionPlayerAnswer[questionIndex]

        // Get the first accepted answer as the "correct" display value
        let correctAns: String
        if case .fillInBlank(_, let acceptedAnswers, _) = q.payload,
           let first = acceptedAnswers.first {
            correctAns = first
        } else {
            correctAns = "?"
        }

        return (playerAnswer: playerAns.isEmpty ? "(no answer)" : playerAns,
                correctAnswer: correctAns,
                explanation: q.explanation)
    }

    // MARK: - Private: UI Helpers

    private func updateAnswerDisplay() {
        if answerBuffer.isEmpty {
            answerLabel?.text = "_"
            answerLabel?.fontColor = SKColor(white: 0.4, alpha: 1)
        } else {
            answerLabel?.text = answerBuffer
            answerLabel?.fontColor = .white
        }
    }

    private func updateKeyHighlight() {
        for (i, keyNode) in keyNodes.enumerated() {
            let char = keyboardCharacters[safe: i] ?? ""
            guard !char.isEmpty else { continue }

            if i == selectedKeyIndex {
                keyNode.fillColor = subjectColor.withAlphaComponent(0.2)
                keyNode.strokeColor = subjectColor.withAlphaComponent(0.9)
                keyNode.lineWidth = 1.5

                // Highlight special keys differently
                if char == "\u{2713}" {
                    keyNode.fillColor = GameColors.correctGreen.skColor.withAlphaComponent(0.15)
                    keyNode.strokeColor = GameColors.correctGreen.skColor.withAlphaComponent(0.8)
                } else if char == "\u{232B}" {
                    keyNode.fillColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.1)
                    keyNode.strokeColor = GameColors.incorrectRed.skColor.withAlphaComponent(0.6)
                }
            } else {
                keyNode.fillColor = SKColor(red: 0.12, green: 0.12, blue: 0.2, alpha: 0.8)
                keyNode.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 0.5)
                keyNode.lineWidth = 1
            }
        }
    }

    private func updateTimerUI() {
        guard let container = questionContainer else { return }

        let timerBarWidth: CGFloat = 100
        let fraction = CGFloat(remainingTime / timePerQuestion)
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
