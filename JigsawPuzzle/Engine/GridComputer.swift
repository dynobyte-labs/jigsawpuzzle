import Foundation

struct GridComputer {

    /// Compute the best-fit grid (rows, cols) for a given piece count and image dimensions.
    /// Optimizes so piece aspect ratio is close to square.
    static func computeGrid(pieceCount: Int, imageWidth: CGFloat, imageHeight: CGFloat) -> (rows: Int, cols: Int) {
        let aspectRatio = imageWidth / imageHeight
        let targetCount = max(4, pieceCount)

        // For a grid of rows×cols where cols/rows ≈ aspectRatio:
        // cols = rows * aspectRatio
        // rows * cols = targetCount
        // rows * rows * aspectRatio = targetCount
        // rows = sqrt(targetCount / aspectRatio)
        let rawRows = sqrt(Double(targetCount) / aspectRatio)
        let rawCols = rawRows * aspectRatio

        // Try rounding combinations to find closest to target
        var bestRows = max(2, Int(rawRows.rounded()))
        var bestCols = max(2, Int(rawCols.rounded()))
        var bestDiff = abs(bestRows * bestCols - targetCount)

        for r in max(2, Int(rawRows.rounded(.down)))...max(2, Int(rawRows.rounded(.up)) + 1) {
            for c in max(2, Int(rawCols.rounded(.down)))...max(2, Int(rawCols.rounded(.up)) + 1) {
                let diff = abs(r * c - targetCount)
                if diff < bestDiff {
                    bestDiff = diff
                    bestRows = r
                    bestCols = c
                }
            }
        }

        return (rows: bestRows, cols: bestCols)
    }
}
