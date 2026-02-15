import Foundation
import SpriteKit

// MARK: - Challenge Result

/// The outcome of a challenge attempt
public struct ChallengeResult {
    public let isCorrect: Bool
    public let xpAwarded: Int
    public let feedbackMessage: String
    public let selectedAnswer: String
    public let correctAnswer: String

    public init(
        isCorrect: Bool,
        xpAwarded: Int,
        feedbackMessage: String,
        selectedAnswer: String,
        correctAnswer: String
    ) {
        self.isCorrect = isCorrect
        self.xpAwarded = xpAwarded
        self.feedbackMessage = feedbackMessage
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
    }
}

// MARK: - Challenge Protocol

/// Protocol that all challenge types must conform to
public protocol Challenge: AnyObject {
    var subject: Subject { get }
    var difficulty: DifficultyLevel { get }
    var gradeLevel: GradeLevel { get }
    var questionText: String { get }
    var isComplete: Bool { get }

    /// Build the challenge UI on the given parent node
    func buildUI(on parentNode: SKNode, viewSize: CGSize)

    /// Handle input during the challenge. Returns a result if the challenge is complete.
    func handleInput(_ input: InputState) -> ChallengeResult?

    /// Update per-frame (for timers, animations)
    func update(deltaTime: TimeInterval)

    /// Clean up UI nodes
    func teardown()

    /// Handle a touch/click at a location in the scene (iOS tap-to-select).
    /// Default implementation does nothing.
    func handleTouch(at location: CGPoint, in scene: SKScene)
}

/// Default no-op for challenges that don't (yet) support touch
extension Challenge {
    public func handleTouch(at location: CGPoint, in scene: SKScene) {}
}

// MARK: - Round Challenge Protocol

/// Extends Challenge for multi-question rounds.
/// Conformers: MultipleChoiceChallenge, MixedRoundChallenge, and single-question challenge wrappers.
public protocol RoundChallenge: Challenge {
    /// Per-question correct/incorrect results in order
    var perQuestionResults: [Bool] { get }

    /// All questions in this round (as universal Question type)
    var allRoundQuestions: [Question] { get }

    /// Build the aggregate result for the entire round
    func buildAggregateResult() -> ChallengeResult

    /// Get correction info for a specific wrong answer.
    /// Returns (playerAnswer, correctAnswer, explanation) or nil if index invalid/correct.
    func correctionInfo(for questionIndex: Int) -> (playerAnswer: String, correctAnswer: String, explanation: String)?
}

// MARK: - Challenge Engine

/// Manages the lifecycle of in-game educational challenges.
/// Coordinates with the game state, player XP, and buddy reactions.
public final class ChallengeEngine {

    // MARK: - State

    public private(set) var isActive: Bool = false
    public private(set) var currentChallenge: Challenge?
    private var containerNode: SKNode?
    private var resultNode: SKNode?
    private var isShowingResult: Bool = false
    private var resultTimer: TimeInterval = 0
    private let resultDisplayDuration: TimeInterval = 30.0  // Summary stays until player presses E

    /// For scrolling the summary corrections
    private var summaryScrollNode: SKNode?
    private var summaryScrollOffset: CGFloat = 0
    private var summaryMaxScroll: CGFloat = 0

    /// Streak tracking for bonus XP
    public private(set) var currentStreak: Int = 0

    // MARK: - Callbacks

    /// Called when a challenge is completed (correct or incorrect)
    public var onChallengeComplete: ((ChallengeResult) -> Void)?

    /// Called when the entire challenge flow is dismissed (after result display)
    public var onChallengeDismissed: (() -> Void)?

    // MARK: - Loading State

    private var isLoading: Bool = false
    private var loadingNode: SKNode?
    private var loadingParentNode: SKNode?
    private var loadingViewSize: CGSize = .zero
    private var loadingSubjectColor: SKColor = .cyan

    // MARK: - Public API

