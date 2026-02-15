import Foundation
import SpriteKit

/// Manages zones, rooms, room loading, and transitions
public final class WorldManager {
    private var zones: [String: Zone] = [:]
    public private(set) var currentZoneId: String?
    public private(set) var currentRoomId: String?
    public private(set) var currentRoom: Room?

    /// The node that holds all room content (tile layers, entities)
    public let worldNode: SKNode

    // Layer nodes for the current room
    private var floorLayerNode: SKNode?
    private var wallLayerNode: SKNode?
    private var decorationLayerNode: SKNode?
    private var doorLabelsNode: SKNode?

    // NPC management
    public private(set) var npcs: [NPCCharacter] = []

    // References to game systems
    private weak var collisionSystem: CollisionSystem?
    private weak var cameraController: CameraController?
    private weak var player: PlayerCharacter?

    // Transition state
    public private(set) var isTransitioning: Bool = false

    // Cooldown after being pushed back from a locked door (prevents stuck-in-portal loop)
    private var lockedDoorCooldown: TimeInterval = 0

    // Callback when a room finishes loading (used for room name banner)
    public var onRoomLoaded: ((Room) -> Void)?

    // Game flags (for door locks, quest progression)
    public var gameFlags: Set<String> = []

    public init() {
        worldNode = SKNode()
        worldNode.name = "world"
    }

    public func configure(
        collisionSystem: CollisionSystem,
        cameraController: CameraController,
        player: PlayerCharacter
    ) {
        self.collisionSystem = collisionSystem
        self.cameraController = cameraController
        self.player = player
    }

    // MARK: - Zone Registration

    public func registerZone(_ zone: Zone) {
        zones[zone.id] = zone
    }

    public func zone(withId id: String) -> Zone? {
        zones[id]
    }

    public var allZones: [Zone] {
        Array(zones.values)
    }

    // MARK: - Room Loading

    /// Load a room by zone and room ID. Sets up tiles, collision, camera, and player position.
    public func loadRoom(
        zoneId: String,
        roomId: String,
        spawnCol: Int? = nil,
        spawnRow: Int? = nil,
        scene: SKScene
    ) {
        guard let zone = zones[zoneId] else {
            print("[WorldManager] Zone '\(zoneId)' not found")
            return
        }

        guard let room = zone.createRoom(id: roomId) else {
            print("[WorldManager] Room '\(roomId)' not found in zone '\(zoneId)'")
            return
        }

        // Clear previous room content
        clearCurrentRoom()

        // Store references
        currentZoneId = zoneId
        currentRoomId = roomId
        currentRoom = room

        // Build tile layers
        let floorNode = TileMapBuilder.buildLayerNode(
            tiles: room.floorLayer,
            width: room.width,
            height: room.height,
            zPosition: ZPositions.floor
        )
        worldNode.addChild(floorNode)
        floorLayerNode = floorNode

        let wallNode = TileMapBuilder.buildLayerNode(
            tiles: room.wallLayer,
            width: room.width,
            height: room.height,
            zPosition: ZPositions.walls
        )
        worldNode.addChild(wallNode)
        wallLayerNode = wallNode

        if !room.decorationLayer.isEmpty {
            let decoNode = TileMapBuilder.buildLayerNode(
                tiles: room.decorationLayer,
                width: room.width,
                height: room.height,
                zPosition: ZPositions.decoration
            )
            worldNode.addChild(decoNode)
            decorationLayerNode = decoNode
        }

        // Build door labels
        let labelsNode = buildDoorLabels(for: room)
        worldNode.addChild(labelsNode)
        doorLabelsNode = labelsNode

        // Spawn NPCs
        spawnNPCs(for: room)

        // Set up collision
        let collisionLayer = room.buildCollisionLayer()
        collisionSystem?.collisionLayer = collisionLayer

        // Set up camera bounds
        cameraController?.setRoomBounds(width: room.widthPx, height: room.heightPx)

        // Position player
        let spawnC = spawnCol ?? room.playerSpawn.col
        let spawnR = spawnRow ?? room.playerSpawn.row
        let spawnPos = CGPoint.fromTileCoord(
            col: spawnC,
            row: room.height - 1 - spawnR  // Flip Y for SpriteKit
        )
        player?.position = spawnPos

        // Snap camera immediately
        cameraController?.snapToTarget()

        // Fire room enter callback
        room.onEnter?()

        // Notify listener (GameEngine uses this for room name banner)
        onRoomLoaded?(room)
    }

