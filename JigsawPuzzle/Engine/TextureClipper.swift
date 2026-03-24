import UIKit
import CoreGraphics

struct TextureClipper {

    /// Clip the source image using the given bezier path.
    /// - Parameters:
    ///   - image: The full puzzle source image
    ///   - path: The piece's bezier outline path (in piece-local coordinates)
    ///   - sourceRect: The rectangle in the source image that this piece covers (before tab/socket extension)
    /// - Returns: A UIImage of the clipped piece with stroke outline, or nil on failure
    static func clip(image: UIImage, path: CGPath, sourceRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let pathBounds = path.boundingBoxOfPath
        // The output image needs to be large enough for the path (including tabs)
        let outputSize = CGSize(
            width: pathBounds.maxX - min(0, pathBounds.minX),
            height: pathBounds.maxY - min(0, pathBounds.minY)
        )

        // Offset to account for tabs extending beyond the base rect
        let offsetX = -min(0, pathBounds.minX)
        let offsetY = -min(0, pathBounds.minY)

        let scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: outputSize)

        return renderer.image { ctx in
            let context = ctx.cgContext

            // Move to account for path offset (tabs extending into negative space)
            context.translateBy(x: offsetX, y: offsetY)

            // Clip to the piece path
            context.addPath(path)
            context.clip()

            // Draw the source image, offset so the correct region shows through the clip
            let drawRect = CGRect(
                x: -sourceRect.origin.x,
                y: -sourceRect.origin.y,
                width: CGFloat(cgImage.width) / scale,
                height: CGFloat(cgImage.height) / scale
            )

            // UIKit draws with flipped Y, UIGraphicsImageRenderer handles this
            UIImage(cgImage: cgImage).draw(in: drawRect)

            // Draw edge stroke with drop shadow for depth
            context.saveGState()
            context.setShadow(offset: CGSize(width: 1, height: -1), blur: 3, color: UIColor.black.withAlphaComponent(0.4).cgColor)
            context.addPath(path)
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(1.5)
            context.strokePath()
            context.restoreGState()
        }
    }
}
