import XCTest
@testable import JigsawPuzzle

final class PathAssemblerTests: XCTestCase {

    func testAssembledPathIsClosed() {
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .socket, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            edgeGenerator: edgeGen
        )

        let bounds = path.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testFlatEdgesProduceRectangle() {
        let edges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            edgeGenerator: edgeGen
        )

        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds.width, pieceSize.width, accuracy: 1.0)
        XCTAssertEqual(bounds.height, pieceSize.height, accuracy: 1.0)
    }

    func testTabEdgeExtendsBoundingBox() {
        let flatEdges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let tabEdges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let flatPath = PathAssembler.assemblePath(for: flatEdges, pieceSize: pieceSize, edgeGenerator: edgeGen)
        let tabPath = PathAssembler.assemblePath(for: tabEdges, pieceSize: pieceSize, edgeGenerator: edgeGen)

        XCTAssertGreaterThan(tabPath.boundingBoxOfPath.width, flatPath.boundingBoxOfPath.width)
    }
}