    // MARK: - Room Transitions

    /// Transition to a new room with fade effect
    public func transitionToRoom(
        zoneId: String,
        roomId: String,
        spawnCol: Int,
        spawnRow: Int,
        scene: SKScene,
        completion: (() -> Void)? = nil
    ) {
        guard !isTransitioning else { return }
        isTransitioning = true

        // Create fade overlay (double the scene size to be safe with scaling)
        let fadeNode = SKShapeNode(rectOf: CGSize(width: scene.size.width * 2, height: scene.size.height * 2))
        fadeNode.fillColor = .black
        fadeNode.strokeColor = .clear
        fadeNode.alpha = 0
        fadeNode.zPosition = ZPositions.transition
        fadeNode.position = .zero  // Centered on camera
        if let camera = cameraController?.cameraNode {
            camera.addChild(fadeNode)
        }

        let duration = GameConstants.fadeTransitionDuration

        // Fade out
        fadeNode.run(.fadeAlpha(to: 1.0, duration: duration)) { [weak self] in
            guard let self = self else { return }

            // Load new room
            self.loadRoom(
                zoneId: zoneId,
                roomId: roomId,
                spawnCol: spawnCol,
                spawnRow: spawnRow,
                scene: scene
            )

            // Fade in
            fadeNode.run(.fadeAlpha(to: 0, duration: duration)) { [weak self] in
                fadeNode.removeFromParent()
                self?.isTransitioning = false
                completion?()
            }
        }
    }

    /// Try to use a door at the player's facing position
    public func tryUseDoor(scene: SKScene) -> Bool {
        guard let room = currentRoom, let player = player else { return false }

        // facingTile returns SpriteKit coords (row 0 = bottom)
        let facing = player.facingTile
        // Door positions are stored in data-space (row 0 = top), so convert
        let dataRow = room.height - 1 - facing.row
        guard let door = room.door(at: facing.col, row: dataRow) else { return false }

        // Check lock conditions
        if let requiredFlag = door.requiredFlag, !gameFlags.contains(requiredFlag) {
            showLockedMessage(door.lockedMessage ?? "This path is locked.")
            return true
        }

        if let requiredLevel = door.requiredLevel, player.level < requiredLevel {
            showLockedMessage(door.lockedMessage ?? "You need to reach level \(requiredLevel).")
            return true
        }

        // Safety: check target zone and room exist before transitioning
        let targetZoneId = door.targetZoneId ?? currentZoneId ?? ""
        guard let targetZone = zones[targetZoneId] else {
            showLockedMessage("This area is coming soon!")
            return true
        }
        guard targetZone.createRoom(id: door.targetRoomId) != nil else {
            showLockedMessage("This area is coming soon!")
            return true
        }

        // Transition
        transitionToRoom(
            zoneId: targetZoneId,
            roomId: door.targetRoomId,
            spawnCol: door.spawnPosition.col,
            spawnRow: door.spawnPosition.row,
            scene: scene
        )

        return true
    }

