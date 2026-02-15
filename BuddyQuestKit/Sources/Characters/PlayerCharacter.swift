import Foundation
import SpriteKit

/// The player-controlled character entity
public final class PlayerCharacter {
    public let node: SKNode
    public let spriteNode: SKSpriteNode

    public var position: CGPoint {
        get { node.position }
        set { node.position = newValue }
    }

    public private(set) var direction: Direction = .down
    public private(set) var isMoving: Bool = false

    // Stats
    public var level: Int = 1
    public var totalXP: Int = 0
    public var health: Int = 3
    public var maxHealth: Int = 3

    // Hitbox (smaller than sprite for forgiving collision)
    public var hitboxSize: CGSize { GameConstants.playerHitboxSize }
    public var hitbox: CGRect {
        CGRect(
            x: position.x - hitboxSize.width / 2,
            y: position.y - hitboxSize.height / 2,
            width: hitboxSize.width,
            height: hitboxSize.height
        )
    }

    // Animation
    private var animationTimer: TimeInterval = 0
    private var animationFrame: Int = 0
    private let walkFrameCount = 4
    private var bounceOffset: CGFloat = 0

    public init() {
        node = SKNode()
        node.name = "player"
        node.zPosition = ZPositions.player

        spriteNode = SKSpriteNode(color: .clear, size: GameConstants.playerSpriteSize)
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.25)
        node.addChild(spriteNode)

        loadTextures()
        updateSprite()
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval, input: InputState, collisionSystem: CollisionSystem) {
        let movement = input.movement
        isMoving = movement.length > 0.1

        if isMoving {
            updateDirection(from: movement)

            let speed = GameConstants.playerSpeed
            let delta = CGPoint(
                x: movement.x * speed * CGFloat(deltaTime),
                y: movement.y * speed * CGFloat(deltaTime)
            )

            let newPos = collisionSystem.resolveMovement(
                currentPosition: position,
                hitboxSize: hitboxSize,
                delta: delta
            )
            position = newPos

            animationTimer += deltaTime
            if animationTimer >= GameConstants.walkAnimationFrameDuration {
                animationTimer = 0
                animationFrame = (animationFrame + 1) % walkFrameCount
                updateSprite()
            }

            // Walking bounce
            bounceOffset = sin(CGFloat(animationFrame) * .pi / 2) * 2
            spriteNode.position.y = bounceOffset
        } else {
            if animationFrame != 0 {
                animationFrame = 0
                animationTimer = 0
                updateSprite()
            }
            spriteNode.position.y = 0
            bounceOffset = 0
        }
    }

    // MARK: - Direction

    private func updateDirection(from movement: CGPoint) {
        if abs(movement.x) > abs(movement.y) {
            direction = movement.x > 0 ? .right : .left
        } else {
            direction = movement.y > 0 ? .up : .down
        }
    }

    // MARK: - Interaction

    public var facingPosition: CGPoint {
        let offset: CGPoint
        switch direction {
        case .up: offset = CGPoint(x: 0, y: GameConstants.interactionRange)
        case .down: offset = CGPoint(x: 0, y: -GameConstants.interactionRange)
        case .left: offset = CGPoint(x: -GameConstants.interactionRange, y: 0)
        case .right: offset = CGPoint(x: GameConstants.interactionRange, y: 0)
        }
        return position + offset
    }

    public var facingTile: (col: Int, row: Int) {
        CollisionSystem.facingTile(position: position, direction: direction)
    }

    // MARK: - XP & Leveling

    public func addXP(_ amount: Int) {
        totalXP += amount
        let newLevel = (totalXP / GameConstants.xpPerLevel) + 1
        if newLevel > level {
            level = newLevel
        }
    }

    public var xpForCurrentLevel: Int {
        totalXP % GameConstants.xpPerLevel
    }

    public var xpProgressFraction: CGFloat {
        CGFloat(xpForCurrentLevel) / CGFloat(GameConstants.xpPerLevel)
    }

    // MARK: - Sprite Rendering (Texture-based)

    /// Pre-loaded textures for each direction
    private var directionTextures: [Direction: SKTexture] = [:]

    private func loadTextures() {
        let mapping: [Direction: String] = [
            .down:  "player_down",
            .up:    "player_up",
            .left:  "player_left",
            .right: "player_right"
        ]
        for (dir, name) in mapping {
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .nearest  // preserve pixel-art crispness
            directionTextures[dir] = tex
        }
    }

    private func updateSprite() {
        spriteNode.texture = directionTextures[direction]
        spriteNode.size = GameConstants.playerSpriteSize
    }
}