    /// Show a "Preparing questions..." loading overlay immediately.
    /// Call `startChallenge(_:)` afterwards once questions are ready.
    public func showLoading(
        on parentNode: SKNode,
        viewSize: CGSize,
        subject: Subject
    ) {
        guard !isActive else { return }

        isActive = true
        isLoading = true
        isShowingResult = false
        resultTimer = 0

        let subjectColor: SKColor = {
            switch subject {
            case .languageArts: return GameColors.lexieColor.skColor
            case .math: return GameColors.digitColor.skColor
            case .science: return GameColors.novaColor.skColor
            case .social: return GameColors.harmonyColor.skColor
            }
        }()
        loadingSubjectColor = subjectColor

        // Create container
        let container = SKNode()
        container.name = "challengeContainer"
        container.zPosition = ZPositions.challenge

        // Semi-transparent backdrop
        let backdrop = SKShapeNode(rectOf: CGSize(
            width: viewSize.width * 2,
            height: viewSize.height * 2
        ))
        backdrop.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        backdrop.strokeColor = .clear
        backdrop.position = .zero
        container.addChild(backdrop)

        // Loading panel
        let panelW: CGFloat = 300
        let panelH: CGFloat = 140
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.95)
        panel.strokeColor = subjectColor.withAlphaComponent(0.7)
        panel.lineWidth = 2
        container.addChild(panel)

        // Subject badge
        let badge = SKLabelNode(fontNamed: "AvenirNext-Bold")
        badge.text = subject.rawValue
        badge.fontSize = 11
        badge.fontColor = subjectColor
        badge.verticalAlignmentMode = .center
        badge.position = CGPoint(x: 0, y: 38)
        container.addChild(badge)

