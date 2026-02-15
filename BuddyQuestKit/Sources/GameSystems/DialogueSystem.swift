import Foundation
import SpriteKit

// MARK: - Dialogue Data Structures

/// A single line of dialogue, optionally with choices
public struct DialogueLine {
    public let speaker: String
    public let text: String
    public let choices: [DialogueChoice]?
    /// Action to run when this line finishes displaying (before choices)
    public let onComplete: (() -> Void)?

    public init(
        speaker: String,
        text: String,
        choices: [DialogueChoice]? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.speaker = speaker
        self.text = text
        self.choices = choices
        self.onComplete = onComplete
    }
}

/// A choice the player can select during dialogue
public struct DialogueChoice {
    public let text: String
    /// If set, jump to this dialogue ID after selecting
    public let nextDialogueId: String?
    /// Callback when this choice is selected
    public let onSelect: (() -> Void)?

    public init(
        text: String,
        nextDialogueId: String? = nil,
        onSelect: (() -> Void)? = nil
    ) {
        self.text = text
        self.nextDialogueId = nextDialogueId
        self.onSelect = onSelect
    }
}

/// A complete dialogue sequence (array of lines)
public struct Dialogue {
    public let id: String
    public let lines: [DialogueLine]

    public init(id: String, lines: [DialogueLine]) {
        self.id = id
        self.lines = lines
    }
}

// MARK: - Dialogue System

/// Renders and manages an interactive dialogue box on the SpriteKit scene.
/// Supports typewriter text reveal, speaker name, and branching choices.
public final class DialogueSystem {

    // MARK: - State

    public private(set) var isActive: Bool = false
    private var currentDialogue: Dialogue?
    private var currentLineIndex: Int = 0
    private var revealedCharCount: Int = 0
    private var revealTimer: TimeInterval = 0
    private var isFullyRevealed: Bool = false
    private var selectedChoiceIndex: Int = 0
    private var isShowingChoices: Bool = false

    /// Callback fired when the dialogue finishes (all lines read)
    public var onDialogueComplete: (() -> Void)?

    /// Callback to request loading another dialogue by ID (for branching)
    public var onRequestDialogue: ((String) -> Dialogue?)?

    // MARK: - SpriteKit Nodes

    private var containerNode: SKNode?
    private var backgroundNode: SKShapeNode?
    private var speakerLabel: SKLabelNode?
    private var textLabel: SKLabelNode?
    private var continueIndicator: SKShapeNode?
    private var choiceNodes: [SKNode] = []

    // Layout constants
    private let boxWidth: CGFloat = 700
    private let boxHeight: CGFloat = 120
    private let boxCornerRadius: CGFloat = 12
    private let textPadding: CGFloat = 20
    private let fontSize: CGFloat = 14
    private let speakerFontSize: CGFloat = 12
    private let maxCharsPerLine: Int = 70

    // MARK: - Public API

    /// Start displaying a dialogue sequence
    public func startDialogue(_ dialogue: Dialogue, on parentNode: SKNode, viewSize: CGSize) {
        guard !dialogue.lines.isEmpty else { return }

        currentDialogue = dialogue
        currentLineIndex = 0
        isActive = true

        buildUI(on: parentNode, viewSize: viewSize)
        showCurrentLine()
    }

