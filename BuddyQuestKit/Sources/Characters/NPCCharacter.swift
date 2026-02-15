import Foundation
import SpriteKit

/// An NPC entity in the world that the player can interact with.
/// NPCs use a shared pixel-art sprite tinted with a per-NPC color,
/// a floating name label, and optionally face toward the player when nearby.
public final class NPCCharacter {
    public let id: String
    public let npcName: String
    public let dialogueId: String?
    public let givesChallenge: Bool
    public let node: SKNode
    public let spriteNode: SKSpriteNode

    public var position: CGPoint {
        get { node.position }
        set { node.position = newValue }
    }

    public private(set) var direction: Direction = .down

    // Name label floating above NPC
    private let nameLabel: SKLabelNode

    // Quest marker (! or ?) floating above name
    private var questMarker: SKLabelNode?

    // Interaction radius in points
    public let interactionRadius: CGFloat = 52

    // Patrol (optional)
    public let patrolPath: [(col: Int, row: Int)]?
    private var patrolIndex: Int = 0
    private var patrolWaitTimer: TimeInterval = 0
    private let patrolWaitDuration: TimeInterval = 2.0
    private var isPatrolWaiting: Bool = true

    // MARK: - Shared Texture Cache

    /// Direction-based textures shared across all NPC instances (loaded once)
    private static var directionTextures: [Direction: SKTexture] = [:]
    private static var texturesLoaded = false

    private static func loadNPCTextures() {
        guard !texturesLoaded else { return }
        let mapping: [Direction: String] = [
            .down:  "npc_down",
            .up:    "npc_up",
            .left:  "npc_left",
            .right: "npc_right"
        ]
        for (dir, name) in mapping {
            let tex = SKTexture(imageNamed: name)
            tex.filteringMode = .nearest  // preserve pixel-art crispness
            directionTextures[dir] = tex
        }
        texturesLoaded = true
    }

    public init(definition: NPCSpawnDefinition, roomHeight: Int) {
        self.id = definition.id
        self.npcName = definition.name
        self.dialogueId = definition.dialogueId
        self.givesChallenge = definition.givesChallenge
        self.patrolPath = definition.patrolPath

        node = SKNode()
        node.name = "npc_\(definition.id)"
        node.zPosition = ZPositions.entities

        // Load shared NPC textures (once for all NPCs)
        Self.loadNPCTextures()

        // NPC sprite — pixel-art texture with per-NPC color tint
        let size = GameConstants.playerSpriteSize
        spriteNode = SKSpriteNode(
            texture: Self.directionTextures[.down],
            size: size
        )
        spriteNode.anchorPoint = CGPoint(x: 0.5, y: 0.25)
        node.addChild(spriteNode)

        // Apply NPC-specific color tint (0.6 blend preserves art detail while tinting)
        let npcColor = NPCCharacter.colorForNPC(id: definition.id)
        spriteNode.color = npcColor
        spriteNode.colorBlendFactor = 0.6

        // Floating name label
        nameLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        nameLabel.text = definition.name
        nameLabel.fontSize = 9
        nameLabel.fontColor = .white
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.verticalAlignmentMode = .bottom
        nameLabel.position = CGPoint(x: 0, y: 44)

        // Name background pill
        let nameBg = SKShapeNode(rectOf: CGSize(
            width: nameLabel.frame.width + 12,
            height: 16
        ), cornerRadius: 8)
        nameBg.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.7)
        nameBg.strokeColor = .clear
        nameBg.position = CGPoint(x: 0, y: 50)
        node.addChild(nameBg)
        node.addChild(nameLabel)

