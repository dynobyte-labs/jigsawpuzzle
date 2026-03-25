import CoreGraphics

struct EdgeGenerator {
    let rows: Int
    let cols: Int
    private var rng: SeededRandomNumberGenerator

    /// Randomized bezier parameters for one edge curve.
    struct EdgeParams {
        let tabHeight: CGFloat   // proportion of perpendicular piece dimension
        let tabWidth: CGFloat    // proportion of edge length
        let neckWidth: CGFloat   // proportion of edge length
        let curvature: CGFloat   // bulge roundness multiplier
    }

    init(rows: Int, cols: Int, seed: UInt64) {
        self.rows = rows
        self.cols = cols
        self.rng = SeededRandomNumberGenerator(seed: seed)
    }

    /// Generate edge types for all pieces in the grid.
    /// Returns a 2D array [row][col] of PieceEdges.
    mutating func generateAllEdges() -> [[PieceEdges]] {
        // Horizontal edges: between [row][col] right and [row][col+1] left
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

    /// Generate randomized bezier parameters for a single edge.
    mutating func generateEdgeParams() -> EdgeParams {
        EdgeParams(
            tabHeight: randomInRange(min: 0.15, max: 0.25),
            tabWidth: randomInRange(min: 0.25, max: 0.35),
            neckWidth: randomInRange(min: 0.15, max: 0.25),
            curvature: randomInRange(min: 1.0, max: 1.4)
        )
    }

    /// Pre-generate EdgeParams for all grid edges.
    /// horizontal[row][col] = params for edge between pieces (row,col) and (row,col+1).
    /// vertical[row][col] = params for edge between pieces (row,col) and (row+1,col).
    mutating func generateAllEdgeParams() -> (horizontal: [[EdgeParams]], vertical: [[EdgeParams]]) {
        var horizontal: [[EdgeParams]] = []
        for _ in 0..<rows {
            var row: [EdgeParams] = []
            for _ in 0..<(cols - 1) {
                row.append(generateEdgeParams())
            }
            horizontal.append(row)
        }

        var vertical: [[EdgeParams]] = []
        for _ in 0..<(rows - 1) {
            var row: [EdgeParams] = []
            for _ in 0..<cols {
                row.append(generateEdgeParams())
            }
            vertical.append(row)
        }

        return (horizontal, vertical)
    }

    /// Add a bezier edge curve to an existing path (continues from current point, no initial move).
    /// For flat edges, draws a straight line to the endpoint.
    static func addEdgePath(
        to path: CGMutablePath,
        for edgeType: EdgeType,
        alongEdge edge: Edge,
        pieceSize: CGSize,
        params: EdgeParams
    ) {
        let w = pieceSize.width
        let h = pieceSize.height

        // Flat edges: straight line to endpoint
        if edgeType == .flat {
            switch edge {
            case .top:    path.addLine(to: CGPoint(x: w, y: 0))
            case .right:  path.addLine(to: CGPoint(x: w, y: h))
            case .bottom: path.addLine(to: CGPoint(x: 0, y: h))
            case .left:   path.addLine(to: CGPoint(x: 0, y: 0))
            }
            return
        }

        switch edge {
        case .right:
            let edgeX: CGFloat = w
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? 1 : -1
            let tabH = w * params.tabHeight * direction
            let neckStart = edgeLen * (0.5 - params.neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + params.neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - params.tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + params.tabWidth / 2)

            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart + edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart - edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * params.curvature, y: bulgeStart + edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * params.curvature, y: bulgeEnd - edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd + edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd - edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: h))

        case .left:
            let edgeX: CGFloat = 0
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? -1 : 1
            let tabH = w * params.tabHeight * direction
            let neckStart = edgeLen * (0.5 + params.neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - params.neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + params.tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - params.tabWidth / 2)

            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart - edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart + edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * params.curvature, y: bulgeStart - edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * params.curvature, y: bulgeEnd + edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd - edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd + edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: 0))

        case .top:
            let edgeY: CGFloat = 0
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? -1 : 1
            let tabH = h * params.tabHeight * direction
            let neckStart = edgeLen * (0.5 - params.neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + params.neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - params.tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + params.tabWidth / 2)

            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart + edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart - edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart + edgeLen * 0.05, y: edgeY + tabH * params.curvature),
                control2: CGPoint(x: bulgeEnd - edgeLen * 0.05, y: edgeY + tabH * params.curvature)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd + edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd - edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: w, y: edgeY))

        case .bottom:
            let edgeY: CGFloat = h
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? 1 : -1
            let tabH = h * params.tabHeight * direction
            let neckStart = edgeLen * (0.5 + params.neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - params.neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + params.tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - params.tabWidth / 2)

            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart - edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart + edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart - edgeLen * 0.05, y: edgeY + tabH * params.curvature),
                control2: CGPoint(x: bulgeEnd + edgeLen * 0.05, y: edgeY + tabH * params.curvature)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd - edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd + edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: 0, y: edgeY))
        }
    }

    /// Generate a standalone bezier CGPath for a single edge (with initial move).
    /// Used by tests; production code uses addEdgePath via PathAssembler.
    mutating func bezierPath(for edgeType: EdgeType, alongEdge edge: Edge, pieceSize: CGSize) -> CGPath {
        let path = CGMutablePath()
        let params = generateEdgeParams()
        let w = pieceSize.width
        let h = pieceSize.height

        switch edge {
        case .top:    path.move(to: CGPoint(x: 0, y: 0))
        case .right:  path.move(to: CGPoint(x: w, y: 0))
        case .bottom: path.move(to: CGPoint(x: w, y: h))
        case .left:   path.move(to: CGPoint(x: 0, y: h))
        }

        EdgeGenerator.addEdgePath(to: path, for: edgeType, alongEdge: edge, pieceSize: pieceSize, params: params)
        return path
    }

    /// Generate a random CGFloat in the given range using the seeded RNG.
    private mutating func randomInRange(min: CGFloat, max: CGFloat) -> CGFloat {
        let raw = CGFloat(rng.next() % 10000) / 10000.0  // 0.0 ..< 1.0
        return min + raw * (max - min)
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
