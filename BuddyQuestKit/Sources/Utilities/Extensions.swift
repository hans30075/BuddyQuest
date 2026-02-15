import Foundation
import CoreGraphics
import SpriteKit

// MARK: - CGPoint Extensions

public extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    func lerp(to target: CGPoint, factor: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (target.x - x) * factor,
            y: y + (target.y - y) * factor
        )
    }

    func normalized() -> CGPoint {
        let length = sqrt(x * x + y * y)
        guard length > 0 else { return .zero }
        return CGPoint(x: x / length, y: y / length)
    }

    var length: CGFloat {
        sqrt(x * x + y * y)
    }

    static func + (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }

    static func - (lhs: CGPoint, rhs: CGPoint) -> CGPoint {
        CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y)
    }

    static func * (point: CGPoint, scalar: CGFloat) -> CGPoint {
        CGPoint(x: point.x * scalar, y: point.y * scalar)
    }

    /// Convert world position to tile coordinate
    func toTileCoord() -> (col: Int, row: Int) {
        let col = Int(x / GameConstants.tileSize)
        let row = Int(y / GameConstants.tileSize)
        return (col, row)
    }

    /// Convert tile coordinate to world center position
    static func fromTileCoord(col: Int, row: Int) -> CGPoint {
        CGPoint(
            x: CGFloat(col) * GameConstants.tileSize + GameConstants.tileSize / 2,
            y: CGFloat(row) * GameConstants.tileSize + GameConstants.tileSize / 2
        )
    }
}

// MARK: - CGRect Extensions

public extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }

    func expanded(by amount: CGFloat) -> CGRect {
        insetBy(dx: -amount, dy: -amount)
    }
}

// MARK: - CGSize Extensions

public extension CGSize {
    static func square(_ size: CGFloat) -> CGSize {
        CGSize(width: size, height: size)
    }
}

// MARK: - SKNode Extensions

public extension SKNode {
    func fadeIn(duration: TimeInterval = GameConstants.fadeTransitionDuration) {
        alpha = 0
        run(.fadeIn(withDuration: duration))
    }

    func fadeOut(duration: TimeInterval = GameConstants.fadeTransitionDuration, completion: (() -> Void)? = nil) {
        run(.fadeOut(withDuration: duration)) {
            completion?()
        }
    }
}

// MARK: - Array Extensions

public extension Array {
    func randomElement(using rng: inout some RandomNumberGenerator) -> Element? {
        guard !isEmpty else { return nil }
        return self[Int.random(in: 0..<count, using: &rng)]
    }
}

// MARK: - GameColors to SKColor

public extension GameColors.RGB {
    var skColor: SKColor {
        SKColor(
            red: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: 1.0
        )
    }
}
