import XCTest
@testable import JigsawPuzzle

final class SnapManagerTests: XCTestCase {

    let pieceSize = CGSize(width: 100, height: 100)

    func testSnapWhenCloseAndAligned() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should snap when close and aligned")
    }

    func testNoSnapWhenTooFar() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 200, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when too far apart")
    }

    func testNoSnapWhenRotationOff() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 45,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when rotation is too far off")
    }

    func testNoSnapWhenMovingTooFast() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 800, dy: 800),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when moving too fast")
    }

    func testSnapWithSmallRotationDifference() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 5,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should snap when rotation is within threshold")
    }

    func testBoardLockWhenAtCorrectPosition() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldBoardLock(
            piecePosition: CGPoint(x: 102, y: 98),
            correctPosition: CGPoint(x: 100, y: 100),
            pieceRotation: 2,
            velocity: CGVector(dx: 5, dy: 5),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should board-lock when at correct position and rotation")
    }

    func testNoBoardLockWhenRotated() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldBoardLock(
            piecePosition: CGPoint(x: 100, y: 100),
            correctPosition: CGPoint(x: 100, y: 100),
            pieceRotation: 90,
            velocity: .zero,
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not board-lock when rotated 90 degrees")
    }
}
