import XCTest
@testable import JigsawPuzzle

final class TextureClipperTests: XCTestCase {

    func testClipProducesNonNilImage() {
        let testImage = createTestImage(width: 200, height: 200, color: .red)
        let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

        let result = TextureClipper.clip(
            image: testImage,
            path: clipPath,
            sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100)
        )

        XCTAssertNotNil(result, "Clipped image should not be nil")
    }

    func testClipOutputMatchesBoundingBox() {
        let testImage = createTestImage(width: 400, height: 400, color: .blue)
        let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 150, height: 100), transform: nil)

        let result = TextureClipper.clip(
            image: testImage,
            path: clipPath,
            sourceRect: CGRect(x: 50, y: 50, width: 150, height: 100)
        )

        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(Int(result!.size.width), 150)
        XCTAssertGreaterThanOrEqual(Int(result!.size.height), 100)
    }

    func testClipWithTabPath() {
        let testImage = createTestImage(width: 400, height: 400, color: .green)
        let pieceSize = CGSize(width: 100, height: 100)
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)
        let tabParams = EdgeGenerator.EdgeParams(tabHeight: 0.2, tabWidth: 0.3, neckWidth: 0.2, curvature: 1.2)
        let flatParams = EdgeGenerator.EdgeParams(tabHeight: 0, tabWidth: 0, neckWidth: 0, curvature: 0)

        let piecePath = PathAssembler.assemblePath(
            for: edges, pieceSize: pieceSize,
            topParams: flatParams, rightParams: tabParams,
            bottomParams: flatParams, leftParams: flatParams
        )

        let result = TextureClipper.clip(
            image: testImage,
            path: piecePath,
            sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100)
        )

        XCTAssertNotNil(result, "Should clip with bezier tab path")
        XCTAssertGreaterThan(result!.size.width, 100)
    }

    // MARK: - Helpers

    private func createTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
