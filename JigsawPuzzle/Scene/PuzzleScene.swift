import SpriteKit
import UIKit
import AudioToolbox

protocol PuzzleSceneDelegate: AnyObject {
    func puzzleScene(_ scene: PuzzleScene, didUpdateProgress placed: Int, of total: Int)
    func puzzleSceneDidComplete(_ scene: PuzzleScene, time: TimeInterval)
}

class PuzzleScene: SKScene {
    weak var puzzleDelegate: PuzzleSceneDelegate?

    private var cameraNode = SKCameraNode()
    private var allGroups: [PieceGroupNode] = []
    private var pieceMap: [PieceID: PuzzlePieceNode] = [:]
    private var groupMap: [PieceID: PieceGroupNode] = [:]  // pieceID -> group

    private let snapManager = SnapManager(
        snapThresholdRatio: 0.2,
        rotationThreshold: 10,
        maxSnapVelocity: 500
    )

    private var totalPieces: Int = 0
    private var startTime: Date?

    // Touch state
    private var activePieceGroup: PieceGroupNode?
    private var touchOffset: CGPoint = .zero
    private var lastTouchPosition: CGPoint = .zero
    private var lastTouchTime: TimeInterval = 0
    private var currentVelocity: CGVector = .zero
    private var isPanning: Bool = false
    private var initialPinchScale: CGFloat = 1.0

    // Ghost outline
    private var ghostNode: SKSpriteNode?

