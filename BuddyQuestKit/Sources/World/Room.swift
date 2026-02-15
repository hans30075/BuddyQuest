import Foundation
import SpriteKit

// MARK: - Tile Type

public enum TileType: Int, Codable {
    case empty = 0
    case grass = 1
    case path = 2
    case water = 3
    case wall = 4
    case floor = 5
    case woodFloor = 6
    case stoneFloor = 7
    case dirt = 8
    case sand = 9
    case snow = 10
    case labFloor = 11
    case bookshelf = 12
    case table = 13
    case tree = 14
    case flower = 15
    case rock = 16
    case crystal = 17
    case portal = 18
    case sign = 19
    case chest = 20

    public var isSolid: Bool {
        switch self {
        case .wall, .water, .bookshelf, .table, .tree, .rock, .portal:
            return true
        default:
            return false
        }
    }

    public var color: SKColor {
        switch self {
        case .empty: return .clear
        case .grass: return SKColor(red: 0.45, green: 0.75, blue: 0.35, alpha: 1)
        case .path: return SKColor(red: 0.75, green: 0.65, blue: 0.45, alpha: 1)
        case .water: return SKColor(red: 0.3, green: 0.55, blue: 0.85, alpha: 1)
        case .wall: return SKColor(red: 0.45, green: 0.4, blue: 0.35, alpha: 1)
        case .floor: return SKColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1)
        case .woodFloor: return SKColor(red: 0.65, green: 0.45, blue: 0.25, alpha: 1)
        case .stoneFloor: return SKColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
        case .dirt: return SKColor(red: 0.55, green: 0.4, blue: 0.25, alpha: 1)
        case .sand: return SKColor(red: 0.95, green: 0.9, blue: 0.65, alpha: 1)
        case .snow: return SKColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1)
        case .labFloor: return SKColor(red: 0.85, green: 0.85, blue: 0.9, alpha: 1)
        case .bookshelf: return SKColor(red: 0.5, green: 0.3, blue: 0.15, alpha: 1)
        case .table: return SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        case .tree: return SKColor(red: 0.2, green: 0.55, blue: 0.2, alpha: 1)
        case .flower: return SKColor(red: 0.95, green: 0.5, blue: 0.6, alpha: 1)
        case .rock: return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        case .crystal: return SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        case .portal: return SKColor(red: 0.7, green: 0.4, blue: 0.95, alpha: 1)
        case .sign: return SKColor(red: 0.7, green: 0.55, blue: 0.3, alpha: 1)
        case .chest: return SKColor(red: 0.8, green: 0.65, blue: 0.2, alpha: 1)
        }
    }

    /// PNG filename (without extension) for this tile type, or nil if no art asset exists yet
    public var textureName: String? {
        switch self {
        case .empty: return nil
        case .grass: return "tile_grass"
        case .path: return "tile_path_dirt"   // stone path has transparent bg, use dirt instead
        case .water: return "tile_water"
        case .wall: return "tile_wall_stone"
        case .floor: return "tile_stone_floor"
        case .woodFloor: return "tile_wood_floor"
        case .stoneFloor: return "tile_stone_floor"
        case .dirt: return "tile_path_dirt"
        case .sand: return "tile_sand"
        case .snow: return "tile_snow"
        case .labFloor: return "tile_lab_floor"
        case .bookshelf: return "tile_bookshelf"
        case .table: return "tile_table_wooden"
        case .tree: return "tile_tree_oka"
        case .flower: return "tile_grass_flower"
        case .rock: return "tile_rock_large"
        case .crystal: return "tile_crystal"
        case .portal: return "tile_portal"
        case .sign: return "tile_sign"
        case .chest: return "tile_chest_closed"
        }
    }
}

// MARK: - Door Definition

public struct DoorDefinition {
    public let id: String
    public let position: (col: Int, row: Int)
    public let targetRoomId: String
    public let targetZoneId: String?
    public let spawnPosition: (col: Int, row: Int)
    public let requiredFlag: String?
    public let requiredLevel: Int?
    public let lockedMessage: String?
    /// Display name shown as a floating label above the door (e.g. "Word Forest")
    public let label: String?

    public init(
        id: String,
        position: (col: Int, row: Int),
        targetRoomId: String,
        targetZoneId: String? = nil,
        spawnPosition: (col: Int, row: Int),
        requiredFlag: String? = nil,
        requiredLevel: Int? = nil,
        lockedMessage: String? = nil,
        label: String? = nil
    ) {
        self.id = id
        self.position = position
        self.targetRoomId = targetRoomId
        self.targetZoneId = targetZoneId
        self.spawnPosition = spawnPosition
        self.requiredFlag = requiredFlag
        self.requiredLevel = requiredLevel
        self.lockedMessage = lockedMessage
        self.label = label
    }
}

// MARK: - NPC Spawn Definition

public struct NPCSpawnDefinition {
    public let id: String
    public let name: String
    public let position: (col: Int, row: Int)
    public let dialogueId: String?
    public let patrolPath: [(col: Int, row: Int)]?
    /// If true, this NPC triggers a challenge after dialogue completes
    public let givesChallenge: Bool