    /// Show a temporary floating message (for locked doors, etc.)
    private func showLockedMessage(_ text: String) {
        guard let camera = cameraController?.cameraNode else { return }
        camera.childNode(withName: "lockedMsg")?.removeFromParent()

        // Measure text to size the background
        let tempLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        tempLabel.text = "🔒 \(text)"
        tempLabel.fontSize = 14
        let bgWidth = max(tempLabel.frame.width + 40, 300)

        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: 50), cornerRadius: 14)
        bg.name = "lockedMsg"
        bg.fillColor = SKColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 0.92)
        bg.strokeColor = SKColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)
        bg.lineWidth = 2
        bg.position = CGPoint(x: 0, y: -220)
        bg.zPosition = ZPositions.hud + 10

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text = "🔒 \(text)"
        label.fontSize = 14
        label.fontColor = SKColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1)
        label.verticalAlignmentMode = .center
        bg.addChild(label)

        camera.addChild(bg)
        bg.run(.sequence([
            .wait(forDuration: 3.0),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
    }

    // MARK: - Auto Door Detection (walk-through)

    /// Check if the player is standing on a door tile and trigger transition.
    /// Returns true if a door was triggered.
    public func checkPlayerOnDoor(scene: SKScene) -> Bool {
        guard let room = currentRoom, let player = player else { return false }
        guard !isTransitioning else { return false }
        guard lockedDoorCooldown <= 0 else { return false }

        // Get player's current tile in SpriteKit coords (row 0 = bottom)
        let tileCoord = player.position.toTileCoord()
        // Convert to data-space (row 0 = top) for door lookup
        let dataRow = room.height - 1 - tileCoord.row

        guard let door = room.door(at: tileCoord.col, row: dataRow) else { return false }

        // Check lock conditions
        if let requiredFlag = door.requiredFlag, !gameFlags.contains(requiredFlag) {
            showLockedMessage(door.lockedMessage ?? "This path is locked.")
            // Push player back slightly so they don't keep triggering the message
            pushPlayerBack(from: tileCoord, in: room)
            return true
        }

        if let requiredLevel = door.requiredLevel, player.level < requiredLevel {
            showLockedMessage(door.lockedMessage ?? "You need to reach level \(requiredLevel).")
            pushPlayerBack(from: tileCoord, in: room)
            return true
        }

        // Safety: check target zone and room exist before transitioning
        let targetZoneId = door.targetZoneId ?? currentZoneId ?? ""
        guard let targetZone = zones[targetZoneId] else {
            showLockedMessage("This area is coming soon!")
            pushPlayerBack(from: tileCoord, in: room)
            return true
        }
        guard targetZone.createRoom(id: door.targetRoomId) != nil else {
            showLockedMessage("This area is coming soon!")
            pushPlayerBack(from: tileCoord, in: room)
            return true
        }

        // Transition!
        transitionToRoom(
            zoneId: targetZoneId,
            roomId: door.targetRoomId,
            spawnCol: door.spawnPosition.col,
            spawnRow: door.spawnPosition.row,
            scene: scene
        )

        return true
    }

    /// Push the player two tiles back from a locked door and start a cooldown
    /// so the door check doesn't re-trigger while the player walks away.
    private func pushPlayerBack(from tileCoord: (col: Int, row: Int), in room: Room) {
        guard let player = player else { return }
        let tileSize = GameConstants.tileSize

        // Find the center of a safe tile two steps back from the door
        let doorDataRow = room.height - 1 - tileCoord.row
        let safeRow: Int
        let safeCol: Int

        // Determine push direction based on door position (edge detection)
        if doorDataRow == 0 {
            // Top edge door — push player down (SpriteKit: decrease row)
            safeRow = tileCoord.row - 2
            safeCol = tileCoord.col
        } else if doorDataRow == room.height - 1 {
            // Bottom edge door — push player up
            safeRow = tileCoord.row + 2
            safeCol = tileCoord.col
        } else if tileCoord.col == 0 {
            // Left edge door — push player right
            safeRow = tileCoord.row
            safeCol = tileCoord.col + 2
        } else if tileCoord.col == room.width - 1 {
            // Right edge door — push player left
            safeRow = tileCoord.row
            safeCol = tileCoord.col - 2
        } else {
            // Interior door — push based on player direction
            safeRow = tileCoord.row
            safeCol = tileCoord.col
            return
        }

        // Clamp to room bounds (stay at least 1 tile from edges)
        let clampedCol = max(1, min(room.width - 2, safeCol))
        let clampedRow = max(1, min(room.height - 2, safeRow))

        player.position = CGPoint(
            x: CGFloat(clampedCol) * tileSize + tileSize / 2,
            y: CGFloat(clampedRow) * tileSize + tileSize / 2
        )

        // Set cooldown so door detection pauses briefly, giving the player time to move away
        lockedDoorCooldown = 0.6
    }

    // MARK: - Helpers

    private func clearCurrentRoom() {
        floorLayerNode?.removeFromParent()
        wallLayerNode?.removeFromParent()
        decorationLayerNode?.removeFromParent()
        doorLabelsNode?.removeFromParent()
        floorLayerNode = nil
        wallLayerNode = nil
        decorationLayerNode = nil
        doorLabelsNode = nil

        // Remove NPCs
        for npc in npcs {
            npc.node.removeFromParent()
        }
        npcs.removeAll()
    }

    // MARK: - NPC Management

    private func spawnNPCs(for room: Room) {
        for definition in room.npcSpawns {
            let npc = NPCCharacter(definition: definition, roomHeight: room.height)
            worldNode.addChild(npc.node)
            npcs.append(npc)
        }
    }

    /// Update quest markers on all NPCs in the current room
    public func updateNPCQuestMarkers(questSystem: QuestSystem, playerLevel: Int) {
        for npc in npcs {
            let hasGive = questSystem.npcHasQuestToGive(npc.id, playerLevel: playerLevel, flags: gameFlags)
            let hasComplete = questSystem.npcHasQuestToComplete(npc.id)
            npc.updateQuestMarker(hasQuestToGive: hasGive, hasQuestToComplete: hasComplete)
        }
    }

    /// Find the nearest NPC that the player can interact with (within range)
    public func nearestInteractableNPC() -> NPCCharacter? {
        guard let playerPos = player?.position else { return nil }
        var closest: NPCCharacter?
        var closestDist: CGFloat = .greatestFiniteMagnitude

        for npc in npcs {
            if npc.canInteract(playerPosition: playerPos) {
                let dist = npc.position.distance(to: playerPos)
                if dist < closestDist {
                    closestDist = dist
                    closest = npc
                }
            }
        }
        return closest
    }

    /// Create floating labels above doors that have a label property.
    /// Labels start hidden and fade in when the player is within proximity.
    /// Multi-tile doors with the same label are merged into a single label.
    /// Locked doors show a 🔒 icon and hint text about how to unlock.
    /// Nearby labels on the same edge are spread apart to avoid overlapping text.
    private func buildDoorLabels(for room: Room) -> SKNode {
        let container = SKNode()
        container.zPosition = ZPositions.hud - 10  // Above walls, below HUD
        let tileSize = GameConstants.tileSize

        struct LabelInfo {
            var doorX: CGFloat      // Average door world X (for proximity)
            var doorY: CGFloat      // Average door world Y (for proximity)
            var labelX: CGFloat     // Offset label position X
            var labelY: CGFloat     // Offset label position Y
            let text: String
            let pillWidth: CGFloat
            var tileCount: Int      // How many door tiles share this label
            let isLocked: Bool      // Whether the door is currently locked
            let requiredFlag: String?  // Game flag needed to unlock
        }

        // --- Pass 0: merge multi-tile doors with the same label ---
        struct DoorGroupKey: Hashable {
            let label: String
            let targetRoomId: String
        }
        struct DoorGroupInfo {
            var positions: [(col: Int, row: Int)] = []
            var requiredFlag: String?
            var requiredLevel: Int?
        }
        var grouped: [DoorGroupKey: DoorGroupInfo] = [:]
        for door in room.doors {
            guard let labelText = door.label else { continue }
            let key = DoorGroupKey(label: labelText, targetRoomId: door.targetRoomId)
            var info = grouped[key] ?? DoorGroupInfo()
            info.positions.append(door.position)
            if info.requiredFlag == nil { info.requiredFlag = door.requiredFlag }
            if info.requiredLevel == nil { info.requiredLevel = door.requiredLevel }
            grouped[key] = info
        }

        // --- Pass 1: compute label positions from merged groups ---
        var labels: [LabelInfo] = []

        for (key, groupInfo) in grouped {
            let positions = groupInfo.positions
            let avgCol = CGFloat(positions.map(\.col).reduce(0, +)) / CGFloat(positions.count)
            let avgDataRow = CGFloat(positions.map(\.row).reduce(0, +)) / CGFloat(positions.count)
            let avgFlippedRow = CGFloat(room.height - 1) - avgDataRow

            let doorWorldX = avgCol * tileSize + tileSize / 2
            let doorWorldY = avgFlippedRow * tileSize + tileSize / 2

            let refRow = positions[0].row
            let refCol = positions[0].col
            var offsetX: CGFloat = 0
            var offsetY: CGFloat = 0
            if refRow == 0 {
                offsetY = -tileSize * 0.9
            } else if refRow == room.height - 1 {
                offsetY = tileSize * 0.9
            } else if refCol == 0 {
                offsetX = tileSize * 1.2
            } else if refCol == room.width - 1 {
                offsetX = -tileSize * 1.2
            } else {
                offsetY = tileSize * 0.7
            }

            // Determine lock status
            let playerLevel = player?.level ?? 1
            var isLocked = false
            if let flag = groupInfo.requiredFlag, !gameFlags.contains(flag) {
                isLocked = true
            }
            if let level = groupInfo.requiredLevel, playerLevel < level {
                isLocked = true
            }

            // Measure text width — include lock icon for locked doors
            let displayText = isLocked ? "🔒 \(key.label)" : key.label
            let tempLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            tempLabel.text = displayText
            tempLabel.fontSize = 11
            let padding: CGFloat = 12
            let pillWidth = max(tempLabel.frame.width + padding * 2, 80)

            labels.append(LabelInfo(
                doorX: doorWorldX,
                doorY: doorWorldY,
                labelX: doorWorldX + offsetX,
                labelY: doorWorldY + offsetY,
                text: key.label,
                pillWidth: pillWidth,
                tileCount: positions.count,
                isLocked: isLocked,
                requiredFlag: groupInfo.requiredFlag
            ))
        }

        // --- Pass 2: spread apart labels that are too close on the same edge ---
        for i in 0..<labels.count {
            for j in (i+1)..<labels.count {
                guard abs(labels[i].labelY - labels[j].labelY) < tileSize * 0.5 else { continue }

                let halfI = labels[i].pillWidth / 2
                let halfJ = labels[j].pillWidth / 2
                let gap: CGFloat = 10
                let minDist = halfI + halfJ + gap

                let currentDist = abs(labels[i].labelX - labels[j].labelX)
                if currentDist < minDist {
                    let overlap = minDist - currentDist
                    let shift = overlap / 2
                    if labels[i].labelX < labels[j].labelX {
                        labels[i].labelX -= shift
                        labels[j].labelX += shift
                    } else {
                        labels[i].labelX += shift
                        labels[j].labelX -= shift
                    }
                }
            }
        }

        for i in 0..<labels.count {
            for j in (i+1)..<labels.count {
                guard abs(labels[i].labelX - labels[j].labelX) < tileSize * 0.5 else { continue }
                guard abs(labels[i].labelY - labels[j].labelY) < tileSize * 3 else { continue }

                let pillHeight: CGFloat = 22
                let gap: CGFloat = 10
                let minDist = pillHeight + gap

                let currentDist = abs(labels[i].labelY - labels[j].labelY)
                if currentDist < minDist {
                    let overlap = minDist - currentDist
                    let shift = overlap / 2
                    if labels[i].labelY < labels[j].labelY {
                        labels[i].labelY -= shift
                        labels[j].labelY += shift
                    } else {
                        labels[i].labelY += shift
                        labels[j].labelY -= shift
                    }
                }
            }
        }

        // --- Pass 3: create the actual SpriteKit nodes ---
        for info in labels {
            let displayText = info.isLocked ? "🔒 \(info.text)" : info.text
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = displayText
            label.fontSize = 11
            label.fontColor = info.isLocked ? SKColor(red: 0.9, green: 0.7, blue: 0.5, alpha: 1) : .white
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            label.name = "doorLabelText"

            let pillHeight: CGFloat = 22

            let pill = SKShapeNode(rectOf: CGSize(width: info.pillWidth, height: pillHeight), cornerRadius: pillHeight / 2)
            pill.fillColor = info.isLocked
                ? SKColor(red: 0.15, green: 0.08, blue: 0.05, alpha: 0.85)
                : SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.75)
            pill.strokeColor = info.isLocked
                ? SKColor(red: 0.7, green: 0.4, blue: 0.2, alpha: 0.7)
                : SKColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.6)
            pill.lineWidth = 1
            pill.position = CGPoint(x: info.labelX, y: info.labelY)
            pill.name = "doorLabelPill"

            pill.addChild(label)

            // Store the door's world position and lock info for proximity/update checks
            pill.userData = NSMutableDictionary()
            pill.userData?["doorX"] = info.doorX
            pill.userData?["doorY"] = info.doorY
            pill.userData?["requiredFlag"] = info.requiredFlag
            pill.userData?["labelText"] = info.text
            pill.userData?["isLocked"] = info.isLocked

            pill.alpha = 0

            let floatUp = SKAction.moveBy(x: 0, y: 3, duration: 1.5)
            floatUp.timingMode = .easeInEaseOut
            let floatDown = floatUp.reversed()
            pill.run(.repeatForever(.sequence([floatUp, floatDown])))

            container.addChild(pill)
        }

        return container
    }

    /// Distance in tiles within which door labels become visible
    private let labelProximityTiles: CGFloat = 3.5

    public func update(deltaTime: TimeInterval) {
        currentRoom?.onUpdate?(deltaTime)

        // Tick down locked-door cooldown
        if lockedDoorCooldown > 0 {
            lockedDoorCooldown -= deltaTime
        }

        // Update NPCs
        if let playerPos = player?.position {
            for npc in npcs {
                npc.update(deltaTime: deltaTime, playerPosition: playerPos)
            }
        }

        // Update door label visibility based on player proximity
        updateDoorLabels()
    }

    /// Fade door labels in/out based on player distance.
    /// Also dynamically updates lock status when flags change.
    private func updateDoorLabels() {
        guard let labelsNode = doorLabelsNode, let player = player else { return }

        let proximityPx = labelProximityTiles * GameConstants.tileSize

        for child in labelsNode.children {
            guard let pill = child as? SKShapeNode,
                  let doorX = pill.userData?["doorX"] as? CGFloat,
                  let doorY = pill.userData?["doorY"] as? CGFloat else { continue }

            let dx = player.position.x - doorX
            let dy = player.position.y - doorY
            let distance = sqrt(dx * dx + dy * dy)

            // Target alpha: 1 when close, 0 when far, smooth transition in between
            let targetAlpha: CGFloat
            if distance < proximityPx * 0.6 {
                targetAlpha = 1.0
            } else if distance < proximityPx {
                targetAlpha = 1.0 - (distance - proximityPx * 0.6) / (proximityPx * 0.4)
            } else {
                targetAlpha = 0
            }

            pill.alpha = pill.alpha + (targetAlpha - pill.alpha) * 0.15

            // Dynamically update lock status — if a flag was just unlocked, switch to unlocked style
            if let requiredFlag = pill.userData?["requiredFlag"] as? String,
               let labelText = pill.userData?["labelText"] as? String {
                let wasLocked = pill.name == "doorLabelPill" && (pill.userData?["isLocked"] as? Bool ?? true)
                let isNowUnlocked = gameFlags.contains(requiredFlag)

                if wasLocked && isNowUnlocked {
                    // Transition from locked to unlocked appearance
                    pill.userData?["isLocked"] = false
                    pill.fillColor = SKColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 0.75)
                    pill.strokeColor = SKColor(red: 0.5, green: 0.4, blue: 0.7, alpha: 0.6)
                    // Update text — remove lock icon
                    if let textNode = pill.childNode(withName: "doorLabelText") as? SKLabelNode {
                        textNode.text = labelText
                        textNode.fontColor = .white
                    }
                }
            }
        }
    }
}
