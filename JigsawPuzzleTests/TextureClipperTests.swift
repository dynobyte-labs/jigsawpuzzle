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
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)

        let piecePath = PathAssembler.assemblePath(for: edges, pieceSize: pieceSize, edgeGenerator: edgeGen)

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
