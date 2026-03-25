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

    /// Current rotation in degrees (0, 90, 180, 270 after snap-assist)
    var rotationDegrees: CGFloat = 0 {
        didSet { zRotation = rotationDegrees * .pi / 180 }
    }

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
        // The texture is rendered by TextureClipper with an offset to account for
        // tabs extending into negative path coordinates. The SKSpriteNode centers
        // the texture on its anchor point (0.5, 0.5), so local (0,0) = bounding box center.
        // We need the grid cell center, which may differ due to asymmetric tab extensions.
        let pathBounds = cutPiece.path.boundingBoxOfPath
        let nodeSize = pathBounds.size
        let offsetX = -min(0, pathBounds.minX)
        let offsetY = -min(0, pathBounds.minY)
        // Grid cell center in the texture image coordinate system (UIKit, Y-down)
        let gridCenterInImageX = offsetX + cutPiece.pieceSize.width / 2
        let gridCenterInImageY = offsetY + cutPiece.pieceSize.height / 2
        // Convert to SKNode local coordinates (Y-up, centered on bounding box)
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

    /// Snap rotation to nearest 90-degree increment with spring animation.
    func snapRotation() {
        let nearest90 = (rotationDegrees / 90).rounded() * 90
        let normalizedRotation = nearest90.truncatingRemainder(dividingBy: 360)
        rotationDegrees = normalizedRotation

        let targetRadians = normalizedRotation * .pi / 180
        let springAction = SKAction.rotate(toAngle: targetRadians, duration: 0.2, shortestUnitArc: true)
        springAction.timingMode = .easeOut
        run(springAction)
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
        // Offset shadow down-right, adjust for path origin
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
