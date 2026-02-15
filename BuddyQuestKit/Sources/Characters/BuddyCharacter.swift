import Foundation
import SpriteKit

// MARK: - Buddy Emotion

public enum BuddyEmotion: String {
    case happy
    case thinking
    case excited
    case encouraging
    case idle
}

// MARK: - Buddy Character

/// A companion character that follows the player, reacts to events,
/// and shows contextual speech bubbles. Each buddy has a distinct
/// personality, color, and subject specialization.
public final class BuddyCharacter {
    public let buddyType: BuddyType
    public let node: SKNode
    public let spriteNode: SKSpriteNode

    public var position: CGPoint {
        get { node.position }
        set { node.position = newValue }
    }

    public private(set) var direction: Direction = .down
    public private(set) var emotion: BuddyEmotion = .idle

    // Following state
    private var targetPosition: CGPoint = .zero
    private var isFollowing: Bool = true
    private let followDistance: CGFloat = GameConstants.buddyFollowDistance
    private let followSpeed: CGFloat = GameConstants.buddyFollowSpeed

    // Position history for smooth trailing (breadcrumb following)
    private var playerPositionHistory: [CGPoint] = []
    private let historyMaxCount: Int = 20
    private var historyTimer: TimeInterval = 0
    private let historySampleInterval: TimeInterval = 0.08

    // Speech bubble
    private var speechBubbleNode: SKNode?
    private var speechTimer: TimeInterval = 0
    private var isSpeaking: Bool = false

    // Idle animation
    private var idleTimer: TimeInterval = 0
    private var nextIdleSpeechTime: TimeInterval = 15

    // Personality lines
    private let personality: BuddyPersonalityData

    // Texture support (per-buddy, loaded from Art/Buddy/<name>/ if available)
    private var directionTextures: [Direction: SKTexture]?

    /// Texture cache keyed by buddy type — loaded once, shared across instances
    private static var buddyTextures: [BuddyType: [Direction: SKTexture]] = [:]

    /// Attempt to load textures for a buddy type. Returns nil if no art exists.
    private static func loadTextures(for type: BuddyType) -> [Direction: SKTexture]? {
        if let cached = buddyTextures[type] { return cached }

        // All buddies have pixel-art sprites
        let prefix: String
        switch type {
        case .lexie: prefix = "lexie"
        case .nova: prefix = "nova"
        case .digit: prefix = "digit"
        case .harmony: prefix = "harmony"
        }

        let mapping: [Direction: String] = [
            .down:  "\(prefix)_down",
            .up:    "\(prefix)_up",
            .left:  "\(prefix)_left",
            .right: "\(prefix)_right"
        ]
        var textures: [Direction: SKTexture] = [:]
        for (dir, name) in mapping {
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .nearest  // preserve pixel-art crispness
            textures[dir] = tex
        }
        buddyTextures[type] = textures
        return textures
    }

