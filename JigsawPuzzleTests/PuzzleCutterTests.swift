import XCTest
@testable import JigsawPuzzle

final class PuzzleCutterTests: XCTestCase {

    func testCutProducesCorrectNumberOfPieces() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        XCTAssertTrue(pieces.count >= 20 && pieces.count <= 28,
            "Expected ~24 pieces, got \(pieces.count)")
    }

    func testAllPiecesHaveTextures() {
        let image = createTestImage(width: 400, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 16, seed: 42)

        for piece in pieces {
            XCTAssertNotNil(piece.texture, "Piece (\(piece.row),\(piece.col)) should have a texture")
        }
    }

    func testPiecesHaveUniquePositions() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        let positions = pieces.map { "\($0.row),\($0.col)" }
        let uniquePositions = Set(positions)
        XCTAssertEqual(positions.count, uniquePositions.count, "All pieces should have unique grid positions")
    }

    func testPiecesHaveCorrectPositions() {
        let image = createTestImage(width: 400, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 16, seed: 42)

        for piece in pieces {
            XCTAssertGreaterThanOrEqual(piece.correctPosition.x, 0)
            XCTAssertGreaterThanOrEqual(piece.correctPosition.y, 0)
        }
    }

    func testNeighborReferencesAreSymmetric() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        let pieceMap: [PieceID: PuzzleCutter.CutPiece] = Dictionary(uniqueKeysWithValues: pieces.map { ($0.id, $0) })

        for piece in pieces {
            for (edge, neighborID) in piece.neighbors {
                guard let neighbor = pieceMap[neighborID] else {
                    XCTFail("Neighbor \(neighborID) not found for piece \(piece.id)")
                    continue
                }
                XCTAssertEqual(neighbor.neighbors[edge.opposite], piece.id,
                    "Neighbor relationship should be symmetric")
            }
        }
    }

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
