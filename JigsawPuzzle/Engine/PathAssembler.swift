import CoreGraphics

struct PathAssembler {

    /// Assemble a closed CGPath for a puzzle piece from its four edges.
    /// Path is constructed clockwise: top -> right -> bottom -> left.
    /// Each edge uses pre-generated params so adjacent pieces share identical curves.
    static func assemblePath(
        for edges: PieceEdges,
        pieceSize: CGSize,
        topParams: EdgeGenerator.EdgeParams,
        rightParams: EdgeGenerator.EdgeParams,
        bottomParams: EdgeGenerator.EdgeParams,
        leftParams: EdgeGenerator.EdgeParams
    ) -> CGPath {
        let path = CGMutablePath()

        // Start at top-left corner (0, 0)
        path.move(to: CGPoint(x: 0, y: 0))

        // Top edge: left to right
        EdgeGenerator.addEdgePath(to: path, for: edges.top, alongEdge: .top, pieceSize: pieceSize, params: topParams)

        // Right edge: top to bottom
        EdgeGenerator.addEdgePath(to: path, for: edges.right, alongEdge: .right, pieceSize: pieceSize, params: rightParams)

        // Bottom edge: right to left
        EdgeGenerator.addEdgePath(to: path, for: edges.bottom, alongEdge: .bottom, pieceSize: pieceSize, params: bottomParams)

        // Left edge: bottom to top
        EdgeGenerator.addEdgePath(to: path, for: edges.left, alongEdge: .left, pieceSize: pieceSize, params: leftParams)

        path.closeSubpath()
        return path
    }
}