    /// Advance to the next line or select choice. Returns true if dialogue is still active.
    @discardableResult
    public func advance(direction: Int = 0) -> Bool {
        guard isActive, let dialogue = currentDialogue else { return false }

        if isShowingChoices {
            // Select current choice
            let line = dialogue.lines[currentLineIndex]
            if let choices = line.choices, !choices.isEmpty {
                let choice = choices[selectedChoiceIndex]
                choice.onSelect?()

                // If choice leads to another dialogue, start it
                if let nextId = choice.nextDialogueId,
                   let _ = onRequestDialogue?(nextId) {
                    teardownUI()
                    // Will be re-started by the caller
                    isActive = false
                    onDialogueComplete?()
                    return false
                }
            }

            // Move to next line after choice
            isShowingChoices = false
            currentLineIndex += 1
            if currentLineIndex >= dialogue.lines.count {
                endDialogue()
                return false
            }
            showCurrentLine()
            return true
        }

        if !isFullyRevealed {
            // Reveal all text instantly
            revealAllText()
            return true
        }

        // Fire onComplete callback for this line
        let line = dialogue.lines[currentLineIndex]
        line.onComplete?()

        // Check for choices
        if let choices = line.choices, !choices.isEmpty {
            showChoices(choices)
            return true
        }

        // Advance to next line
        currentLineIndex += 1
        if currentLineIndex >= dialogue.lines.count {
            endDialogue()
            return false
        }

        showCurrentLine()
        return true
    }

    /// Navigate choices up/down
    public func moveChoice(by offset: Int) {
        guard isShowingChoices, let dialogue = currentDialogue else { return }
        let line = dialogue.lines[currentLineIndex]
        guard let choices = line.choices, !choices.isEmpty else { return }

        selectedChoiceIndex = (selectedChoiceIndex + offset + choices.count) % choices.count
        updateChoiceHighlight()
    }

    /// Update typewriter animation — call each frame
    public func update(deltaTime: TimeInterval) {
        guard isActive, !isFullyRevealed, !isShowingChoices else { return }
        guard let dialogue = currentDialogue else { return }

        let line = dialogue.lines[currentLineIndex]
        let totalChars = line.text.count

        revealTimer += deltaTime
        let charsPerSecond = GameConstants.typewriterCharsPerSecond
        let targetChars = Int(revealTimer * charsPerSecond)

        if targetChars >= totalChars {
            revealedCharCount = totalChars
            isFullyRevealed = true
            continueIndicator?.alpha = 1
        } else if targetChars > revealedCharCount {
            revealedCharCount = targetChars
        }

        // Update displayed text
        let fullText = line.text
        let index = fullText.index(fullText.startIndex, offsetBy: min(revealedCharCount, fullText.count))
        textLabel?.text = String(fullText[..<index])
    }

    /// Immediately end dialogue and clean up
    public func endDialogue() {
        isActive = false
        currentDialogue = nil
        teardownUI()
        onDialogueComplete?()
    }

    // MARK: - UI Construction

