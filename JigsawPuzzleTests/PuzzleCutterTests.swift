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

    func testGridCenterLocalOffsetIsCorrect() {
        // For a piece with all flat edges, gridCenterLocal should be (0, 0)
        // because the bounding box equals the grid cell — no asymmetric tabs.
        let image = createTestImage(width: 400, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 16, seed: 42)

        // Corner piece (0,0) has top=flat, left=flat. Only right and bottom may have tabs.
        // Find it and create a PuzzlePieceNode.
        guard let topLeftCut = pieces.first(where: { $0.row == 0 && $0.col == 0 }) else {
            XCTFail("Missing piece (0,0)")
            return
        }
        let topLeftNode = PuzzlePieceNode(cutPiece: topLeftCut)

        // gridCellSize should be the uniform grid cell size, not the bounding box
        XCTAssertEqual(topLeftNode.gridCellSize.width, topLeftCut.pieceSize.width, accuracy: 0.01)
        XCTAssertEqual(topLeftNode.gridCellSize.height, topLeftCut.pieceSize.height, accuracy: 0.01)

        // For any piece, the grid center offset should account for path bounds asymmetry
        for cutPiece in pieces {
            let node = PuzzlePieceNode(cutPiece: cutPiece)
            let pathBounds = cutPiece.path.boundingBoxOfPath

            // Recompute expected gridCenterLocal
            let offsetX = -min(0, pathBounds.minX)
            let offsetY = -min(0, pathBounds.minY)
            let nodeSize = pathBounds.size
            let expectedX = (offsetX + cutPiece.pieceSize.width / 2) - nodeSize.width / 2
            let expectedY = nodeSize.height / 2 - (offsetY + cutPiece.pieceSize.height / 2)

            XCTAssertEqual(node.gridCenterLocal.x, expectedX, accuracy: 0.01,
                "gridCenterLocal.x wrong for piece (\(cutPiece.row),\(cutPiece.col))")
            XCTAssertEqual(node.gridCenterLocal.y, expectedY, accuracy: 0.01,
                "gridCenterLocal.y wrong for piece (\(cutPiece.row),\(cutPiece.col))")
        }
    }

    func testAdjacentPieceCorrectPositionsAreOneCellApart() {
        // Adjacent pieces' correctPositions should differ by exactly one grid cell dimension.
        let image = createTestImage(width: 300, height: 300)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 9, seed: 42)
        let pieceMap = Dictionary(uniqueKeysWithValues: pieces.map { ($0.id, $0) })

        for piece in pieces {
            for (edge, neighborID) in piece.neighbors {
                guard let neighbor = pieceMap[neighborID] else { continue }
                let dx = neighbor.correctPosition.x - piece.correctPosition.x
                let dy = neighbor.correctPosition.y - piece.correctPosition.y

                switch edge {
                case .right:
                    XCTAssertEqual(dx, piece.pieceSize.width, accuracy: 0.01,
                        "Right neighbor should be one cell width apart")
                    XCTAssertEqual(dy, 0, accuracy: 0.01)
                case .left:
                    XCTAssertEqual(dx, -piece.pieceSize.width, accuracy: 0.01)
                    XCTAssertEqual(dy, 0, accuracy: 0.01)
                case .bottom:
                    // In SpriteKit coords (Y-up), bottom neighbor has LOWER Y
                    XCTAssertEqual(dx, 0, accuracy: 0.01)
                    XCTAssertEqual(dy, -piece.pieceSize.height, accuracy: 0.01,
                        "Bottom neighbor should be one cell height below")
                case .top:
                    // In SpriteKit coords (Y-up), top neighbor has HIGHER Y
                    XCTAssertEqual(dx, 0, accuracy: 0.01)
                    XCTAssertEqual(dy, piece.pieceSize.height, accuracy: 0.01,
                        "Top neighbor should be one cell height above")
                }
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
