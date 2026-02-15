import Foundation
import CoreGraphics

// MARK: - Collision Layer

/// A 2D grid of booleans representing solid/passable tiles
public struct CollisionLayer {
    public let width: Int
    public let height: Int
    private var grid: [Bool]  // true = solid

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
        self.grid = Array(repeating: false, count: width * height)
    }

    public init(from data: [[Int]]) {
        self.height = data.count
        self.width = data.first?.count ?? 0
        self.grid = Array(repeating: false, count: width * height)

        for row in 0..<height {
            for col in 0..<min(width, data[row].count) {
                // In SpriteKit, Y is up, so we flip rows
                let flippedRow = height - 1 - row
                grid[flippedRow * width + col] = data[row][col] != 0
            }
        }
    }

    public func isSolid(col: Int, row: Int) -> Bool {
        guard col >= 0, col < width, row >= 0, row < height else { return true }
        return grid[row * width + col]
    }

    public mutating func setSolid(col: Int, row: Int, solid: Bool) {
        guard col >= 0, col < width, row >= 0, row < height else { return }
        grid[row * width + col] = solid
    }
}

// MARK: - Collision System

public final class CollisionSystem {
    public var collisionLayer: CollisionLayer?

    public init() {}

    // MARK: - Tile Collision

    /// Check if a world-space rect overlaps any solid tile
    public func collidesWithTiles(rect: CGRect) -> Bool {
        guard let layer = collisionLayer else { return false }

        let tileSize = GameConstants.tileSize
        let minCol = max(0, Int(rect.minX / tileSize))
        let maxCol = min(layer.width - 1, Int(rect.maxX / tileSize))
        let minRow = max(0, Int(rect.minY / tileSize))
        let maxRow = min(layer.height - 1, Int(rect.maxY / tileSize))

        // If player rect is entirely outside the grid, treat as collision
        guard minCol <= maxCol, minRow <= maxRow else { return true }

        for row in minRow...maxRow {
            for col in minCol...maxCol {
                if layer.isSolid(col: col, row: row) {
                    return true
                }
            }
        }
        return false
    }

    /// Check if a specific tile coordinate is solid
    public func isTileSolid(col: Int, row: Int) -> Bool {
        collisionLayer?.isSolid(col: col, row: row) ?? true
    }

    // MARK: - Entity Collision

    /// AABB overlap test
    public static func overlaps(_ a: CGRect, _ b: CGRect) -> Bool {
        a.intersects(b)
    }

    // MARK: - Movement Resolution

    /// Attempt to move a hitbox by a delta, resolving tile collisions.
    /// Returns the allowed new position. Uses wall-sliding for smooth movement.
    public func resolveMovement(
        currentPosition: CGPoint,
        hitboxSize: CGSize,
        delta: CGPoint
    ) -> CGPoint {
        guard collisionLayer != nil else {
            return CGPoint(x: currentPosition.x + delta.x, y: currentPosition.y + delta.y)
        }

        let halfW = hitboxSize.width / 2
        let halfH = hitboxSize.height / 2

        // Try full movement
        let fullTarget = CGPoint(x: currentPosition.x + delta.x, y: currentPosition.y + delta.y)
        let fullRect = CGRect(
            x: fullTarget.x - halfW,
            y: fullTarget.y - halfH,
            width: hitboxSize.width,
            height: hitboxSize.height
        )

        if !collidesWithTiles(rect: fullRect) {
            return fullTarget
        }

        // Try X only (wall-slide vertical)
        let xTarget = CGPoint(x: currentPosition.x + delta.x, y: currentPosition.y)
        let xRect = CGRect(
            x: xTarget.x - halfW,
            y: xTarget.y - halfH,
            width: hitboxSize.width,
            height: hitboxSize.height
        )

        var result = currentPosition

        if !collidesWithTiles(rect: xRect) {
            result.x = xTarget.x
        }

        // Try Y only (wall-slide horizontal)
        let yTarget = CGPoint(x: result.x, y: currentPosition.y + delta.y)
        let yRect = CGRect(
            x: yTarget.x - halfW,
            y: yTarget.y - halfH,
            width: hitboxSize.width,
            height: hitboxSize.height
        )

        if !collidesWithTiles(rect: yRect) {
            result.y = yTarget.y
        }

        return result
    }

    // MARK: - Facing Tile Query

    /// Get the tile coordinate the entity is facing
    public static func facingTile(
        position: CGPoint,
        direction: Direction
    ) -> (col: Int, row: Int) {
        let offset: CGPoint
        switch direction {
        case .up: offset = CGPoint(x: 0, y: GameConstants.tileSize)
        case .down: offset = CGPoint(x: 0, y: -GameConstants.tileSize)
        case .left: offset = CGPoint(x: -GameConstants.tileSize, y: 0)
        case .right: offset = CGPoint(x: GameConstants.tileSize, y: 0)
        }

        let facingPoint = CGPoint(
            x: position.x + offset.x,
            y: position.y + offset.y
        )
        return facingPoint.toTileCoord()
    }
}
