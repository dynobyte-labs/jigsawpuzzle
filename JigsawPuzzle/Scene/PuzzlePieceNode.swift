import SpriteKit

class PuzzlePieceNode: SKSpriteNode {
    let pieceID: PieceID
    let row: Int
    let col: Int
    let edges: PieceEdges
    let correctPosition: CGPoint
    let neighbors: [Edge: PieceID]
    let piecePath: CGPath

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

        let texture: SKTexture?
        if let image = cutPiece.texture {
            texture = SKTexture(image: image)
        } else {
            texture = nil
        }

        let size = cutPiece.path.boundingBoxOfPath.size
        super.init(texture: texture, color: .clear, size: size)

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
