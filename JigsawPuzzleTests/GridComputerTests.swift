import XCTest
@testable import JigsawPuzzle

final class GridComputerTests: XCTestCase {

    func testSquareImageWith48Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 48,
            imageWidth: 1000,
            imageHeight: 1000
        )
        XCTAssertEqual(rows * cols, 49, "Should pick closest grid to 48 for square image")
        // 7x7=49 is closest to 48 for a 1:1 ratio
    }

    func testLandscapeImageWith48Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 48,
            imageWidth: 2000,
            imageHeight: 1500
        )
        // 4:3 aspect -> 8x6=48 is a perfect fit
        XCTAssertEqual(rows, 6)
        XCTAssertEqual(cols, 8)
        XCTAssertEqual(rows * cols, 48)
    }

    func testSmall10Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 10,
            imageWidth: 1600,
            imageHeight: 1200
        )
        // Should produce a small grid near 10 pieces
        let total = rows * cols
        XCTAssertTrue(total >= 8 && total <= 12, "Should be close to 10, got \(total)")
        XCTAssertTrue(rows >= 2 && cols >= 2, "Must have at least 2 rows and cols")
    }

    func testMax100Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 100,
            imageWidth: 1920,
            imageHeight: 1080
        )
        let total = rows * cols
        XCTAssertTrue(total >= 90 && total <= 110, "Should be close to 100, got \(total)")
    }

    func testMinimumGrid() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 2,
            imageWidth: 500,
            imageHeight: 500
        )
        XCTAssertTrue(rows >= 2 && cols >= 2, "Minimum grid is 2x2")
    }
}