        // "Preparing questions..." label
        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "Preparing questions..."
        label.fontSize = 16
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 6)
        container.addChild(label)

        // Animated dots
        let dots = SKLabelNode(fontNamed: "AvenirNext-Medium")
        dots.text = "◆  ◆  ◆"
        dots.fontSize = 14
        dots.fontColor = subjectColor.withAlphaComponent(0.6)
        dots.verticalAlignmentMode = .center
        dots.position = CGPoint(x: 0, y: -28)
        dots.name = "loadingDots"
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.3, duration: 0.4),
            .fadeAlpha(to: 1.0, duration: 0.4)
        ])
        dots.run(.repeatForever(pulse))
        container.addChild(dots)

        // Fade in
        container.alpha = 0
        container.run(.fadeAlpha(to: 1.0, duration: 0.15))

        parentNode.addChild(container)
        containerNode = container
        loadingParentNode = parentNode
        loadingViewSize = viewSize
    }

    /// Replace the loading screen with the actual challenge.
    /// If loading wasn't shown, starts normally.
    public func startChallengeAfterLoading(_ challenge: Challenge) {
        guard isActive, isLoading, let container = containerNode else {
            // Fallback: loading was never shown, shouldn't happen
            return
        }

        isLoading = false
        currentChallenge = challenge

        // Remove loading UI, build challenge UI in-place
        container.removeAllChildren()

        // Re-add backdrop
        let backdrop = SKShapeNode(rectOf: CGSize(
            width: loadingViewSize.width * 2,
            height: loadingViewSize.height * 2
        ))
        backdrop.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        backdrop.strokeColor = .clear
        backdrop.position = .zero
        container.addChild(backdrop)

        // Build challenge UI
        challenge.buildUI(on: container, viewSize: loadingViewSize)
    }

    /// Start a challenge, displaying it on the given parent node
    public func startChallenge(
        _ challenge: Challenge,
        on parentNode: SKNode,
        viewSize: CGSize
    ) {
        guard !isActive else { return }

        currentChallenge = challenge
        isActive = true
        isLoading = false
        isShowingResult = false
        resultTimer = 0

        // Create container
        let container = SKNode()
        container.name = "challengeContainer"
        container.zPosition = ZPositions.challenge

        // Semi-transparent backdrop
        let backdrop = SKShapeNode(rectOf: CGSize(
            width: viewSize.width * 2,
            height: viewSize.height * 2
        ))
        backdrop.fillColor = SKColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        backdrop.strokeColor = .clear
        backdrop.position = .zero
        container.addChild(backdrop)

        // Build the challenge-specific UI
        challenge.buildUI(on: container, viewSize: viewSize)

        // Fade in
        container.alpha = 0
        container.run(.fadeAlpha(to: 1.0, duration: 0.25))

        parentNode.addChild(container)
        containerNode = container
    }

    /// Handle input for the active challenge
    public func handleInput(_ input: InputState) {
        guard isActive else { return }
        guard !isLoading else { return }  // Block input while loading

        // If showing result summary, allow scrolling and dismiss on interact/confirm
        if isShowingResult {
            // Scroll corrections up/down
            if let scrollNode = summaryScrollNode, summaryMaxScroll > 0 {
                let scrollSpeed: CGFloat = 8
                if input.isPressed(.moveUp) || input.isHeld(.moveUp) {
                    summaryScrollOffset = min(summaryScrollOffset + scrollSpeed, summaryMaxScroll)
                    scrollNode.position.y = -summaryScrollOffset
                }
                if input.isPressed(.moveDown) || input.isHeld(.moveDown) {
                    summaryScrollOffset = max(summaryScrollOffset - scrollSpeed, 0)
                    scrollNode.position.y = -summaryScrollOffset
                }
            }
            if input.isPressed(.interact) || input.isPressed(.confirm) {
                dismissChallenge()
            }
            return
        }

        // Pass input to the challenge
        guard let challenge = currentChallenge else { return }
        if let result = challenge.handleInput(input) {
            completeChallenge(with: result)
        }
    }

    /// Route a touch/click to the active challenge (iOS tap-to-select)
    public func handleTouch(at location: CGPoint, in scene: SKScene) {
        guard isActive, !isLoading else { return }

        // If showing result summary, tap anywhere to dismiss
        if isShowingResult {
            dismissChallenge()
            return
        }

        currentChallenge?.handleTouch(at: location, in: scene)
    }

    /// Per-frame update for active challenge
    public func update(deltaTime: TimeInterval) {
        guard isActive else { return }
        guard !isLoading else { return }  // Skip updates while loading

        if isShowingResult {
            resultTimer += deltaTime
            if resultTimer >= resultDisplayDuration {
                // Auto-dismiss after timeout
                dismissChallenge()
            }
            return
        }

        currentChallenge?.update(deltaTime: deltaTime)

        // Check if the challenge round is complete (multi-question)
        if let challenge = currentChallenge, challenge.isComplete, !isShowingResult {
            if let roundChallenge = challenge as? RoundChallenge {
                let aggregateResult = roundChallenge.buildAggregateResult()
                completeChallenge(with: aggregateResult)
            }
        }
    }

    /// Cancel the current challenge without completing
    public func cancelChallenge() {
        guard isActive else { return }
        currentStreak = 0
        cleanupUI()
        isActive = false
        currentChallenge = nil
        onChallengeDismissed?()
    }

    // MARK: - Private

    private func completeChallenge(with result: ChallengeResult) {
        isShowingResult = true
        resultTimer = 0

        // Update streak
        if result.isCorrect {
            currentStreak += 1
        } else {
            currentStreak = 0
        }

        // Notify listener (GameEngine will handle XP, buddy reactions)
        onChallengeComplete?(result)

        // Show result feedback UI
        showResultFeedback(result)
    }

    private func showResultFeedback(_ result: ChallengeResult) {
        guard let container = containerNode else { return }

        // Gather wrong-answer data from the challenge (works with any RoundChallenge)
        let roundChallenge = currentChallenge as? RoundChallenge
        let wrongIndices: [Int] = {
            guard let rc = roundChallenge else { return [] }
            return rc.perQuestionResults.enumerated()
                .filter { !$0.element }
                .map(\.offset)
        }()

        // Remove the challenge-specific UI
        currentChallenge?.teardown()

        let feedbackNode = SKNode()
        feedbackNode.name = "challengeResult"

        // Panel sizing — taller when there are corrections
        let panelW: CGFloat = 520
        let hasCorrections = !wrongIndices.isEmpty
        let correctionsBlockHeight: CGFloat = hasCorrections ? CGFloat(wrongIndices.count) * 80 + 30 : 0
        let basePanelH: CGFloat = 200
        let panelH: CGFloat = min(basePanelH + correctionsBlockHeight, 500)

        // Main panel
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 16)
        panel.fillColor = SKColor(red: 0.06, green: 0.06, blue: 0.12, alpha: 0.95)
        panel.strokeColor = result.isCorrect
            ? GameColors.correctGreen.skColor
            : SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 0.8)
        panel.lineWidth = 2
        feedbackNode.addChild(panel)

        // ── Top section: Score + Encouragement ──
        let topY = panelH / 2 - 18

        // Score line: "You got 3 out of 5 correct!"
        let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        scoreLabel.text = result.feedbackMessage
        scoreLabel.fontSize = 17
        scoreLabel.fontColor = .white
        scoreLabel.verticalAlignmentMode = .center
        scoreLabel.position = CGPoint(x: 0, y: topY)
        feedbackNode.addChild(scoreLabel)

        // Progress dots showing which were right/wrong
        if let rc = roundChallenge {
            let dotStartX = -CGFloat(rc.perQuestionResults.count - 1) * 10
            let dotY = topY - 22
            for (i, wasCorrect) in rc.perQuestionResults.enumerated() {
                let dot = SKShapeNode(circleOfRadius: 5)
                dot.fillColor = wasCorrect
                    ? GameColors.correctGreen.skColor
                    : GameColors.incorrectRed.skColor
                dot.strokeColor = .clear
                dot.position = CGPoint(x: dotStartX + CGFloat(i) * 20, y: dotY)
                feedbackNode.addChild(dot)

                let dotLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
                dotLabel.text = wasCorrect ? "✓" : "✗"
                dotLabel.fontSize = 8
                dotLabel.fontColor = .white
                dotLabel.verticalAlignmentMode = .center
                dotLabel.position = CGPoint(x: dotStartX + CGFloat(i) * 20, y: dotY)
                feedbackNode.addChild(dotLabel)
            }
        }

        // Encouragement message
        let encourageY = topY - 44
        let encourageLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        encourageLabel.fontSize = 13
        encourageLabel.verticalAlignmentMode = .center
        encourageLabel.horizontalAlignmentMode = .center

        let correctCount = roundChallenge?.perQuestionResults.filter { $0 }.count ?? (result.isCorrect ? 1 : 0)
        let totalCount = roundChallenge?.allRoundQuestions.count ?? 1
        let ratio = totalCount > 0 ? Double(correctCount) / Double(totalCount) : 0

        if ratio == 1.0 {
            encourageLabel.text = "Perfect score! You're a superstar!"
            encourageLabel.fontColor = GameColors.xpBarFill.skColor
        } else if ratio >= 0.8 {
            encourageLabel.text = "Amazing work! Almost perfect!"
            encourageLabel.fontColor = GameColors.correctGreen.skColor
        } else if ratio >= 0.6 {
            encourageLabel.text = "Good job! Keep practicing and you'll master it!"
            encourageLabel.fontColor = SKColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1)
        } else if ratio >= 0.4 {
            encourageLabel.text = "Nice try! Let's learn from the ones you missed."
            encourageLabel.fontColor = SKColor(red: 0.9, green: 0.7, blue: 0.3, alpha: 1)
        } else {
            encourageLabel.text = "Don't give up! Every try helps you learn!"
            encourageLabel.fontColor = SKColor(red: 0.9, green: 0.5, blue: 0.5, alpha: 1)
        }
        encourageLabel.position = CGPoint(x: 0, y: encourageY)
        feedbackNode.addChild(encourageLabel)

        // XP awarded
        let xpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        xpLabel.text = "+\(result.xpAwarded) XP"
        xpLabel.fontSize = 15
        xpLabel.fontColor = GameColors.xpBarFill.skColor
        xpLabel.verticalAlignmentMode = .center
        xpLabel.position = CGPoint(x: 0, y: encourageY - 18)
        feedbackNode.addChild(xpLabel)

        // ── Corrections section (only if there are wrong answers) ──
        if hasCorrections {
            let separatorY = encourageY - 36
            let separatorLine = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 1))
            separatorLine.fillColor = SKColor(white: 0.3, alpha: 0.6)
            separatorLine.strokeColor = .clear
            separatorLine.position = CGPoint(x: 0, y: separatorY)
            feedbackNode.addChild(separatorLine)

            let correctionHeader = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            correctionHeader.text = "Let's Review:"
            correctionHeader.fontSize = 13
            correctionHeader.fontColor = SKColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1)
            correctionHeader.verticalAlignmentMode = .center
            correctionHeader.horizontalAlignmentMode = .center
            correctionHeader.position = CGPoint(x: 0, y: separatorY - 16)
            feedbackNode.addChild(correctionHeader)

            // Scrollable area for corrections
            let clipHeight = panelH - (panelH / 2 - separatorY + 26) - 32
            let scrollAreaY = separatorY - 26

            // Clip node to mask overflow
            let clipNode = SKCropNode()
            let maskShape = SKShapeNode(rectOf: CGSize(width: panelW - 20, height: clipHeight))
            maskShape.fillColor = .white
            clipNode.maskNode = maskShape
            clipNode.position = CGPoint(x: 0, y: scrollAreaY - clipHeight / 2)
            feedbackNode.addChild(clipNode)

            let scrollContent = SKNode()
            clipNode.addChild(scrollContent)

            var yOffset: CGFloat = clipHeight / 2 - 10
            let itemSpacing: CGFloat = 8
            let contentWidth = panelW - 50

            for (displayIdx, wrongIdx) in wrongIndices.enumerated() {
                // Get correction info via the RoundChallenge protocol
                let correction = roundChallenge?.correctionInfo(for: wrongIdx)
                let qText = roundChallenge?.allRoundQuestions[safe: wrongIdx]?.questionText ?? "?"
                let playerAns = correction?.playerAnswer ?? "?"
                let correctAns = correction?.correctAnswer ?? "?"
                let explanation = correction?.explanation ?? ""

                // Question number + text
                let qLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                qLabel.text = "Q\(displayIdx + 1): \(qText)"
                qLabel.fontSize = 11
                qLabel.fontColor = .white
                qLabel.verticalAlignmentMode = .top
                qLabel.horizontalAlignmentMode = .left
                qLabel.preferredMaxLayoutWidth = contentWidth
                qLabel.numberOfLines = 0
                qLabel.lineBreakMode = .byWordWrapping
                qLabel.position = CGPoint(x: -contentWidth / 2, y: yOffset)
                scrollContent.addChild(qLabel)

                let qTextHeight = max(qLabel.frame.height, 14)
                yOffset -= qTextHeight + 4

                // Your answer (red) + Correct answer (green)
                let yourLabel = SKLabelNode(fontNamed: "AvenirNext-Medium")
                yourLabel.text = "Your answer: \(playerAns)"
                yourLabel.fontSize = 10
                yourLabel.fontColor = GameColors.incorrectRed.skColor
                yourLabel.verticalAlignmentMode = .top
                yourLabel.horizontalAlignmentMode = .left
                yourLabel.preferredMaxLayoutWidth = contentWidth
                yourLabel.numberOfLines = 1
                yourLabel.position = CGPoint(x: -contentWidth / 2 + 10, y: yOffset)
                scrollContent.addChild(yourLabel)
                yOffset -= 14

                let correctLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
                correctLabel.text = "Correct: \(correctAns)"
                correctLabel.fontSize = 10
                correctLabel.fontColor = GameColors.correctGreen.skColor
                correctLabel.verticalAlignmentMode = .top
                correctLabel.horizontalAlignmentMode = .left
                correctLabel.preferredMaxLayoutWidth = contentWidth
                correctLabel.numberOfLines = 1
                correctLabel.position = CGPoint(x: -contentWidth / 2 + 10, y: yOffset)
                scrollContent.addChild(correctLabel)
                yOffset -= 14

                // Explanation
                if !explanation.isEmpty {
                    let explLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
                    explLabel.text = "💡 \(explanation)"
                    explLabel.fontSize = 10
                    explLabel.fontColor = SKColor(white: 0.7, alpha: 1)
                    explLabel.verticalAlignmentMode = .top
                    explLabel.horizontalAlignmentMode = .left
                    explLabel.preferredMaxLayoutWidth = contentWidth
                    explLabel.numberOfLines = 0
                    explLabel.lineBreakMode = .byWordWrapping
                    explLabel.position = CGPoint(x: -contentWidth / 2 + 10, y: yOffset)
                    scrollContent.addChild(explLabel)
                    let explHeight = max(explLabel.frame.height, 12)
                    yOffset -= explHeight + 2
                }

                yOffset -= itemSpacing
            }

            // Calculate scroll bounds
            let totalContentHeight = (clipHeight / 2 - 10) - yOffset
            summaryMaxScroll = max(totalContentHeight - clipHeight, 0)
            summaryScrollOffset = 0
            summaryScrollNode = scrollContent

            // Show scroll hint if content overflows
            if summaryMaxScroll > 0 {
                let scrollHint = SKLabelNode(fontNamed: "AvenirNext-Medium")
                scrollHint.text = "↑↓ Scroll to see more"
                scrollHint.fontSize = 9
                scrollHint.fontColor = SKColor(white: 0.45, alpha: 1)
                scrollHint.verticalAlignmentMode = .center
                scrollHint.position = CGPoint(x: 0, y: scrollAreaY - clipHeight - 6)
                feedbackNode.addChild(scrollHint)
            }
        } else {
            summaryScrollNode = nil
            summaryMaxScroll = 0
        }

        // "Press E to continue" / "Tap to continue" hint (bottom of panel)
        let hint = SKLabelNode(fontNamed: "AvenirNext-Medium")
        #if os(iOS)
        hint.text = "Tap to continue"
        #else
        hint.text = "Press E to continue"
        #endif
        hint.fontSize = 11
        hint.fontColor = SKColor(white: 0.6, alpha: 1)
        hint.verticalAlignmentMode = .center
        hint.position = CGPoint(x: 0, y: -panelH / 2 + 14)
        feedbackNode.addChild(hint)

        // Animate in
        feedbackNode.alpha = 0
        feedbackNode.setScale(0.8)
        feedbackNode.run(.group([
            .fadeAlpha(to: 1.0, duration: 0.3),
            .scale(to: 1.0, duration: 0.3)
        ]))

        container.addChild(feedbackNode)
        resultNode = feedbackNode
    }

    private func dismissChallenge() {
        cleanupUI()
        isActive = false
        currentChallenge = nil
        isShowingResult = false
        summaryScrollNode = nil
        summaryScrollOffset = 0
        summaryMaxScroll = 0
        onChallengeDismissed?()
    }

    private func cleanupUI() {
        currentChallenge?.teardown()
        containerNode?.run(.sequence([
            .fadeAlpha(to: 0, duration: 0.2),
            .removeFromParent()
        ]))
        containerNode = nil
        resultNode = nil
    }
}
