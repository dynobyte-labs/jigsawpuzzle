import CoreGraphics

struct PathAssembler {

    /// Assemble a closed CGPath for a puzzle piece from its four edges.
    /// Path is constructed clockwise: top -> right -> bottom -> left.
    /// EdgeGenerator is inout because bezierPath uses the seeded RNG for randomized params.
    static func assemblePath(
        for edges: PieceEdges,
        pieceSize: CGSize,
        edgeGenerator: inout EdgeGenerator
    ) -> CGPath {
        let path = CGMutablePath()

        // Start at top-left corner (0, 0)
        // Top edge: left to right
        let topPath = edgeGenerator.bezierPath(for: edges.top, alongEdge: .top, pieceSize: pieceSize)
        path.addPath(topPath)

        // Right edge: top to bottom
        let rightPath = edgeGenerator.bezierPath(for: edges.right, alongEdge: .right, pieceSize: pieceSize)
        path.addPath(rightPath)

        // Bottom edge: right to left
        let bottomPath = edgeGenerator.bezierPath(for: edges.bottom, alongEdge: .bottom, pieceSize: pieceSize)
        path.addPath(bottomPath)

        // Left edge: bottom to top
        let leftPath = edgeGenerator.bezierPath(for: edges.left, alongEdge: .left, pieceSize: pieceSize)
        path.addPath(leftPath)

        path.closeSubpath()
        return path
    }
}