    public init(type: BuddyType) {
        self.buddyType = type
        self.personality = BuddyPersonalityData.forType(type)

        node = SKNode()
        node.name = "buddy_\(type.rawValue)"
        node.zPosition = ZPositions.entities + 1  // Slightly above NPCs

        // Check if this buddy has pixel-art textures
        if let textures = Self.loadTextures(for: type) {
            // Use texture-based sprite
            directionTextures = textures
            let buddySize = CGSize(width: 40, height: 40)  // Slightly smaller than player
            spriteNode = SKSpriteNode(
                texture: textures[.down],
                size: buddySize
            )
            spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.25)
            node.addChild(spriteNode)
        } else {
            // Fall back to programmatic shapes
            directionTextures = nil
            let size = CGSize(width: 36, height: 36)
            spriteNode = SKSpriteNode(color: .clear, size: size)
            spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.25)
            node.addChild(spriteNode)
            buildBuddySprite()
        }
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        // Record player position breadcrumbs
        historyTimer += deltaTime
        if historyTimer >= historySampleInterval {
            historyTimer = 0
            playerPositionHistory.append(playerPosition)
            if playerPositionHistory.count > historyMaxCount {
                playerPositionHistory.removeFirst()
            }
        }

        // Follow the player using position history (trail behind)
        if isFollowing {
            updateFollowing(deltaTime: deltaTime, playerPosition: playerPosition)
        }

        // Face same direction as movement
        let dist = position.distance(to: playerPosition)
        if dist > followDistance * 0.5 {
            faceToward(playerPosition)
        }

        // Idle bob
        let time = CACurrentMediaTime()
        spriteNode.position.y = sin(CGFloat(time) * 3.0) * 2

        // Speech bubble timer
        if isSpeaking {
            speechTimer -= deltaTime
            if speechTimer <= 0 {
                dismissSpeechBubble()
            }
        }

        // Idle speech timer
        idleTimer += deltaTime
        if idleTimer >= nextIdleSpeechTime && !isSpeaking {
            sayRandomIdleLine()
            idleTimer = 0
            nextIdleSpeechTime = TimeInterval.random(in: 12...25)
        }
    }

    // MARK: - Following AI

    private func updateFollowing(deltaTime: TimeInterval, playerPosition: CGPoint) {
        let dist = position.distance(to: playerPosition)

        guard dist > followDistance else { return }

        // Follow a trailing position from history (for smooth path following)
        let trailTarget: CGPoint
        if playerPositionHistory.count >= 8 {
            trailTarget = playerPositionHistory[playerPositionHistory.count - 8]
        } else if let first = playerPositionHistory.first {
            trailTarget = first
        } else {
            trailTarget = playerPosition
        }

        let direction = (trailTarget - position).normalized()
        let moveSpeed: CGFloat

        if dist > followDistance * 3 {
            // Too far — teleport closer
            position = playerPosition - CGPoint(x: followDistance * 0.8, y: 0)
            return
        } else if dist > followDistance * 1.5 {
            moveSpeed = followSpeed * 1.4  // Hurry up
        } else {
            moveSpeed = followSpeed
        }

        let delta = direction * (moveSpeed * CGFloat(deltaTime))
        position = position + delta
    }

    // MARK: - Speech Bubbles

    /// Show a speech bubble with text above the buddy
    public func say(_ text: String, duration: TimeInterval = GameConstants.speechBubbleDuration) {
        dismissSpeechBubble()

        let bubble = SKNode()
        bubble.name = "speechBubble"
        bubble.zPosition = 10

        // Measure text
        let label = SKLabelNode(fontNamed: "AvenirNext-Medium")
        label.text = text
        label.fontSize = 10
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.preferredMaxLayoutWidth = 140
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping

        let padding: CGFloat = 10
        let bubbleWidth = min(label.frame.width + padding * 2, 160)
        let bubbleHeight = label.frame.height + padding * 2

        // Background pill
        let bg = SKShapeNode(rectOf: CGSize(width: bubbleWidth, height: bubbleHeight), cornerRadius: 8)
        bg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.85)
        bg.strokeColor = buddyColor.withAlphaComponent(0.6)
        bg.lineWidth = 1
        bubble.addChild(bg)
        bubble.addChild(label)

        // Small triangle pointer below bubble
        let trianglePath = CGMutablePath()
        trianglePath.move(to: CGPoint(x: -5, y: -bubbleHeight / 2))
        trianglePath.addLine(to: CGPoint(x: 5, y: -bubbleHeight / 2))
        trianglePath.addLine(to: CGPoint(x: 0, y: -bubbleHeight / 2 - 6))
        trianglePath.closeSubpath()
        let triangle = SKShapeNode(path: trianglePath)
        triangle.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.85)
        triangle.strokeColor = .clear
        bubble.addChild(triangle)

        // Position above buddy
        bubble.position = CGPoint(x: 0, y: 48)
        bubble.alpha = 0
        bubble.run(.fadeAlpha(to: 1.0, duration: 0.2))

        node.addChild(bubble)
        speechBubbleNode = bubble
        speechTimer = duration
        isSpeaking = true
    }

    private func dismissSpeechBubble() {
        speechBubbleNode?.run(.sequence([
            .fadeAlpha(to: 0, duration: 0.15),
            .removeFromParent()
        ]))
        speechBubbleNode = nil
        isSpeaking = false
    }

    // MARK: - Contextual Reactions

    /// React to player getting an answer correct
    public func reactCorrect() {
        emotion = .excited
        say(personality.correctLines.randomElement() ?? "Great job!")
    }

    /// React to player getting an answer wrong
    public func reactIncorrect() {
        emotion = .encouraging
        say(personality.encourageLines.randomElement() ?? "Keep trying!")
    }

    /// React to entering a new zone
    public func reactZoneEnter(zoneName: String) {
        emotion = .excited
        let line = personality.zoneEnterLines.randomElement() ?? "Wow, look at this place!"
        say(line.replacingOccurrences(of: "{zone}", with: zoneName), duration: 4.0)
    }

    /// React to player interacting with the buddy (E key)
    public func reactInteraction() {
        emotion = .happy
        let line = personality.interactionLines.randomElement() ?? "Hi there, friend!"
        say(line, duration: 4.0)
    }

    /// React to reaching a new bond level
    public func reactBondLevelUp(level: BondLevel) {
        emotion = .excited
        let line = personality.bondLevelUpLines[level]
            ?? "I feel our friendship growing stronger!"
        say(line, duration: 5.0)
    }

    /// Show floating bond points text above the buddy
    public func showBondPointsEarned(_ points: Int) {
        let floater = SKLabelNode(fontNamed: "AvenirNext-Bold")
        floater.text = "+\(points) Bond \u{2764}\u{FE0F}"
        floater.fontSize = 11
        floater.fontColor = SKColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1)
        floater.verticalAlignmentMode = .center
        floater.horizontalAlignmentMode = .center
        floater.position = CGPoint(x: 0, y: 36)
        floater.zPosition = 12
        floater.alpha = 0
        node.addChild(floater)

        floater.run(.sequence([
            .group([
                .fadeAlpha(to: 1.0, duration: 0.2),
                .moveBy(x: 0, y: 20, duration: 1.0)
            ]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }

    /// Say a random idle line
    private func sayRandomIdleLine() {
        emotion = .idle
        if let line = personality.idleLines.randomElement() {
            say(line, duration: 3.5)
        }
    }

    // MARK: - Direction

    private func faceToward(_ target: CGPoint) {
        let dx = target.x - position.x
        let dy = target.y - position.y
        let newDirection: Direction
        if abs(dx) > abs(dy) {
            newDirection = dx > 0 ? .right : .left
        } else {
            newDirection = dy > 0 ? .up : .down
        }
        if newDirection != direction {
            direction = newDirection
            updateBuddySprite()
        }
    }

    private func updateBuddySprite() {
        if let tex = directionTextures?[direction] {
            spriteNode.texture = tex
        }
    }

    // MARK: - Visual

    private var buddyColor: SKColor {
        switch buddyType {
        case .nova: return GameColors.novaColor.skColor
        case .lexie: return GameColors.lexieColor.skColor
        case .digit: return GameColors.digitColor.skColor
        case .harmony: return GameColors.harmonyColor.skColor
        }
    }

    private func buildBuddySprite() {
        let color = buddyColor

        // Body (round shape, smaller than player)
        let body = SKShapeNode(ellipseOf: CGSize(width: 24, height: 24))
        body.fillColor = color
        body.strokeColor = color.withAlphaComponent(0.5)
        body.lineWidth = 2
        body.position = CGPoint(x: 0, y: 10)
        spriteNode.addChild(body)

        // Eyes (two small white dots)
        let eyeL = SKShapeNode(circleOfRadius: 3)
        eyeL.fillColor = .white
        eyeL.strokeColor = .clear
        eyeL.position = CGPoint(x: -5, y: 14)
        spriteNode.addChild(eyeL)

        let eyeR = SKShapeNode(circleOfRadius: 3)
        eyeR.fillColor = .white
        eyeR.strokeColor = .clear
        eyeR.position = CGPoint(x: 5, y: 14)
        spriteNode.addChild(eyeR)

        // Pupils
        let pupilL = SKShapeNode(circleOfRadius: 1.5)
        pupilL.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1)
        pupilL.strokeColor = .clear
        pupilL.position = CGPoint(x: -4, y: 14)
        spriteNode.addChild(pupilL)

        let pupilR = SKShapeNode(circleOfRadius: 1.5)
        pupilR.fillColor = SKColor(red: 0.15, green: 0.15, blue: 0.2, alpha: 1)
        pupilR.strokeColor = .clear
        pupilR.position = CGPoint(x: 6, y: 14)
        spriteNode.addChild(pupilR)

        // Type-specific accent
        switch buddyType {
        case .nova:
            // Goggles (small arc on top)
            let goggles = SKShapeNode(circleOfRadius: 5)
            goggles.fillColor = SKColor(red: 0.8, green: 0.9, blue: 1, alpha: 0.4)
            goggles.strokeColor = SKColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 0.8)
            goggles.lineWidth = 1
            goggles.position = CGPoint(x: 0, y: 22)
            spriteNode.addChild(goggles)

        case .lexie:
            // Small book icon
            let book = SKShapeNode(rectOf: CGSize(width: 8, height: 6), cornerRadius: 1)
            book.fillColor = SKColor(red: 1, green: 0.7, blue: 0.3, alpha: 1)
            book.strokeColor = .clear
            book.position = CGPoint(x: 14, y: 8)
            book.zRotation = 0.2
            spriteNode.addChild(book)

        case .digit:
            // Geometric pattern (small diamond)
            let diamond = SKShapeNode(rectOf: CGSize(width: 6, height: 6))
            diamond.fillColor = SKColor(red: 1, green: 0.85, blue: 0.2, alpha: 1)
            diamond.strokeColor = .clear
            diamond.zRotation = .pi / 4
            diamond.position = CGPoint(x: 0, y: 24)
            spriteNode.addChild(diamond)

        case .harmony:
            // Heart accent
            let heart = SKLabelNode(text: "♥")
            heart.fontSize = 8
            heart.fontColor = SKColor(red: 1, green: 0.5, blue: 0.6, alpha: 0.8)
            heart.position = CGPoint(x: 0, y: 24)
            heart.verticalAlignmentMode = .center
            spriteNode.addChild(heart)
        }
    }
}