    public init(
        id: String,
        name: String,
        position: (col: Int, row: Int),
        dialogueId: String? = nil,
        patrolPath: [(col: Int, row: Int)]? = nil,
        givesChallenge: Bool = false
    ) {
        self.id = id
        self.name = name
        self.position = position
        self.dialogueId = dialogueId
        self.patrolPath = patrolPath
        self.givesChallenge = givesChallenge
    }
}

// MARK: - Room

public final class Room {
    public let id: String
    public let name: String
    public let width: Int   // In tiles
    public let height: Int  // In tiles

    public let floorLayer: [[TileType]]
    public let wallLayer: [[TileType]]
    public let decorationLayer: [[TileType]]

    public let doors: [DoorDefinition]
    public let npcSpawns: [NPCSpawnDefinition]
    public let playerSpawn: (col: Int, row: Int)

    public let musicTrack: String?

    public var onEnter: (() -> Void)?
    public var onUpdate: ((TimeInterval) -> Void)?

    public var widthPx: CGFloat { CGFloat(width) * GameConstants.tileSize }
    public var heightPx: CGFloat { CGFloat(height) * GameConstants.tileSize }

    public init(
        id: String,
        name: String,
        width: Int,
        height: Int,
        floorLayer: [[TileType]],
        wallLayer: [[TileType]],
        decorationLayer: [[TileType]] = [],
        doors: [DoorDefinition] = [],
        npcSpawns: [NPCSpawnDefinition] = [],
        playerSpawn: (col: Int, row: Int) = (7, 5),
        musicTrack: String? = nil,
        onEnter: (() -> Void)? = nil,
        onUpdate: ((TimeInterval) -> Void)? = nil
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.floorLayer = floorLayer
        self.wallLayer = wallLayer
        self.decorationLayer = decorationLayer
        self.doors = doors
        self.npcSpawns = npcSpawns
        self.playerSpawn = playerSpawn
        self.musicTrack = musicTrack
        self.onEnter = onEnter
        self.onUpdate = onUpdate
    }

    /// Set of door positions (in data-space) for quick lookup
    private lazy var doorPositionSet: Set<String> = {
        Set(doors.map { "\($0.position.col),\($0.position.row)" })
    }()

    /// Build a CollisionLayer from the wall layer.
    /// Door tiles are made passable so the player can walk through them.
    public func buildCollisionLayer() -> CollisionLayer {
        var layer = CollisionLayer(width: width, height: height)
        let doorPositions = Set(doors.map { "\($0.position.col),\($0.position.row)" })

        for row in 0..<min(height, wallLayer.count) {
            for col in 0..<min(width, wallLayer[row].count) {
                let flippedRow = height - 1 - row
                if wallLayer[row][col].isSolid {
                    // Skip making door tiles solid — player walks through doors
                    let key = "\(col),\(row)"
                    if doorPositions.contains(key) {
                        continue
                    }
                    layer.setSolid(col: col, row: flippedRow, solid: true)
                }
            }
        }
        return layer
    }

    /// Get door at a tile coordinate
    public func door(at col: Int, row: Int) -> DoorDefinition? {
        doors.first { $0.position.col == col && $0.position.row == row }
    }
}

// MARK: - Tile Map Node Builder

public enum TileMapBuilder {
    /// Texture cache — each PNG loaded once, reused for all tiles of that type
    private static var textureCache: [String: SKTexture] = [:]

    private static func cachedTexture(named name: String) -> SKTexture {
        if let cached = textureCache[name] {
            return cached
        }
        let tex = SKTexture(imageNamed: name)
        tex.filteringMode = .nearest  // preserve pixel-art crispness
        textureCache[name] = tex
        return tex
    }

    /// Create SpriteKit tile nodes for a room layer
    public static func buildLayerNode(
        tiles: [[TileType]],
        width: Int,
        height: Int,
        zPosition: CGFloat
    ) -> SKNode {
        let layerNode = SKNode()
        layerNode.zPosition = zPosition

        let tileSize = GameConstants.tileSize
        let spriteSize = CGSize(width: tileSize, height: tileSize)

        for row in 0..<min(height, tiles.count) {
            for col in 0..<min(width, tiles[row].count) {
                let tileType = tiles[row][col]
                guard tileType != .empty else { continue }

                let sprite: SKSpriteNode
                if let texName = tileType.textureName {
                    sprite = SKSpriteNode(texture: cachedTexture(named: texName), size: spriteSize)
                } else {
                    sprite = SKSpriteNode(color: tileType.color, size: spriteSize)
                }

                // SpriteKit Y is up, tile data Y is down
                let flippedRow = height - 1 - row
                sprite.position = CGPoint(
                    x: CGFloat(col) * tileSize + tileSize / 2,
                    y: CGFloat(flippedRow) * tileSize + tileSize / 2
                )
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0.5)

                layerNode.addChild(sprite)
            }
        }

        return layerNode
    }
}
