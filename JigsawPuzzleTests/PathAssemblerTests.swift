import XCTest
@testable import JigsawPuzzle

final class PathAssemblerTests: XCTestCase {

    private let defaultParams = EdgeGenerator.EdgeParams(
        tabHeight: 0.2, tabWidth: 0.3, neckWidth: 0.2, curvature: 1.2
    )
    private let flatParams = EdgeGenerator.EdgeParams(
        tabHeight: 0, tabWidth: 0, neckWidth: 0, curvature: 0
    )

    func testAssembledPathIsClosed() {
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .socket, left: .flat)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            topParams: flatParams,
            rightParams: defaultParams,
            bottomParams: defaultParams,
            leftParams: flatParams
        )

        let bounds = path.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testFlatEdgesProduceRectangle() {
        let edges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            topParams: flatParams,
            rightParams: flatParams,
            bottomParams: flatParams,
            leftParams: flatParams
        )

        let bounds = path.boundingBoxOfPath
        XCTAssertEqual(bounds.width, pieceSize.width, accuracy: 1.0)
        XCTAssertEqual(bounds.height, pieceSize.height, accuracy: 1.0)
    }

    func testTabEdgeExtendsBoundingBox() {
        let flatEdges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let tabEdges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)
        let pieceSize = CGSize(width: 100, height: 100)

        let flatPath = PathAssembler.assemblePath(
            for: flatEdges, pieceSize: pieceSize,
            topParams: flatParams, rightParams: flatParams,
            bottomParams: flatParams, leftParams: flatParams
        )
        let tabPath = PathAssembler.assemblePath(
            for: tabEdges, pieceSize: pieceSize,
            topParams: flatParams, rightParams: defaultParams,
            bottomParams: flatParams, leftParams: flatParams
        )

        XCTAssertGreaterThan(tabPath.boundingBoxOfPath.width, flatPath.boundingBoxOfPath.width)
    }
}