// MARK: - Buddy Personality Data

/// Static personality lines for each buddy type
public struct BuddyPersonalityData {
    public let catchphrase: String
    public let idleLines: [String]
    public let correctLines: [String]
    public let encourageLines: [String]
    public let zoneEnterLines: [String]
    public let interactionLines: [String]
    public let bondLevelUpLines: [BondLevel: String]

    public static func forType(_ type: BuddyType) -> BuddyPersonalityData {
        switch type {
        case .nova:
            return BuddyPersonalityData(
                catchphrase: "Fascinating!",
                idleLines: [
                    "I wonder what would happen if...",
                    "Did you know stars are made of plasma?",
                    "Let's investigate!",
                    "My hypothesis is we should explore more.",
                    "Science is all around us!",
                ],
                correctLines: [
                    "Excellent deduction!",
                    "Hypothesis confirmed!",
                    "Your brain is firing on all cylinders!",
                    "That's scientifically brilliant!",
                ],
                encourageLines: [
                    "Every great scientist makes mistakes!",
                    "Let's analyze that again...",
                    "Hmm, what if we try a different approach?",
                    "Don't give up — discovery takes time!",
                ],
                zoneEnterLines: [
                    "Whoa, look at {zone}! I bet there's so much to discover!",
                    "The {zone}... I can already sense new experiments!",
                    "What fascinating data will we find in {zone}?",
                ],
                interactionLines: [
                    "Did you know water boils at 100 degrees?",
                    "I've been thinking about gravity...",
                    "Want to hear a fun fact about space?",
                    "You're my favorite lab partner!",
                    "Let's discover something new together!",
                ],
                bondLevelUpLines: [
                    .goodBuddy: "Our friendship is like a proven theory — solid!",
                    .greatBuddy: "We've reached a whole new level of discovery together!",
                    .bestBuddy: "You're my best friend in the whole universe!",
                ]
            )

        case .lexie:
            return BuddyPersonalityData(
                catchphrase: "Once upon a time...",
                idleLines: [
                    "Every place has a story to tell!",
                    "Words are like little spells, you know?",
                    "I'm composing a poem in my head...",
                    "What chapter of our adventure is this?",
                    "Let me tell you something interesting...",
                ],
                correctLines: [
                    "What a wonderful answer!",
                    "You have a way with words!",
                    "Perfectly written! I mean, said!",
                    "That's a story-worthy answer!",
                ],
                encourageLines: [
                    "Even the best authors need drafts!",
                    "Let's rewrite that chapter together!",
                    "Not every word comes easily — keep going!",
                    "The best stories have twists!",
                ],
                zoneEnterLines: [
                    "{zone}! I bet there are amazing stories here!",
                    "Oh, {zone} — this place writes itself!",
                    "What tales will we uncover in {zone}?",
                ],
                interactionLines: [
                    "I just thought of a great rhyme!",
                    "You know what would make a great story?",
                    "I love adventuring with you!",
                    "Want to hear a poem I wrote about us?",
                    "Our friendship is my favorite story!",
                ],
                bondLevelUpLines: [
                    .goodBuddy: "Our friendship story just got a whole new chapter!",
                    .greatBuddy: "If I wrote a book about us, it'd be a bestseller!",
                    .bestBuddy: "You're the hero of my favorite story — forever!",
                ]
            )

        case .digit:
            return BuddyPersonalityData(
                catchphrase: "Let me calculate...",
                idleLines: [
                    "Did you notice the pattern in these tiles?",
                    "I count things when I'm bored. There are a lot of tiles here.",
                    "Math is everywhere if you look closely!",
                    "I love a good puzzle!",
                    "The probability of fun here is 100%!",
                ],
                correctLines: [
                    "That's the right answer! Calculated perfectly!",
                    "Your math skills are adding up!",
                    "Precisely correct!",
                    "The numbers don't lie — you nailed it!",
                ],
                encourageLines: [
                    "Let's break this problem into smaller parts!",
                    "Close! Let's try counting again...",
                    "Even calculators need a retry sometimes!",
                    "Think step by step — you've got this!",
                ],
                zoneEnterLines: [
                    "{zone}! I bet there are patterns everywhere!",
                    "The {zone}... time to crunch some numbers!",
                    "I calculate a 100% chance of learning in {zone}!",
                ],
                interactionLines: [
                    "I counted all the steps we've taken today!",
                    "The equation of our friendship = awesome!",
                    "Want to hear a number joke?",
                    "You + me = the best team!",
                    "I'm so glad we're exploring together!",
                ],
                bondLevelUpLines: [
                    .goodBuddy: "Our friendship just multiplied! This is exponential!",
                    .greatBuddy: "We've reached a prime level of friendship!",
                    .bestBuddy: "Our bond is infinite — you're my best friend!",
                ]
            )

        case .harmony:
            return BuddyPersonalityData(
                catchphrase: "We're better together!",
                idleLines: [
                    "Working together makes everything better!",
                    "How are you feeling today?",
                    "I think we make a great team!",
                    "Kindness is a superpower, you know.",
                    "Let's make some friends here!",
                ],
                correctLines: [
                    "You're amazing! I knew you could do it!",
                    "Teamwork makes the dream work!",
                    "That was so thoughtful!",
                    "You make me so proud!",
                ],
                encourageLines: [
                    "It's okay — we learn from every try!",
                    "I believe in you! Let's try again!",
                    "Friends help each other — and I'm here!",
                    "Take a deep breath — you'll get it!",
                ],
                zoneEnterLines: [
                    "{zone}! I hope we make new friends here!",
                    "Oh, {zone} feels so welcoming!",
                    "I bet everyone in {zone} is really nice!",
                ],
                interactionLines: [
                    "I'm so happy we're friends!",
                    "You always make me smile!",
                    "Want a virtual hug?",
                    "Being kind is what makes you special!",
                    "I feel safe when I'm with you!",
                ],
                bondLevelUpLines: [
                    .goodBuddy: "Our hearts are in harmony — we're Good Buddies!",
                    .greatBuddy: "I've never felt this close to anyone!",
                    .bestBuddy: "You're my best friend in the whole world!",
                ]
            )
        }
    }
}
