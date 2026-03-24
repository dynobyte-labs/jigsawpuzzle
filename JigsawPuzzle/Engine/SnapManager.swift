import CoreGraphics

struct SnapManager {
    let snapThresholdRatio: CGFloat  // proportion of piece size
    let rotationThreshold: CGFloat   // degrees
    let maxSnapVelocity: CGFloat     // points per second

    /// Check if a piece should snap to a neighbor.
    func shouldSnap(
        piecePosition: CGPoint,
        targetPosition: CGPoint,
        pieceRotation: CGFloat,
        targetRotation: CGFloat,
        velocity: CGVector,
        pieceSize: CGSize
    ) -> Bool {
        // Velocity gate
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > maxSnapVelocity { return false }

        // Proximity check
        let threshold = max(pieceSize.width, pieceSize.height) * snapThresholdRatio
        let distance = sqrt(
            pow(piecePosition.x - targetPosition.x, 2) +
            pow(piecePosition.y - targetPosition.y, 2)
        )
        if distance > threshold { return false }

        // Rotation check
        let rotDiff = normalizeAngle(pieceRotation - targetRotation)
        if abs(rotDiff) > rotationThreshold { return false }

        return true
    }

    /// Check if a piece/group should lock to the board at its correct position.
    /// Board lock requires rotation to be near 0 (correct orientation).
    func shouldBoardLock(
        piecePosition: CGPoint,
        correctPosition: CGPoint,
        pieceRotation: CGFloat,
        velocity: CGVector,
        pieceSize: CGSize
    ) -> Bool {
        // Velocity gate
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > maxSnapVelocity { return false }

        // Proximity check
        let threshold = max(pieceSize.width, pieceSize.height) * snapThresholdRatio
        let distance = sqrt(
            pow(piecePosition.x - correctPosition.x, 2) +
            pow(piecePosition.y - correctPosition.y, 2)
        )
        if distance > threshold { return false }

        // Rotation must be near 0 (correct orientation)
        let rotDiff = normalizeAngle(pieceRotation)
        if abs(rotDiff) > rotationThreshold { return false }

        return true
    }

    /// Normalize an angle in degrees to [-180, 180].
    private func normalizeAngle(_ degrees: CGFloat) -> CGFloat {
        var angle = degrees.truncatingRemainder(dividingBy: 360)
        if angle > 180 { angle -= 360 }
        if angle < -180 { angle += 360 }
        return angle
    }
}
