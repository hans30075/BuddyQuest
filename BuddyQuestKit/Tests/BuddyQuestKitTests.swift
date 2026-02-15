import XCTest
@testable import BuddyQuestKit

final class CollisionSystemTests: XCTestCase {

    func testCollisionLayerFromData() {
        let data: [[Int]] = [
            [1, 1, 1],
            [1, 0, 1],
            [1, 1, 1],
        ]
        let layer = CollisionLayer(from: data)

        // Corners should be solid
        XCTAssertTrue(layer.isSolid(col: 0, row: 0))
        XCTAssertTrue(layer.isSolid(col: 2, row: 2))

        // Center should be empty (row 1 col 1 in data = row 1 col 1 after flip)
        XCTAssertFalse(layer.isSolid(col: 1, row: 1))
    }

    func testOutOfBoundsIsSolid() {
        let layer = CollisionLayer(width: 3, height: 3)
        XCTAssertTrue(layer.isSolid(col: -1, row: 0))
        XCTAssertTrue(layer.isSolid(col: 3, row: 0))
        XCTAssertTrue(layer.isSolid(col: 0, row: -1))
        XCTAssertTrue(layer.isSolid(col: 0, row: 3))
    }

    func testMovementResolutionWithNoCollision() {
        let system = CollisionSystem()
        system.collisionLayer = CollisionLayer(width: 10, height: 10)

        let newPos = system.resolveMovement(
            currentPosition: CGPoint(x: 50, y: 50),
            hitboxSize: CGSize(width: 24, height: 24),
            delta: CGPoint(x: 5, y: 0)
        )

        XCTAssertEqual(newPos.x, 55, accuracy: 0.01)
        XCTAssertEqual(newPos.y, 50, accuracy: 0.01)
    }
}

final class GameStateTests: XCTestCase {

    func testStateTransition() {
        let manager = GameStateManager()
        XCTAssertEqual(manager.currentState, .title)

        manager.transition(to: .playing)
        XCTAssertEqual(manager.currentState, .playing)
        XCTAssertEqual(manager.previousState, .title)
    }

    func testReturnToPrevious() {
        let manager = GameStateManager()
        manager.transition(to: .playing)
        manager.transition(to: .paused)
        XCTAssertEqual(manager.currentState, .paused)

        manager.returnToPrevious()
        XCTAssertEqual(manager.currentState, .playing)
    }

    func testIsOverlay() {
        let manager = GameStateManager()
        manager.transition(to: .playing)
        XCTAssertFalse(manager.isInOverlay)

        manager.transition(to: .dialogue)
        XCTAssertTrue(manager.isInOverlay)

        manager.transition(to: .challenge)
        XCTAssertTrue(manager.isInOverlay)
    }
}

final class PlayerTests: XCTestCase {

    func testXPAndLeveling() {
        let player = PlayerCharacter()
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.totalXP, 0)

        player.addXP(50)
        XCTAssertEqual(player.level, 1)
        XCTAssertEqual(player.xpForCurrentLevel, 50)

        player.addXP(60)  // 110 total, should be level 2
        XCTAssertEqual(player.level, 2)
        XCTAssertEqual(player.xpForCurrentLevel, 10)
    }

    func testXPProgress() {
        let player = PlayerCharacter()
        player.addXP(50)
        XCTAssertEqual(player.xpProgressFraction, 0.5, accuracy: 0.01)
    }
}

final class ExtensionTests: XCTestCase {

    func testCGPointDistance() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 3, y: 4)
        XCTAssertEqual(a.distance(to: b), 5.0, accuracy: 0.001)
    }

    func testCGPointNormalized() {
        let p = CGPoint(x: 3, y: 4)
        let n = p.normalized()
        XCTAssertEqual(n.length, 1.0, accuracy: 0.001)
    }

    func testCGPointLerp() {
        let a = CGPoint(x: 0, y: 0)
        let b = CGPoint(x: 10, y: 10)
        let mid = a.lerp(to: b, factor: 0.5)
        XCTAssertEqual(mid.x, 5, accuracy: 0.001)
        XCTAssertEqual(mid.y, 5, accuracy: 0.001)
    }

    func testTileCoordConversion() {
        let pos = CGPoint(x: 96, y: 144)
        let tile = pos.toTileCoord()
        XCTAssertEqual(tile.col, 2)  // 96 / 48 = 2
        XCTAssertEqual(tile.row, 3)  // 144 / 48 = 3
    }
}

final class DirectionTests: XCTestCase {

    func testDirectionVectors() {
        XCTAssertEqual(Direction.up.dy, 1)
        XCTAssertEqual(Direction.down.dy, -1)
        XCTAssertEqual(Direction.left.dx, -1)
        XCTAssertEqual(Direction.right.dx, 1)
    }
}

final class DifficultyTests: XCTestCase {

    func testDifficultyProgression() {
        XCTAssertEqual(DifficultyLevel.beginner.next, .easy)
        XCTAssertEqual(DifficultyLevel.advanced.next, .advanced)
        XCTAssertEqual(DifficultyLevel.beginner.previous, .beginner)
        XCTAssertEqual(DifficultyLevel.easy.previous, .beginner)
    }

    func testDifficultyComparable() {
        XCTAssertTrue(DifficultyLevel.beginner < .easy)
        XCTAssertTrue(DifficultyLevel.hard < .advanced)
        XCTAssertFalse(DifficultyLevel.medium < .beginner)
    }
}
