import Foundation
import SpriteKit

/// Controls the camera viewport, following a target with smooth interpolation
/// and clamping to room boundaries.
public final class CameraController {
    public let cameraNode: SKCameraNode
    public var target: SKNode?

    /// The bounding rect the camera cannot scroll beyond (room bounds)
    public var bounds: CGRect = .zero

    /// The visible area size (screen/viewport size)
    public var viewportSize: CGSize = .zero

    public var lerpSpeed: CGFloat = GameConstants.cameraLerpSpeed

    public init() {
        cameraNode = SKCameraNode()
        cameraNode.name = "gameCamera"
    }

    /// Call every frame to smoothly follow the target
    public func update(deltaTime: TimeInterval) {
        guard let target = target else { return }

        let targetPosition = target.position
        let dt = CGFloat(deltaTime)

        // Lerp toward target
        let newPosition = cameraNode.position.lerp(
            to: targetPosition,
            factor: min(lerpSpeed * dt, 1.0)
        )

        // Clamp to room bounds
        cameraNode.position = clampPosition(newPosition)
    }

    /// Instantly snap camera to target position (for room transitions)
    public func snapToTarget() {
        guard let target = target else { return }
        cameraNode.position = clampPosition(target.position)
    }

    /// Snap camera to a specific position
    public func snapTo(_ position: CGPoint) {
        cameraNode.position = clampPosition(position)
    }

    /// Set the room boundaries the camera should stay within
    public func setRoomBounds(width: CGFloat, height: CGFloat) {
        bounds = CGRect(x: 0, y: 0, width: width, height: height)
    }

    // MARK: - Private

    private func clampPosition(_ position: CGPoint) -> CGPoint {
        guard bounds.width > 0 && bounds.height > 0 else { return position }

        let halfWidth = viewportSize.width / 2
        let halfHeight = viewportSize.height / 2

        let minX = bounds.minX + halfWidth
        let maxX = bounds.maxX - halfWidth
        let minY = bounds.minY + halfHeight
        let maxY = bounds.maxY - halfHeight

        return CGPoint(
            x: max(minX, min(maxX, position.x)),
            y: max(minY, min(maxY, position.y))
        )
    }
}
