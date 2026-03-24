import UIKit

struct PuzzleInfo: Identifiable {
    let id: String
    let title: String
    let category: String
    let imageName: String
}

struct PuzzleCatalog {
    static let puzzles: [PuzzleInfo] = [
        PuzzleInfo(id: "mountain", title: "Mountain Lake", category: "Landscape", imageName: "puzzle_mountain"),
        PuzzleInfo(id: "ocean", title: "Ocean Sunset", category: "Seascape", imageName: "puzzle_ocean"),
        PuzzleInfo(id: "sunflower", title: "Sunflower Field", category: "Nature", imageName: "puzzle_sunflower"),
        PuzzleInfo(id: "temple", title: "Ancient Temple", category: "Architecture", imageName: "puzzle_temple"),
        PuzzleInfo(id: "safari", title: "Safari Wildlife", category: "Animals", imageName: "puzzle_safari"),
        PuzzleInfo(id: "abstract", title: "Abstract Art", category: "Art", imageName: "puzzle_abstract"),
    ]

    /// Generate a placeholder gradient image for a puzzle when asset is not available.
    static func placeholderImage(for puzzleID: String, size: CGSize = CGSize(width: 1024, height: 768)) -> UIImage {
        let colors: [String: (UIColor, UIColor)] = [
            "mountain": (.systemRed, .systemOrange),
            "ocean": (.systemCyan, .systemBlue),
            "sunflower": (.systemYellow, .systemOrange),
            "temple": (.systemPurple, .systemIndigo),
            "safari": (.systemGreen, .systemTeal),
            "abstract": (.systemPink, .systemPurple),
        ]

        let (startColor, endColor) = colors[puzzleID] ?? (.gray, .darkGray)

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [startColor.cgColor, endColor.cgColor] as CFArray,
                locations: [0, 1]
            )!
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: .zero,
                end: CGPoint(x: size.width, y: size.height),
                options: []
            )

            // Add grid lines for visual reference
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.15).cgColor)
            ctx.cgContext.setLineWidth(1)
            let gridSize: CGFloat = 64
            for x in stride(from: CGFloat(0), through: size.width, by: gridSize) {
                ctx.cgContext.move(to: CGPoint(x: x, y: 0))
                ctx.cgContext.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat(0), through: size.height, by: gridSize) {
                ctx.cgContext.move(to: CGPoint(x: 0, y: y))
                ctx.cgContext.addLine(to: CGPoint(x: size.width, y: y))
            }
            ctx.cgContext.strokePath()
        }
    }
}
