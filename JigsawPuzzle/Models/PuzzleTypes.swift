import CoreGraphics
import UIKit

typealias PieceID = Int

enum Edge: CaseIterable, Hashable {
    case top, right, bottom, left

    var opposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .right
        case .right: return .left
        }
    }
}

enum EdgeType: Equatable {
    case flat
    case tab
    case socket

    var complement: EdgeType {
        switch self {
        case .tab: return .socket
        case .socket: return .tab
        case .flat: return .flat
        }
    }
}

struct PieceEdges {
    let top: EdgeType
    let right: EdgeType
    let bottom: EdgeType
    let left: EdgeType

    func edgeType(for edge: Edge) -> EdgeType {
        switch edge {
        case .top: return top
        case .right: return right
        case .bottom: return bottom
        case .left: return left
        }
    }
}

struct PieceMetadata {
    let id: PieceID
    let row: Int
    let col: Int
    let edges: PieceEdges
    let correctPosition: CGPoint
    let neighbors: [Edge: PieceID]
}

struct PuzzleConfig {
    let image: UIImage
    let rows: Int
    let cols: Int
    let seed: UInt64
    let pieceSize: CGSize

    var totalPieces: Int { rows * cols }
}
