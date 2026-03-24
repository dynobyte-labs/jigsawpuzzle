import SpriteKit

class PieceGroupNode: SKNode {
    /// All pieces in this group
    var pieces: [PuzzlePieceNode] {
        children.compactMap { $0 as? PuzzlePieceNode }
    }

    /// Whether this entire group is locked to the board
    var isLockedToBoard: Bool = false

    /// Exposed edges: edges of pieces in this group that are not connected to another piece in the group.
    /// Returns tuples of (piece, edge direction, neighbor piece ID).
    var exposedEdges: [(piece: PuzzlePieceNode, edge: Edge, neighborID: PieceID)] {
        let pieceIDs = Set(pieces.map(\.pieceID))
        var exposed: [(PuzzlePieceNode, Edge, PieceID)] = []

        for piece in pieces {
            for (edge, neighborID) in piece.neighbors {
                if !pieceIDs.contains(neighborID) {
                    exposed.append((piece, edge, neighborID))
                }
            }
        }
        return exposed
    }

    /// Add a piece to this group, positioning it relative to the group's coordinate system.
    func addPiece(_ piece: PuzzlePieceNode, at localPosition: CGPoint) {
        piece.removeFromParent()
        piece.position = localPosition
        addChild(piece)
    }

    /// Merge another group into this one.
    /// Reparents all pieces from the other group, adjusting positions.
    func merge(otherGroup: PieceGroupNode) {
        let offset = CGPoint(
            x: otherGroup.position.x - position.x,
            y: otherGroup.position.y - position.y
        )

        let otherPieces = otherGroup.pieces
        for piece in otherPieces {
            let localPos = CGPoint(
                x: piece.position.x + offset.x,
                y: piece.position.y + offset.y
            )
            piece.removeFromParent()
            piece.position = localPos
            addChild(piece)
        }

        otherGroup.removeFromParent()
    }

    /// Lock the entire group to the board.
    func lockToBoard() {
        isLockedToBoard = true
        zPosition = -1
        for piece in pieces {
            piece.lockToBoard()
        }
    }

    /// Visual feedback: lift group
    func liftUp() {
        let scaleUp = SKAction.scale(to: 1.05, duration: 0.1)
        scaleUp.timingMode = .easeOut
        run(scaleUp, withKey: "lift")
        zPosition = 1000
    }

    /// Visual feedback: put group down
    func putDown() {
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scaleDown.timingMode = .easeOut
        run(scaleDown, withKey: "lift")
    }
}