        // Position in world (convert data-space to SpriteKit)
        let flippedRow = roomHeight - 1 - definition.position.row
        position = CGPoint.fromTileCoord(col: definition.position.col, row: flippedRow)
    }

    // MARK: - Update

    public func update(deltaTime: TimeInterval, playerPosition: CGPoint) {
        // Face toward player when they're nearby
        let dist = position.distance(to: playerPosition)
        if dist < interactionRadius * 2 {
            faceToward(playerPosition)
        }

        // Gentle idle bob
        let time = CACurrentMediaTime()
        spriteNode.position.y = sin(CGFloat(time) * 2.5) * 1.5
    }

    // MARK: - Interaction

    /// Check if the player is close enough to interact
    public func canInteract(playerPosition: CGPoint) -> Bool {
        position.distance(to: playerPosition) < interactionRadius
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
            updateSprite()
        }
    }

    private func updateSprite() {
        spriteNode.texture = Self.directionTextures[direction]
        spriteNode.size = GameConstants.playerSpriteSize
    }

    // MARK: - Quest Markers

    /// Update the quest marker above this NPC.
    /// - `hasQuestToGive`: true if NPC has a quest the player can accept (shows gold !)
    /// - `hasQuestToComplete`: true if NPC can accept a completed quest turn-in (shows green ?)
    public func updateQuestMarker(hasQuestToGive: Bool, hasQuestToComplete: Bool) {
        // Remove existing marker
        questMarker?.removeFromParent()
        questMarker = nil

        let symbol: String
        let color: SKColor

        if hasQuestToComplete {
            symbol = "?"
            color = SKColor(red: 0.3, green: 0.9, blue: 0.3, alpha: 1)  // Green
        } else if hasQuestToGive {
            symbol = "!"
            color = SKColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)  // Gold
        } else {
            return  // No marker needed
        }

        let marker = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        marker.text = symbol
        marker.fontSize = 18
        marker.fontColor = color
        marker.horizontalAlignmentMode = .center
        marker.verticalAlignmentMode = .bottom
        marker.position = CGPoint(x: 0, y: 58)
        marker.zPosition = 10
        node.addChild(marker)
        questMarker = marker

        // Gentle bounce animation
        let bounceUp = SKAction.moveBy(x: 0, y: 4, duration: 0.5)
        bounceUp.timingMode = .easeInEaseOut
        let bounceDown = bounceUp.reversed()
        marker.run(.repeatForever(.sequence([bounceUp, bounceDown])))
    }

    // MARK: - NPC Colors

    private static func colorForNPC(id: String) -> SKColor {
        // Different NPCs get different colors for visual variety
        switch id {
        case "guide_pip":
            return SKColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1)  // Blue
        case "librarian_sage":
            return SKColor(red: 0.6, green: 0.4, blue: 0.8, alpha: 1)  // Purple
        case "forest_sprite":
            return SKColor(red: 0.3, green: 0.8, blue: 0.4, alpha: 1)  // Green
        case "forest_willow":
            return SKColor(red: 0.2, green: 0.7, blue: 0.5, alpha: 1)  // Sage green
        case "forest_guardian":
            return SKColor(red: 0.5, green: 0.35, blue: 0.15, alpha: 1) // Deep brown
        case "rocky_calcinator":
            return SKColor(red: 0.4, green: 0.5, blue: 0.85, alpha: 1) // Mountain blue
        case "peaks_crystal_sage":
            return SKColor(red: 0.5, green: 0.7, blue: 0.95, alpha: 1) // Ice blue
        case "peaks_summit_keeper":
            return SKColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1) // Snow white
        case "professor_atom":
            return SKColor(red: 0.7, green: 0.4, blue: 0.85, alpha: 1) // Lab purple
        case "lab_researcher":
            return SKColor(red: 0.3, green: 0.8, blue: 0.7, alpha: 1)  // Teal
        case "lab_director":
            return SKColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 1)  // Electric orange
        case "coach_unity":
            return SKColor(red: 0.95, green: 0.65, blue: 0.3, alpha: 1) // Warm orange
        case "arena_captain":
            return SKColor(red: 0.85, green: 0.4, blue: 0.4, alpha: 1) // Warm red
        case "arena_champion_npc":
            return SKColor(red: 0.95, green: 0.8, blue: 0.2, alpha: 1) // Gold
        default:
            return SKColor(red: 0.5, green: 0.5, blue: 0.7, alpha: 1)  // Default gray-blue
        }
    }
}