    // MARK: - Setup

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupGestureRecognizers()
    }

    func setupPuzzle(image: UIImage, pieceCount: Int, puzzleID: String = "") {
        backgroundColor = SKColor(white: 0.15, alpha: 1.0)

        // Setup camera
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Cut the puzzle — deterministic seed from puzzle ID + piece count
        let seedString = "\(puzzleID)_\(pieceCount)"
        var hasher = Hasher()
        hasher.combine(seedString)
        let seed = UInt64(bitPattern: Int64(hasher.finalize()))
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: pieceCount, seed: seed)
        totalPieces = pieces.count

        // Compute puzzle dimensions for ghost outline
        if let firstPiece = pieces.first {
            let grid = GridComputer.computeGrid(pieceCount: pieceCount, imageWidth: image.size.width, imageHeight: image.size.height)
            let puzzleWidth = firstPiece.pieceSize.width * CGFloat(grid.cols)
            let puzzleHeight = firstPiece.pieceSize.height * CGFloat(grid.rows)

            // Add ghost outline
            let ghostTexture = SKTexture(image: image)
            ghostNode = SKSpriteNode(texture: ghostTexture, size: CGSize(width: puzzleWidth, height: puzzleHeight))
            ghostNode?.position = CGPoint(x: puzzleWidth / 2, y: puzzleHeight / 2)
            ghostNode?.alpha = 0.2
            ghostNode?.zPosition = -100
            addChild(ghostNode!)

            // Center camera on puzzle
            cameraNode.position = CGPoint(x: puzzleWidth / 2, y: puzzleHeight / 2)
        }

        // Create piece nodes and groups, scatter them
        let scatterMargin: CGFloat = 200
        for cutPiece in pieces {
            let pieceNode = PuzzlePieceNode(cutPiece: cutPiece)
            pieceMap[cutPiece.id] = pieceNode

            // Each piece starts in its own group
            let group = PieceGroupNode()
            group.name = "group_\(cutPiece.id)"
            group.addPiece(pieceNode, at: .zero)

            // Random scatter position around the puzzle area
            let puzzleArea = ghostNode?.frame ?? CGRect(x: 0, y: 0, width: size.width, height: size.height)
            let randomX = CGFloat.random(in: (puzzleArea.minX - scatterMargin)...(puzzleArea.maxX + scatterMargin))
            let randomY = CGFloat.random(in: (puzzleArea.minY - scatterMargin)...(puzzleArea.maxY + scatterMargin))
            group.position = CGPoint(x: randomX, y: randomY)

            // Random rotation (0, 90, 180, 270)
            let randomRotation = CGFloat([0, 90, 180, 270].randomElement()!)
            pieceNode.rotationDegrees = randomRotation

            addChild(group)
            allGroups.append(group)
            groupMap[cutPiece.id] = group
        }

        startTime = Date()
    }

    // MARK: - Victory

    private func checkVictory() {
        let unlockedGroups = allGroups.filter { !$0.isLockedToBoard && !$0.pieces.isEmpty }

        if unlockedGroups.isEmpty {
            triggerVictory()
            return
        }

        if unlockedGroups.count == 1 {
            let group = unlockedGroups[0]
            if group.pieces.count == totalPieces {
                // Verify the group is near the correct board position
                // Check any piece's world position against its correct position
                if let anyPiece = group.pieces.first {
                    let worldPos = anyPiece.convert(.zero, to: self)
                    let pieceSize = anyPiece.size
                    let threshold = max(pieceSize.width, pieceSize.height) * 0.3
                    let distance = sqrt(
                        pow(worldPos.x - anyPiece.correctPosition.x, 2) +
                        pow(worldPos.y - anyPiece.correctPosition.y, 2)
                    )
                    if distance < threshold {
                        group.lockToBoard()
                        triggerVictory()
                        return
                    }
                }
            }
        }
    }

    private func triggerVictory() {
        let elapsed = Date().timeIntervalSince(startTime ?? Date())

        // Fade out piece edges
        for group in allGroups {
            for piece in group.pieces {
                piece.run(SKAction.fadeAlpha(to: 0, duration: 0.5))
            }
        }

        // Show clean image
        if let ghost = ghostNode {
            ghost.run(SKAction.fadeAlpha(to: 1.0, duration: 0.5))
        }

        // Confetti particle effect
        if let confetti = createConfettiEmitter() {
            confetti.position = CGPoint(x: 0, y: size.height / 2)
            confetti.zPosition = 2000
            cameraNode.addChild(confetti)

            confetti.run(SKAction.sequence([
                SKAction.wait(forDuration: 3.0),
                SKAction.removeFromParent()
            ]))
        }

        generateSuccessHaptic()
        puzzleDelegate?.puzzleSceneDidComplete(self, time: elapsed)
    }

    private func createConfettiEmitter() -> SKEmitterNode? {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 200
        emitter.numParticlesToEmit = 600
        emitter.particleLifetime = 3.0
        emitter.particleLifetimeRange = 1.0
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = 300
        emitter.particleSpeedRange = 150
        emitter.yAcceleration = -300
        emitter.particleSize = CGSize(width: 8, height: 8)
        emitter.particleSizeRange = CGSize(width: 4, height: 4)
        emitter.particleColorBlendFactor = 1.0
        emitter.particleColorSequence = nil
        emitter.particleColor = .systemYellow
        emitter.particleColorRedRange = 0.5
        emitter.particleColorGreenRange = 0.5
        emitter.particleColorBlueRange = 0.5
        emitter.particleAlphaSpeed = -0.3
        emitter.particleRotationRange = .pi * 2
        return emitter
    }

    // MARK: - Snap Logic Integration

    private func handlePieceRelease(group: PieceGroupNode) {
        guard !group.isLockedToBoard else { return }

        let pieceSize = pieceMap.values.first?.size ?? CGSize(width: 100, height: 100)

        // Check board lock first (for each piece in group)
        for piece in group.pieces {
            let worldPos = piece.convert(.zero, to: self)
            if snapManager.shouldBoardLock(
                piecePosition: worldPos,
                correctPosition: piece.correctPosition,
                pieceRotation: piece.rotationDegrees,
                velocity: currentVelocity,
                pieceSize: pieceSize
            ) {
                let moveX = piece.correctPosition.x - worldPos.x
                let moveY = piece.correctPosition.y - worldPos.y
                group.run(SKAction.moveBy(x: moveX, y: moveY, duration: 0.15)) {
                    group.lockToBoard()
                    self.updateProgress()
                    self.generateHaptic(style: .medium)
                    AudioServicesPlaySystemSound(1104)
                    self.checkVictory()
                }
                return
            }
        }

        // Check snap to neighbors
        for (piece, edge, neighborID) in group.exposedEdges {
            guard let neighborPiece = pieceMap[neighborID],
                  let neighborGroup = groupMap[neighborID],
                  neighborGroup !== group else { continue }

            let pieceWorldPos = piece.convert(.zero, to: self)
            let neighborWorldPos = neighborPiece.convert(.zero, to: self)

            // Calculate where the piece SHOULD be relative to neighbor
            let targetOffset = targetOffsetForEdge(edge, pieceSize: pieceSize)
            let targetPos = CGPoint(
                x: neighborWorldPos.x + targetOffset.x,
                y: neighborWorldPos.y + targetOffset.y
            )

            if snapManager.shouldSnap(
                piecePosition: pieceWorldPos,
                targetPosition: targetPos,
                pieceRotation: piece.rotationDegrees,
                targetRotation: neighborPiece.rotationDegrees,
                velocity: currentVelocity,
                pieceSize: pieceSize
            ) {
                let moveOffset = CGPoint(
                    x: targetPos.x - pieceWorldPos.x,
                    y: targetPos.y - pieceWorldPos.y
                )

                let snapAction = SKAction.moveBy(x: moveOffset.x, y: moveOffset.y, duration: 0.15)
                snapAction.timingMode = .easeOut
                group.run(snapAction) {
                    if group.pieces.count >= neighborGroup.pieces.count {
                        group.merge(otherGroup: neighborGroup)
                        self.allGroups.removeAll { $0 === neighborGroup }
                        for p in group.pieces {
                            self.groupMap[p.pieceID] = group
                        }
                    } else {
                        neighborGroup.merge(otherGroup: group)
                        self.allGroups.removeAll { $0 === group }
                        for p in neighborGroup.pieces {
                            self.groupMap[p.pieceID] = neighborGroup
                        }
                    }
                    self.generateHaptic(style: .medium)
                    AudioServicesPlaySystemSound(1104)
                    self.updateProgress()
                    self.checkVictory()
                }
                return
            }
        }
    }

    private func targetOffsetForEdge(_ edge: Edge, pieceSize: CGSize) -> CGPoint {
        switch edge {
        case .top: return CGPoint(x: 0, y: pieceSize.height)
        case .bottom: return CGPoint(x: 0, y: -pieceSize.height)
        case .left: return CGPoint(x: -pieceSize.width, y: 0)
        case .right: return CGPoint(x: pieceSize.width, y: 0)
        }
    }

    private func updateProgress() {
        var placed = 0
        for group in allGroups {
            if group.isLockedToBoard {
                placed += group.pieces.count
            }
        }
        puzzleDelegate?.puzzleScene(self, didUpdateProgress: placed, of: totalPieces)
    }

    // MARK: - Haptics

    private func generateHaptic(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    private func generateSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Touch Handling

extension PuzzleScene {

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Check if touch is on a piece/group
        let touchedNodes = nodes(at: location)
        for node in touchedNodes {
            if let piece = node as? PuzzlePieceNode,
               let group = piece.parent as? PieceGroupNode,
               !group.isLockedToBoard {
                activePieceGroup = group
                touchOffset = CGPoint(
                    x: group.position.x - location.x,
                    y: group.position.y - location.y
                )
                lastTouchPosition = location
                lastTouchTime = touch.timestamp
                currentVelocity = .zero
                group.liftUp()
                generateHaptic(style: .light)
                return
            }
        }

        // Touch on empty canvas — start panning
        isPanning = true
        lastTouchPosition = location
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let group = activePieceGroup {
            group.position = CGPoint(
                x: location.x + touchOffset.x,
                y: location.y + touchOffset.y
            )

            // Track velocity
            let dt = touch.timestamp - lastTouchTime
            if dt > 0 {
                currentVelocity = CGVector(
                    dx: (location.x - lastTouchPosition.x) / CGFloat(dt),
                    dy: (location.y - lastTouchPosition.y) / CGFloat(dt)
                )
            }
            lastTouchPosition = location
            lastTouchTime = touch.timestamp

        } else if isPanning {
            let previousLocation = touch.previousLocation(in: self)
            let dx = location.x - previousLocation.x
            let dy = location.y - previousLocation.y
            cameraNode.position = CGPoint(
                x: cameraNode.position.x - dx,
                y: cameraNode.position.y - dy
            )
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let group = activePieceGroup {
            group.putDown()

            for piece in group.pieces {
                piece.snapRotation()
            }

            handlePieceRelease(group: group)
            activePieceGroup = nil
        }
        isPanning = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let group = activePieceGroup {
            group.putDown()
            activePieceGroup = nil
        }
        isPanning = false
    }
}

// MARK: - Gesture Recognizers

extension PuzzleScene {

    func setupGestureRecognizers() {
        guard let view = view else { return }

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        view.addGestureRecognizer(rotation)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            initialPinchScale = cameraNode.xScale
        case .changed:
            let newScale = initialPinchScale / gesture.scale
            let clampedScale = min(max(newScale, 0.3), 3.0)
            cameraNode.setScale(clampedScale)
        default:
            break
        }
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        guard let group = activePieceGroup else { return }

        switch gesture.state {
        case .changed:
            // Rotate the group node itself so all pieces maintain their relative positions
            group.zRotation -= gesture.rotation
            gesture.rotation = 0
        case .ended:
            // Snap group rotation to nearest 90 degrees
            let currentDegrees = group.zRotation * 180 / .pi
            let nearest90 = (currentDegrees / 90).rounded() * 90
            let targetRadians = nearest90 * .pi / 180
            let snapAction = SKAction.rotate(toAngle: targetRadians, duration: 0.2, shortestUnitArc: true)
            snapAction.timingMode = .easeOut
            group.run(snapAction)
            // Update piece rotation tracking to match group rotation
            for piece in group.pieces {
                piece.rotationDegrees = nearest90
            }
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = view else { return }
        let location = gesture.location(in: view)
        let sceneLocation = convertPoint(fromView: location)

        let touchedNodes = nodes(at: sceneLocation)
        for node in touchedNodes {
            if let piece = node as? PuzzlePieceNode,
               let group = piece.parent as? PieceGroupNode,
               !group.isLockedToBoard {
                // Rotate the group node 90 degrees clockwise
                let currentDegrees = group.zRotation * 180 / .pi
                let targetDegrees = currentDegrees - 90
                let targetRadians = targetDegrees * .pi / 180
                let rotateAction = SKAction.rotate(toAngle: targetRadians, duration: 0.15, shortestUnitArc: true)
                rotateAction.timingMode = .easeOut
                group.run(rotateAction)
                for p in group.pieces {
                    p.rotationDegrees += 90
                }
                generateHaptic(style: .light)
                return
            }
        }
    }
}
