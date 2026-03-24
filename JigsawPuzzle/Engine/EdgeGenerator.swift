import CoreGraphics

struct EdgeGenerator {
    let rows: Int
    let cols: Int
    private var rng: SeededRandomNumberGenerator

    init(rows: Int, cols: Int, seed: UInt64) {
        self.rows = rows
        self.cols = cols
        self.rng = SeededRandomNumberGenerator(seed: seed)
    }

    /// Generate edge types for all pieces in the grid.
    /// Returns a 2D array [row][col] of PieceEdges.
    mutating func generateAllEdges() -> [[PieceEdges]] {
        // Horizontal edges: between [row][col] right and [row][col+1] left
        // Store as the "right" edge of the left piece (tab or socket)
        var horizontalEdges: [[EdgeType]] = Array(
            repeating: Array(repeating: EdgeType.flat, count: cols - 1),
            count: rows
        )
        for row in 0..<rows {
            for col in 0..<(cols - 1) {
                horizontalEdges[row][col] = Bool.random(using: &rng) ? .tab : .socket
            }
        }

        // Vertical edges: between [row][col] bottom and [row+1][col] top
        // Store as the "bottom" edge of the top piece
        var verticalEdges: [[EdgeType]] = Array(
            repeating: Array(repeating: EdgeType.flat, count: cols),
            count: rows - 1
        )
        for row in 0..<(rows - 1) {
            for col in 0..<cols {
                verticalEdges[row][col] = Bool.random(using: &rng) ? .tab : .socket
            }
        }

        // Assemble PieceEdges for each piece
        var result: [[PieceEdges]] = []
        for row in 0..<rows {
            var rowEdges: [PieceEdges] = []
            for col in 0..<cols {
                let top: EdgeType = row == 0 ? .flat : verticalEdges[row - 1][col].complement
                let bottom: EdgeType = row == rows - 1 ? .flat : verticalEdges[row][col]
                let left: EdgeType = col == 0 ? .flat : horizontalEdges[row][col - 1].complement
                let right: EdgeType = col == cols - 1 ? .flat : horizontalEdges[row][col]

                rowEdges.append(PieceEdges(top: top, right: right, bottom: bottom, left: left))
            }
            result.append(rowEdges)
        }

        return result
    }

    /// Generate a bezier CGPath for a tab or socket along the given edge of a piece.
    /// The path starts at the edge's start point and ends at the edge's end point.
    /// For .flat, returns a straight line.
    func bezierPath(for edgeType: EdgeType, alongEdge edge: Edge, pieceSize: CGSize) -> CGPath {
        let path = CGMutablePath()
        let w = pieceSize.width
        let h = pieceSize.height

        // Tab parameters
        let tabHeight: CGFloat = 0.2  // proportion of piece size
        let tabWidth: CGFloat = 0.3   // proportion of edge length
        let neckWidth: CGFloat = 0.2  // proportion of edge length

        switch edge {
        case .right:
            let startY: CGFloat = 0
            let endY: CGFloat = h
            let edgeX: CGFloat = w
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? 1 : -1

            let tabH = w * tabHeight * direction
            let neckStart = edgeLen * (0.5 - neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + tabWidth / 2)

            path.move(to: CGPoint(x: edgeX, y: startY))
            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart + edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart - edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * 1.2, y: bulgeStart + edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * 1.2, y: bulgeEnd - edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd + edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd - edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: endY))

        case .left:
            let startY: CGFloat = h
            let endY: CGFloat = 0
            let edgeX: CGFloat = 0
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? -1 : 1

            let tabH = w * tabHeight * direction
            let neckStart = edgeLen * (0.5 + neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - tabWidth / 2)

            path.move(to: CGPoint(x: edgeX, y: startY))
            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart - edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart + edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * 1.2, y: bulgeStart - edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * 1.2, y: bulgeEnd + edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd - edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd + edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: endY))

        case .top:
            let startX: CGFloat = 0
            let endX: CGFloat = w
            let edgeY: CGFloat = 0
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? -1 : 1

            let tabH = h * tabHeight * direction
            let neckStart = edgeLen * (0.5 - neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + tabWidth / 2)

            path.move(to: CGPoint(x: startX, y: edgeY))
            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart + edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart - edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart + edgeLen * 0.05, y: edgeY + tabH * 1.2),
                control2: CGPoint(x: bulgeEnd - edgeLen * 0.05, y: edgeY + tabH * 1.2)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd + edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd - edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: endX, y: edgeY))

        case .bottom:
            let startX: CGFloat = w
            let endX: CGFloat = 0
            let edgeY: CGFloat = h
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? 1 : -1

            let tabH = h * tabHeight * direction
            let neckStart = edgeLen * (0.5 + neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - tabWidth / 2)

            path.move(to: CGPoint(x: startX, y: edgeY))
            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart - edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart + edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart - edgeLen * 0.05, y: edgeY + tabH * 1.2),
                control2: CGPoint(x: bulgeEnd + edgeLen * 0.05, y: edgeY + tabH * 1.2)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd - edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd + edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: endX, y: edgeY))
        }

        return path
    }
}

/// A simple seeded RNG for deterministic edge generation.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
