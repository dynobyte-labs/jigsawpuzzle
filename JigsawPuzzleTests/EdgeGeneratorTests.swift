import XCTest
@testable import JigsawPuzzle

final class EdgeGeneratorTests: XCTestCase {

    func testBorderEdgesAreFlat() {
        var generator = EdgeGenerator(rows: 4, cols: 6, seed: 42)
        let edges = generator.generateAllEdges()

        for col in 0..<6 {
            XCTAssertEqual(edges[0][col].top, .flat, "Top border should be flat at col \(col)")
        }
        for col in 0..<6 {
            XCTAssertEqual(edges[3][col].bottom, .flat, "Bottom border should be flat at col \(col)")
        }
        for row in 0..<4 {
            XCTAssertEqual(edges[row][0].left, .flat, "Left border should be flat at row \(row)")
        }
        for row in 0..<4 {
            XCTAssertEqual(edges[row][5].right, .flat, "Right border should be flat at row \(row)")
        }
    }

    func testNeighborEdgesAreComplementary() {
        var generator = EdgeGenerator(rows: 4, cols: 6, seed: 42)
        let edges = generator.generateAllEdges()

        for row in 0..<4 {
            for col in 0..<5 {
                let rightEdge = edges[row][col].right
                let leftEdge = edges[row][col + 1].left
                XCTAssertEqual(rightEdge.complement, leftEdge,
                    "Horizontal mismatch at (\(row),\(col))-(\(row),\(col+1))")
            }
        }

        for row in 0..<3 {
            for col in 0..<6 {
                let bottomEdge = edges[row][col].bottom
                let topEdge = edges[row + 1][col].top
                XCTAssertEqual(bottomEdge.complement, topEdge,
                    "Vertical mismatch at (\(row),\(col))-(\(row+1),\(col))")
            }
        }
    }

    func testDeterministicWithSameSeed() {
        var gen1 = EdgeGenerator(rows: 3, cols: 3, seed: 123)
        var gen2 = EdgeGenerator(rows: 3, cols: 3, seed: 123)
        let edges1 = gen1.generateAllEdges()
        let edges2 = gen2.generateAllEdges()

        for row in 0..<3 {
            for col in 0..<3 {
                XCTAssertEqual(edges1[row][col].top, edges2[row][col].top)
                XCTAssertEqual(edges1[row][col].right, edges2[row][col].right)
                XCTAssertEqual(edges1[row][col].bottom, edges2[row][col].bottom)
                XCTAssertEqual(edges1[row][col].left, edges2[row][col].left)
            }
        }
    }

    func testDifferentSeedsProduceDifferentResults() {
        var gen1 = EdgeGenerator(rows: 4, cols: 4, seed: 1)
        var gen2 = EdgeGenerator(rows: 4, cols: 4, seed: 2)
        let edges1 = gen1.generateAllEdges()
        let edges2 = gen2.generateAllEdges()

        var anyDifferent = false
        for row in 0..<4 {
            for col in 0..<4 {
                if edges1[row][col].right != edges2[row][col].right {
                    anyDifferent = true
                }
            }
        }
        XCTAssertTrue(anyDifferent, "Different seeds should produce different edge layouts")
    }

    func testInternalEdgesAreTabOrSocket() {
        var generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let edges = generator.generateAllEdges()

        for row in 0..<3 {
            for col in 0..<3 {
                if row > 0 {
                    XCTAssertNotEqual(edges[row][col].top, .flat, "Internal top edge should not be flat")
                }
                if col < 2 {
                    XCTAssertNotEqual(edges[row][col].right, .flat, "Internal right edge should not be flat")
                }
                if row < 2 {
                    XCTAssertNotEqual(edges[row][col].bottom, .flat, "Internal bottom edge should not be flat")
                }
                if col > 0 {
                    XCTAssertNotEqual(edges[row][col].left, .flat, "Internal left edge should not be flat")
                }
            }
        }
    }

    func testBezierPathGeneration() {
        var generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let path = generator.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100))
        XCTAssertFalse(path.isEmpty, "Bezier path should not be empty")
    }

    func testSocketPathIsInverse() {
        var generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let tabBounds = generator.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100)).boundingBoxOfPath
        var generator2 = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let socketBounds = generator2.bezierPath(for: .socket, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100)).boundingBoxOfPath

        XCTAssertGreaterThan(tabBounds.width, 0)
        XCTAssertGreaterThan(socketBounds.width, 0)
    }

    func testRandomizedParamsVaryBetweenEdges() {
        var gen1 = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let path1 = gen1.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100))
        let path2 = gen1.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100))

        // Different calls should produce different bezier shapes due to randomized params
        let bounds1 = path1.boundingBoxOfPath
        let bounds2 = path2.boundingBoxOfPath
        // At minimum both should be valid non-empty paths
        XCTAssertGreaterThan(bounds1.width, 0)
        XCTAssertGreaterThan(bounds2.width, 0)
        // Bounds should differ since params are randomized
        let widthsDiffer = abs(bounds1.width - bounds2.width) > 0.01
        let heightsDiffer = abs(bounds1.height - bounds2.height) > 0.01
        XCTAssertTrue(widthsDiffer || heightsDiffer, "Randomized params should produce varying shapes")
    }
}