    private func buildUI(on parentNode: SKNode, viewSize: CGSize) {
        teardownUI()

        let container = SKNode()
        container.name = "dialogueContainer"
        container.zPosition = ZPositions.dialogue

        // Position at bottom of screen
        let boxY = -viewSize.height / 2 + boxHeight / 2 + 16

        // Dark semi-transparent background
        let bg = SKShapeNode(rectOf: CGSize(width: boxWidth, height: boxHeight), cornerRadius: boxCornerRadius)
        bg.fillColor = SKColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.92)
        bg.strokeColor = SKColor(red: 0.4, green: 0.35, blue: 0.6, alpha: 0.8)
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: boxY)
        container.addChild(bg)
        backgroundNode = bg

        // Speaker name label (top-left of box)
        let speaker = SKLabelNode(fontNamed: "AvenirNext-Bold")
        speaker.fontSize = speakerFontSize
        speaker.fontColor = SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        speaker.horizontalAlignmentMode = .left
        speaker.verticalAlignmentMode = .top
        speaker.position = CGPoint(
            x: -boxWidth / 2 + textPadding,
            y: boxHeight / 2 - 12
        )
        bg.addChild(speaker)
        speakerLabel = speaker

        // Main text label
        let text = SKLabelNode(fontNamed: "AvenirNext-Medium")
        text.fontSize = fontSize
        text.fontColor = .white
        text.horizontalAlignmentMode = .left
        text.verticalAlignmentMode = .top
        text.preferredMaxLayoutWidth = boxWidth - textPadding * 2
        text.numberOfLines = 0
        text.lineBreakMode = .byWordWrapping
        text.position = CGPoint(
            x: -boxWidth / 2 + textPadding,
            y: boxHeight / 2 - 30
        )
        bg.addChild(text)
        textLabel = text

        // Continue indicator (small triangle, bottom-right)
        let indicator = SKShapeNode(path: makeTrianglePath(size: 8))
        indicator.fillColor = .white
        indicator.strokeColor = .clear
        indicator.position = CGPoint(
            x: boxWidth / 2 - 20,
            y: -boxHeight / 2 + 16
        )
        indicator.alpha = 0
        // Pulsing animation
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.3, duration: 0.5),
            .fadeAlpha(to: 1.0, duration: 0.5)
        ])
        indicator.run(.repeatForever(pulse))
        bg.addChild(indicator)
        continueIndicator = indicator

        // Fade in
        container.alpha = 0
        container.run(.fadeAlpha(to: 1.0, duration: 0.2))

        parentNode.addChild(container)
        containerNode = container
    }

    private func teardownUI() {
        containerNode?.run(.sequence([
            .fadeAlpha(to: 0, duration: 0.15),
            .removeFromParent()
        ]))
        containerNode = nil
        backgroundNode = nil
        speakerLabel = nil
        textLabel = nil
        continueIndicator = nil
        choiceNodes.removeAll()
    }

    // MARK: - Display Helpers

    private func showCurrentLine() {
        guard let dialogue = currentDialogue else { return }
        let line = dialogue.lines[currentLineIndex]

        speakerLabel?.text = line.speaker
        textLabel?.text = ""
        revealedCharCount = 0
        revealTimer = 0
        isFullyRevealed = false
        isShowingChoices = false
        continueIndicator?.alpha = 0

        // Clear old choices
        for node in choiceNodes { node.removeFromParent() }
        choiceNodes.removeAll()
    }

    private func revealAllText() {
        guard let dialogue = currentDialogue else { return }
        let line = dialogue.lines[currentLineIndex]
        textLabel?.text = line.text
        revealedCharCount = line.text.count
        isFullyRevealed = true
        continueIndicator?.alpha = 1
    }

    private func showChoices(_ choices: [DialogueChoice]) {
        isShowingChoices = true
        selectedChoiceIndex = 0
        continueIndicator?.alpha = 0

        guard let bg = backgroundNode else { return }

        let choiceStartY: CGFloat = -boxHeight / 2 - 10
        let choiceHeight: CGFloat = 28
        let choiceGap: CGFloat = 4

        for (i, choice) in choices.enumerated() {
            let y = choiceStartY - CGFloat(i) * (choiceHeight + choiceGap)

            let pillW = boxWidth * 0.7
            let pill = SKShapeNode(rectOf: CGSize(width: pillW, height: choiceHeight), cornerRadius: choiceHeight / 2)
            pill.fillColor = i == 0
                ? SKColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 0.9)
                : SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.85)
            pill.strokeColor = i == 0
                ? SKColor(red: 0.5, green: 0.45, blue: 0.8, alpha: 0.9)
                : SKColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 0.6)
            pill.lineWidth = 1
            pill.position = CGPoint(x: 0, y: y)
            pill.name = "choice_\(i)"

            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = choice.text
            label.fontSize = 12
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            pill.addChild(label)

            bg.addChild(pill)
            choiceNodes.append(pill)
        }
    }

    private func updateChoiceHighlight() {
        for (i, node) in choiceNodes.enumerated() {
            guard let pill = node as? SKShapeNode else { continue }
            if i == selectedChoiceIndex {
                pill.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 0.9)
                pill.strokeColor = SKColor(red: 0.5, green: 0.45, blue: 0.8, alpha: 0.9)
            } else {
                pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.85)
                pill.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.5, alpha: 0.6)
            }
        }
    }

    // MARK: - Geometry Helpers

    private func makeTrianglePath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size / 2, y: size / 2))
        path.addLine(to: CGPoint(x: size / 2, y: size / 2))
        path.addLine(to: CGPoint(x: 0, y: -size / 2))
        path.closeSubpath()
        return path
    }
}
