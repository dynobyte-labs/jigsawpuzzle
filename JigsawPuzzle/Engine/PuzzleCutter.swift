import UIKit
import CoreGraphics

struct PuzzleCutter {

    struct CutPiece {
        let id: PieceID
        let row: Int
        let col: Int
        let edges: PieceEdges
        let texture: UIImage?
        let path: CGPath
        let correctPosition: CGPoint
        let neighbors: [Edge: PieceID]
        let pieceSize: CGSize
        let pathBoundsOrigin: CGPoint  // offset for tab extensions
    }

    /// Cut an image into puzzle pieces.
    static func cut(image: UIImage, requestedPieceCount: Int, seed: UInt64) -> [CutPiece] {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: requestedPieceCount,
            imageWidth: image.size.width,
            imageHeight: image.size.height
        )

        var edgeGen = EdgeGenerator(rows: rows, cols: cols, seed: seed)
        let allEdges = edgeGen.generateAllEdges()

        let pieceWidth = image.size.width / CGFloat(cols)
        let pieceHeight = image.size.height / CGFloat(rows)
        let pieceSize = CGSize(width: pieceWidth, height: pieceHeight)

        // Build ID map: row,col -> PieceID
        var idMap: [[PieceID]] = []
        var nextID = 0
        for _ in 0..<rows {
            var rowIDs: [PieceID] = []
            for _ in 0..<cols {
                rowIDs.append(nextID)
                nextID += 1
            }
            idMap.append(rowIDs)
        }

        var pieces: [CutPiece] = []

        for row in 0..<rows {
            for col in 0..<cols {
                let edges = allEdges[row][col]
                let pieceID = idMap[row][col]

                // Build neighbor map
                var neighbors: [Edge: PieceID] = [:]
                if row > 0 { neighbors[.top] = idMap[row - 1][col] }
                if row < rows - 1 { neighbors[.bottom] = idMap[row + 1][col] }
                if col > 0 { neighbors[.left] = idMap[row][col - 1] }
                if col < cols - 1 { neighbors[.right] = idMap[row][col + 1] }

                // Assemble path
                let path = PathAssembler.assemblePath(
                    for: edges,
                    pieceSize: pieceSize,
                    edgeGenerator: edgeGen
                )

                // Source rect in the original image
                let sourceRect = CGRect(
                    x: CGFloat(col) * pieceWidth,
                    y: CGFloat(row) * pieceHeight,
                    width: pieceWidth,
                    height: pieceHeight
                )

                // Clip texture
                let texture = TextureClipper.clip(
                    image: image,
                    path: path,
                    sourceRect: sourceRect
                )

                let pathBounds = path.boundingBoxOfPath

                // Correct position = center of where this piece belongs
                let correctPosition = CGPoint(
                    x: sourceRect.midX,
                    y: sourceRect.midY
                )

                pieces.append(CutPiece(
                    id: pieceID,
                    row: row,
                    col: col,
                    edges: edges,
                    texture: texture,
                    path: path,
                    correctPosition: correctPosition,
                    neighbors: neighbors,
                    pieceSize: pieceSize,
                    pathBoundsOrigin: CGPoint(x: pathBounds.minX, y: pathBounds.minY)
                ))
            }
        }

        return pieces
    }
}
