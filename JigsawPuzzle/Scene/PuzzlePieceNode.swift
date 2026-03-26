import SpriteKit

class PuzzlePieceNode: SKSpriteNode {
    let pieceID: PieceID
    let row: Int
    let col: Int
    let edges: PieceEdges
    let correctPosition: CGPoint
    let neighbors: [Edge: PieceID]
    let piecePath: CGPath

    /// The uniform grid cell size (without tab/socket extensions)
    let gridCellSize: CGSize

    /// The grid cell center in this node's local coordinate system.
    /// Due to asymmetric tab/socket extensions, the node's anchor (0,0) is at the
    /// bounding box center, which differs from the grid cell center.
    let gridCenterLocal: CGPoint

    /// Accumulated rotation in degrees for snap logic (tracking only — visual
    /// rotation is handled by the parent group node's zRotation).
    var rotationDegrees: CGFloat = 0

    /// Whether this piece is locked to the board
    var isLockedToBoard: Bool = false

    init(cutPiece: PuzzleCutter.CutPiece) {
        self.pieceID = cutPiece.id
        self.row = cutPiece.row
        self.col = cutPiece.col
        self.edges = cutPiece.edges
        self.correctPosition = cutPiece.correctPosition
        self.neighbors = cutPiece.neighbors
        self.piecePath = cutPiece.path
        self.gridCellSize = cutPiece.pieceSize

        // Compute the grid cell center in SKNode local coordinates.
        let pathBounds = cutPiece.path.boundingBoxOfPath
        let nodeSize = pathBounds.size
        let offsetX = -min(0, pathBounds.minX)
        let offsetY = -min(0, pathBounds.minY)
        let gridCenterInImageX = offsetX + cutPiece.pieceSize.width / 2
        let gridCenterInImageY = offsetY + cutPiece.pieceSize.height / 2
        self.gridCenterLocal = CGPoint(
            x: gridCenterInImageX - nodeSize.width / 2,
            y: nodeSize.height / 2 - gridCenterInImageY
        )

        let texture: SKTexture?
        if let image = cutPiece.texture {
            texture = SKTexture(image: image)
        } else {
            texture = nil
        }

        super.init(texture: texture, color: .clear, size: nodeSize)

        self.name = "piece_\(pieceID)"
        self.isUserInteractionEnabled = false  // Handled by PuzzleScene
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not supported")
    }

    /// Visual feedback: lift piece (scale up, add shadow effect)
    func liftUp() {
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.1)
        scaleUp.timingMode = .easeOut
        run(scaleUp, withKey: "lift")
        zPosition = 1000

        // Add shadow matching the piece's bezier path
        let pathBounds = piecePath.boundingBoxOfPath
        let shadow = SKShapeNode(path: piecePath)
        shadow.fillColor = SKColor.black.withAlphaComponent(0.3)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(
            x: 4 - pathBounds.midX + size.width * 0.5,
            y: -4 - pathBounds.midY + size.height * 0.5
        )
        shadow.zPosition = -1
        shadow.name = "shadow"
        addChild(shadow)
    }

    /// Visual feedback: put piece down
    func putDown() {
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scaleDown.timingMode = .easeOut
        run(scaleDown, withKey: "lift")

        // Remove shadow
        childNode(withName: "shadow")?.removeFromParent()
    }

    /// Lock this piece to the board (make immovable, visual feedback)
    func lockToBoard() {
        isLockedToBoard = true
        zPosition = -1
        let brighten = SKAction.colorize(with: .white, colorBlendFactor: 0.1, duration: 0.2)
        run(brighten)
    }
}
