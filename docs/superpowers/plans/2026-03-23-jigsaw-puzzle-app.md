# Jigsaw Puzzle App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS jigsaw puzzle app that slices images into interlocking pieces and lets users assemble them with snap-to-connect gameplay.

**Architecture:** SpriteKit-centric — SwiftUI for menu/HUD, SpriteKit for all gameplay. A pure-Swift puzzle engine (no UI deps) handles cutting, edge generation, and snap logic. The engine is unit-testable; SpriteKit integration is verified manually and with lightweight scene tests.

**Tech Stack:** Swift, iOS 17+, SpriteKit, SwiftUI, XCTest

---

## File Structure

```
JigsawPuzzle/
├── JigsawPuzzleApp.swift              # App entry point, navigation
├── Models/
│   ├── PuzzleTypes.swift              # EdgeType, PieceEdges, PieceMetadata, PuzzleConfig, Edge, PieceID
│   └── PuzzleCatalog.swift            # Static list of 6 bundled puzzles (name, image, category)
├── Engine/
│   ├── GridComputer.swift             # Computes best-fit rows×cols from piece count + aspect ratio
│   ├── EdgeGenerator.swift            # Creates tab/socket bezier curves, seeded RNG
│   ├── PathAssembler.swift            # Builds closed CGPath per piece from 4 edges
│   ├── TextureClipper.swift           # Clips source image to piece path, adds stroke/shadow
│   ├── PuzzleCutter.swift             # Orchestrates grid→edges→paths→textures pipeline
│   └── SnapManager.swift              # Proximity, rotation, velocity checks; group merge logic
├── Scene/
│   ├── PuzzlePieceNode.swift          # SKSpriteNode subclass with metadata, edge info, rotation
│   ├── PieceGroupNode.swift           # SKNode parent for locked pieces, exposed edge tracking
│   └── PuzzleScene.swift              # Main SKScene: camera, touch routing, snap integration, victory
├── Views/
│   ├── HomeView.swift                 # 2-col puzzle grid, piece count selector, navigation
│   ├── PuzzleContainerView.swift      # SpriteView bridge + HUD overlay (timer, progress, back)
│   └── VictoryOverlayView.swift       # Congratulations overlay with stats
├── Assets.xcassets/
│   └── Puzzles/                       # 6 bundled puzzle images
└── Tests/
    ├── GridComputerTests.swift
    ├── EdgeGeneratorTests.swift
    ├── PathAssemblerTests.swift
    ├── TextureClipperTests.swift
    ├── SnapManagerTests.swift
    └── PuzzleCutterTests.swift
```

---

### Task 1: Xcode Project Setup

**Files:**
- Create: `JigsawPuzzle.xcodeproj` (via Xcode project generation)
- Create: `JigsawPuzzle/JigsawPuzzleApp.swift`
- Create: `JigsawPuzzle/ContentView.swift` (temporary, replaced later)

- [ ] **Step 1: Create the Xcode project**

Create a new iOS App project using Swift Package structure or manual Xcode project:

```bash
mkdir -p JigsawPuzzle/JigsawPuzzle
mkdir -p JigsawPuzzle/JigsawPuzzleTests
```

Create `JigsawPuzzle/JigsawPuzzle/JigsawPuzzleApp.swift`:
```swift
import SwiftUI

@main
struct JigsawPuzzleApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Jigsaw Puzzle")
                .font(.largeTitle)
        }
    }
}
```

- [ ] **Step 2: Create the Xcode project file**

Use `swift package init` or create the project via Xcode CLI. The project needs:
- iOS 17.0 deployment target
- SwiftUI App lifecycle
- SpriteKit framework linked
- A test target `JigsawPuzzleTests`

Generate a `Package.swift` for SPM-based build:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JigsawPuzzle",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "JigsawPuzzleEngine", targets: ["JigsawPuzzleEngine"]),
    ],
    targets: [
        .target(
            name: "JigsawPuzzleEngine",
            path: "JigsawPuzzle/Engine"
        ),
        .testTarget(
            name: "JigsawPuzzleTests",
            dependencies: ["JigsawPuzzleEngine"],
            path: "JigsawPuzzle/Tests"
        ),
    ]
)
```

Note: The full app requires an Xcode project for SpriteKit/SwiftUI. The SPM package covers the engine for unit testing. Create the Xcode project via `xcodebuild` or Xcode, with the engine files included.

- [ ] **Step 3: Verify the project builds**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: initialize Xcode project with iOS 17 target"
```

---

### Task 2: Data Models

**Files:**
- Create: `JigsawPuzzle/Models/PuzzleTypes.swift`
- Create: `JigsawPuzzle/Models/PuzzleCatalog.swift`

- [ ] **Step 1: Create PuzzleTypes.swift**

```swift
import CoreGraphics
import UIKit

typealias PieceID = Int

enum Edge: CaseIterable {
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

enum EdgeType {
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
```

- [ ] **Step 2: Create PuzzleCatalog.swift**

```swift
import Foundation

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
}
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add JigsawPuzzle/Models/
git commit -m "feat: add puzzle data models and catalog"
```

---

### Task 3: Grid Computer

**Files:**
- Create: `JigsawPuzzle/Engine/GridComputer.swift`
- Create: `JigsawPuzzle/Tests/GridComputerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import JigsawPuzzleEngine

final class GridComputerTests: XCTestCase {

    func testSquareImageWith48Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 48,
            imageWidth: 1000,
            imageHeight: 1000
        )
        XCTAssertEqual(rows * cols, 49, "Should pick closest grid to 48 for square image")
        // 7x7=49 is closest to 48 for a 1:1 ratio
    }

    func testLandscapeImageWith48Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 48,
            imageWidth: 2000,
            imageHeight: 1500
        )
        // 4:3 aspect → 8x6=48 is a perfect fit
        XCTAssertEqual(rows, 6)
        XCTAssertEqual(cols, 8)
        XCTAssertEqual(rows * cols, 48)
    }

    func testSmall10Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 10,
            imageWidth: 1600,
            imageHeight: 1200
        )
        // Should produce a small grid near 10 pieces
        let total = rows * cols
        XCTAssertTrue(total >= 8 && total <= 12, "Should be close to 10, got \(total)")
        XCTAssertTrue(rows >= 2 && cols >= 2, "Must have at least 2 rows and cols")
    }

    func testMax100Pieces() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 100,
            imageWidth: 1920,
            imageHeight: 1080
        )
        let total = rows * cols
        XCTAssertTrue(total >= 90 && total <= 110, "Should be close to 100, got \(total)")
    }

    func testMinimumGrid() {
        let (rows, cols) = GridComputer.computeGrid(
            pieceCount: 2,
            imageWidth: 500,
            imageHeight: 500
        )
        XCTAssertTrue(rows >= 2 && cols >= 2, "Minimum grid is 2x2")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `GridComputer` not defined

- [ ] **Step 3: Implement GridComputer**

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All GridComputerTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/GridComputer.swift JigsawPuzzle/Tests/GridComputerTests.swift
git commit -m "feat: add grid computer with best-fit algorithm"
```

---

### Task 4: Edge Generator

**Files:**
- Create: `JigsawPuzzle/Engine/EdgeGenerator.swift`
- Create: `JigsawPuzzle/Tests/EdgeGeneratorTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import JigsawPuzzleEngine

final class EdgeGeneratorTests: XCTestCase {

    func testBorderEdgesAreFlat() {
        let generator = EdgeGenerator(rows: 4, cols: 6, seed: 42)
        let edges = generator.generateAllEdges()

        // Top row, top edge should be flat
        for col in 0..<6 {
            XCTAssertEqual(edges[0][col].top, .flat, "Top border should be flat at col \(col)")
        }
        // Bottom row, bottom edge should be flat
        for col in 0..<6 {
            XCTAssertEqual(edges[3][col].bottom, .flat, "Bottom border should be flat at col \(col)")
        }
        // Left col, left edge should be flat
        for row in 0..<4 {
            XCTAssertEqual(edges[row][0].left, .flat, "Left border should be flat at row \(row)")
        }
        // Right col, right edge should be flat
        for row in 0..<4 {
            XCTAssertEqual(edges[row][5].right, .flat, "Right border should be flat at row \(row)")
        }
    }

    func testNeighborEdgesAreComplementary() {
        let generator = EdgeGenerator(rows: 4, cols: 6, seed: 42)
        let edges = generator.generateAllEdges()

        // Horizontal neighbors: piece[r][c].right == complement of piece[r][c+1].left
        for row in 0..<4 {
            for col in 0..<5 {
                let rightEdge = edges[row][col].right
                let leftEdge = edges[row][col + 1].left
                XCTAssertEqual(rightEdge.complement, leftEdge,
                    "Horizontal mismatch at (\(row),\(col))-(\(row),\(col+1))")
            }
        }

        // Vertical neighbors: piece[r][c].bottom == complement of piece[r+1][c].top
        for row in 0..<3 {
            for col in 0..<6 {
                let bottomEdge = edges[row][col].bottom
                let topEdge = edges[row + 1][col].top
                XCTAssertEqual(bottomEdge.complement, topEdge,
                    "Vertical mismatch at (\(row),\(col))-(\(row+1),\(col))")
            }
        }
    }

    func testDeterministicWithSameSeed() {
        let gen1 = EdgeGenerator(rows: 3, cols: 3, seed: 123)
        let gen2 = EdgeGenerator(rows: 3, cols: 3, seed: 123)
        let edges1 = gen1.generateAllEdges()
        let edges2 = gen2.generateAllEdges()

        for row in 0..<3 {
            for col in 0..<3 {
                XCTAssertEqual(edges1[row][col].top, edges2[row][col].top)
                XCTAssertEqual(edges1[row][col].right, edges2[row][col].right)
                XCTAssertEqual(edges1[row][col].bottom, edges2[row][col].bottom)
                XCTAssertEqual(edges1[row][col].left, edges2[row][col].left)
            }
        }
    }

    func testDifferentSeedsProduceDifferentResults() {
        let gen1 = EdgeGenerator(rows: 4, cols: 4, seed: 1)
        let gen2 = EdgeGenerator(rows: 4, cols: 4, seed: 2)
        let edges1 = gen1.generateAllEdges()
        let edges2 = gen2.generateAllEdges()

        var anyDifferent = false
        for row in 0..<4 {
            for col in 0..<4 {
                if edges1[row][col].right != edges2[row][col].right {
                    anyDifferent = true
                }
            }
        }
        XCTAssertTrue(anyDifferent, "Different seeds should produce different edge layouts")
    }

    func testInternalEdgesAreTabOrSocket() {
        let generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let edges = generator.generateAllEdges()

        // Internal edges (not borders) must be tab or socket, never flat
        for row in 0..<3 {
            for col in 0..<3 {
                if row > 0 {
                    XCTAssertNotEqual(edges[row][col].top, .flat, "Internal top edge should not be flat")
                }
                if col < 2 {
                    XCTAssertNotEqual(edges[row][col].right, .flat, "Internal right edge should not be flat")
                }
                if row < 2 {
                    XCTAssertNotEqual(edges[row][col].bottom, .flat, "Internal bottom edge should not be flat")
                }
                if col > 0 {
                    XCTAssertNotEqual(edges[row][col].left, .flat, "Internal left edge should not be flat")
                }
            }
        }
    }

    func testBezierPathGeneration() {
        let generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let path = generator.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100))
        XCTAssertFalse(path.isEmpty, "Bezier path should not be empty")
    }

    func testSocketPathIsInverse() {
        let generator = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let tabBounds = generator.bezierPath(for: .tab, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100)).boundingBoxOfPath
        let socketBounds = generator.bezierPath(for: .socket, alongEdge: .right, pieceSize: CGSize(width: 100, height: 100)).boundingBoxOfPath

        // Tab should extend outward (wider bounding box than socket on the relevant axis)
        XCTAssertGreaterThan(tabBounds.width, 0)
        XCTAssertGreaterThan(socketBounds.width, 0)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `EdgeGenerator` not defined

- [ ] **Step 3: Implement EdgeGenerator**

```swift
import CoreGraphics

struct EdgeGenerator {
    let rows: Int
    let cols: Int
    private var rng: SeededRandomNumberGenerator

    init(rows: Int, cols: Int, seed: UInt64) {
        self.rows = rows
        self.cols = cols
        self.rng = SeededRandomNumberGenerator(seed: seed)
    }

    /// Generate edge types for all pieces in the grid.
    /// Returns a 2D array [row][col] of PieceEdges.
    mutating func generateAllEdges() -> [[PieceEdges]] {
        // Horizontal edges: between [row][col] right and [row][col+1] left
        // Store as the "right" edge of the left piece (tab or socket)
        var horizontalEdges: [[EdgeType]] = Array(
            repeating: Array(repeating: EdgeType.flat, count: cols - 1),
            count: rows
        )
        for row in 0..<rows {
            for col in 0..<(cols - 1) {
                horizontalEdges[row][col] = Bool.random(using: &rng) ? .tab : .socket
            }
        }

        // Vertical edges: between [row][col] bottom and [row+1][col] top
        // Store as the "bottom" edge of the top piece
        var verticalEdges: [[EdgeType]] = Array(
            repeating: Array(repeating: EdgeType.flat, count: cols),
            count: rows - 1
        )
        for row in 0..<(rows - 1) {
            for col in 0..<cols {
                verticalEdges[row][col] = Bool.random(using: &rng) ? .tab : .socket
            }
        }

        // Assemble PieceEdges for each piece
        var result: [[PieceEdges]] = []
        for row in 0..<rows {
            var rowEdges: [PieceEdges] = []
            for col in 0..<cols {
                let top: EdgeType = row == 0 ? .flat : verticalEdges[row - 1][col].complement
                let bottom: EdgeType = row == rows - 1 ? .flat : verticalEdges[row][col]
                let left: EdgeType = col == 0 ? .flat : horizontalEdges[row][col - 1].complement
                let right: EdgeType = col == cols - 1 ? .flat : horizontalEdges[row][col]

                rowEdges.append(PieceEdges(top: top, right: right, bottom: bottom, left: left))
            }
            result.append(rowEdges)
        }

        return result
    }

    /// Generate a bezier CGPath for a tab or socket along the given edge of a piece.
    /// The path starts at the edge's start point and ends at the edge's end point.
    /// For .flat, returns a straight line.
    func bezierPath(for edgeType: EdgeType, alongEdge edge: Edge, pieceSize: CGSize) -> CGPath {
        let path = CGMutablePath()
        let w = pieceSize.width
        let h = pieceSize.height

        // Tab parameters
        let tabHeight: CGFloat = 0.2  // proportion of piece size
        let tabWidth: CGFloat = 0.3   // proportion of edge length
        let neckWidth: CGFloat = 0.2  // proportion of edge length

        switch edge {
        case .right:
            let startY: CGFloat = 0
            let endY: CGFloat = h
            let edgeX: CGFloat = w
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? 1 : -1

            let tabH = w * tabHeight * direction
            let neckStart = edgeLen * (0.5 - neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + tabWidth / 2)

            path.move(to: CGPoint(x: edgeX, y: startY))
            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart + edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart - edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * 1.2, y: bulgeStart + edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * 1.2, y: bulgeEnd - edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd + edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd - edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: endY))

        case .left:
            let startY: CGFloat = h
            let endY: CGFloat = 0
            let edgeX: CGFloat = 0
            let edgeLen = h
            let direction: CGFloat = edgeType == .tab ? -1 : 1

            let tabH = w * tabHeight * direction
            let neckStart = edgeLen * (0.5 + neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - tabWidth / 2)

            path.move(to: CGPoint(x: edgeX, y: startY))
            path.addLine(to: CGPoint(x: edgeX, y: neckStart))
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeStart),
                control1: CGPoint(x: edgeX, y: neckStart - edgeLen * 0.02),
                control2: CGPoint(x: edgeX + tabH, y: bulgeStart + edgeLen * 0.02)
            )
            path.addCurve(
                to: CGPoint(x: edgeX + tabH, y: bulgeEnd),
                control1: CGPoint(x: edgeX + tabH * 1.2, y: bulgeStart - edgeLen * 0.05),
                control2: CGPoint(x: edgeX + tabH * 1.2, y: bulgeEnd + edgeLen * 0.05)
            )
            path.addCurve(
                to: CGPoint(x: edgeX, y: neckEnd),
                control1: CGPoint(x: edgeX + tabH, y: bulgeEnd - edgeLen * 0.02),
                control2: CGPoint(x: edgeX, y: neckEnd + edgeLen * 0.02)
            )
            path.addLine(to: CGPoint(x: edgeX, y: endY))

        case .top:
            let startX: CGFloat = 0
            let endX: CGFloat = w
            let edgeY: CGFloat = 0
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? -1 : 1

            let tabH = h * tabHeight * direction
            let neckStart = edgeLen * (0.5 - neckWidth / 2)
            let neckEnd = edgeLen * (0.5 + neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 - tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 + tabWidth / 2)

            path.move(to: CGPoint(x: startX, y: edgeY))
            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart + edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart - edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart + edgeLen * 0.05, y: edgeY + tabH * 1.2),
                control2: CGPoint(x: bulgeEnd - edgeLen * 0.05, y: edgeY + tabH * 1.2)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd + edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd - edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: endX, y: edgeY))

        case .bottom:
            let startX: CGFloat = w
            let endX: CGFloat = 0
            let edgeY: CGFloat = h
            let edgeLen = w
            let direction: CGFloat = edgeType == .tab ? 1 : -1

            let tabH = h * tabHeight * direction
            let neckStart = edgeLen * (0.5 + neckWidth / 2)
            let neckEnd = edgeLen * (0.5 - neckWidth / 2)
            let bulgeStart = edgeLen * (0.5 + tabWidth / 2)
            let bulgeEnd = edgeLen * (0.5 - tabWidth / 2)

            path.move(to: CGPoint(x: startX, y: edgeY))
            path.addLine(to: CGPoint(x: neckStart, y: edgeY))
            path.addCurve(
                to: CGPoint(x: bulgeStart, y: edgeY + tabH),
                control1: CGPoint(x: neckStart - edgeLen * 0.02, y: edgeY),
                control2: CGPoint(x: bulgeStart + edgeLen * 0.02, y: edgeY + tabH)
            )
            path.addCurve(
                to: CGPoint(x: bulgeEnd, y: edgeY + tabH),
                control1: CGPoint(x: bulgeStart - edgeLen * 0.05, y: edgeY + tabH * 1.2),
                control2: CGPoint(x: bulgeEnd + edgeLen * 0.05, y: edgeY + tabH * 1.2)
            )
            path.addCurve(
                to: CGPoint(x: neckEnd, y: edgeY),
                control1: CGPoint(x: bulgeEnd - edgeLen * 0.02, y: edgeY + tabH),
                control2: CGPoint(x: neckEnd + edgeLen * 0.02, y: edgeY)
            )
            path.addLine(to: CGPoint(x: endX, y: edgeY))
        }

        return path
    }
}

/// A simple seeded RNG for deterministic edge generation.
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All EdgeGeneratorTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/EdgeGenerator.swift JigsawPuzzle/Tests/EdgeGeneratorTests.swift
git commit -m "feat: add edge generator with seeded bezier tab/socket curves"
```

---

### Task 5: Path Assembler

**Files:**
- Create: `JigsawPuzzle/Engine/PathAssembler.swift`
- Create: `JigsawPuzzle/Tests/PathAssemblerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import JigsawPuzzleEngine

final class PathAssemblerTests: XCTestCase {

    func testAssembledPathIsClosed() {
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .socket, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            edgeGenerator: edgeGen
        )

        // A closed path should have a non-zero area bounding box
        let bounds = path.boundingBoxOfPath
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }

    func testFlatEdgesProduceRectangle() {
        let edges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let path = PathAssembler.assemblePath(
            for: edges,
            pieceSize: pieceSize,
            edgeGenerator: edgeGen
        )

        let bounds = path.boundingBoxOfPath
        // All flat edges = rectangle, bounding box should match piece size closely
        XCTAssertEqual(bounds.width, pieceSize.width, accuracy: 1.0)
        XCTAssertEqual(bounds.height, pieceSize.height, accuracy: 1.0)
    }

    func testTabEdgeExtendsBoundingBox() {
        let flatEdges = PieceEdges(top: .flat, right: .flat, bottom: .flat, left: .flat)
        let tabEdges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)

        let flatPath = PathAssembler.assemblePath(for: flatEdges, pieceSize: pieceSize, edgeGenerator: edgeGen)
        let tabPath = PathAssembler.assemblePath(for: tabEdges, pieceSize: pieceSize, edgeGenerator: edgeGen)

        // Tab should extend the bounding box beyond the flat version
        XCTAssertGreaterThan(tabPath.boundingBoxOfPath.width, flatPath.boundingBoxOfPath.width)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `PathAssembler` not defined

- [ ] **Step 3: Implement PathAssembler**

```swift
import CoreGraphics

struct PathAssembler {

    /// Assemble a closed CGPath for a puzzle piece from its four edges.
    /// Path is constructed clockwise: top → right → bottom → left.
    static func assemblePath(
        for edges: PieceEdges,
        pieceSize: CGSize,
        edgeGenerator: EdgeGenerator
    ) -> CGPath {
        let path = CGMutablePath()

        // Start at top-left corner (0, 0)
        // Top edge: left to right
        let topPath = edgeGenerator.bezierPath(for: edges.top, alongEdge: .top, pieceSize: pieceSize)
        path.addPath(topPath)

        // Right edge: top to bottom
        let rightPath = edgeGenerator.bezierPath(for: edges.right, alongEdge: .right, pieceSize: pieceSize)
        path.addPath(rightPath)

        // Bottom edge: right to left
        let bottomPath = edgeGenerator.bezierPath(for: edges.bottom, alongEdge: .bottom, pieceSize: pieceSize)
        path.addPath(bottomPath)

        // Left edge: bottom to top
        let leftPath = edgeGenerator.bezierPath(for: edges.left, alongEdge: .left, pieceSize: pieceSize)
        path.addPath(leftPath)

        path.closeSubpath()
        return path
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All PathAssemblerTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/PathAssembler.swift JigsawPuzzle/Tests/PathAssemblerTests.swift
git commit -m "feat: add path assembler for piece outline construction"
```

---

### Task 6: Texture Clipper

**Files:**
- Create: `JigsawPuzzle/Engine/TextureClipper.swift`
- Create: `JigsawPuzzle/Tests/TextureClipperTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import SpriteKit
@testable import JigsawPuzzleEngine

final class TextureClipperTests: XCTestCase {

    func testClipProducesNonNilImage() {
        // Create a simple 200x200 red test image
        let testImage = createTestImage(width: 200, height: 200, color: .red)

        // Simple rectangular clip path
        let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 100, height: 100), transform: nil)

        let result = TextureClipper.clip(
            image: testImage,
            path: clipPath,
            sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100)
        )

        XCTAssertNotNil(result, "Clipped image should not be nil")
    }

    func testClipOutputMatchesBoundingBox() {
        let testImage = createTestImage(width: 400, height: 400, color: .blue)
        let clipPath = CGPath(rect: CGRect(x: 0, y: 0, width: 150, height: 100), transform: nil)

        let result = TextureClipper.clip(
            image: testImage,
            path: clipPath,
            sourceRect: CGRect(x: 50, y: 50, width: 150, height: 100)
        )

        XCTAssertNotNil(result)
        // Output should be at least as large as the clip path bounding box
        XCTAssertGreaterThanOrEqual(Int(result!.size.width), 150)
        XCTAssertGreaterThanOrEqual(Int(result!.size.height), 100)
    }

    func testClipWithTabPath() {
        let testImage = createTestImage(width: 400, height: 400, color: .green)
        let edgeGen = EdgeGenerator(rows: 3, cols: 3, seed: 42)
        let pieceSize = CGSize(width: 100, height: 100)
        let edges = PieceEdges(top: .flat, right: .tab, bottom: .flat, left: .flat)

        let piecePath = PathAssembler.assemblePath(for: edges, pieceSize: pieceSize, edgeGenerator: edgeGen)

        let result = TextureClipper.clip(
            image: testImage,
            path: piecePath,
            sourceRect: CGRect(x: 0, y: 0, width: 100, height: 100)
        )

        XCTAssertNotNil(result, "Should clip with bezier tab path")
        // With a tab, the image should be wider than the base piece size
        XCTAssertGreaterThan(result!.size.width, 100)
    }

    // MARK: - Helpers

    private func createTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `TextureClipper` not defined

- [ ] **Step 3: Implement TextureClipper**

```swift
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

            // Draw edge stroke for visual definition
            context.addPath(path)
            context.setStrokeColor(UIColor.black.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(1.5)
            context.strokePath()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All TextureClipperTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/TextureClipper.swift JigsawPuzzle/Tests/TextureClipperTests.swift
git commit -m "feat: add texture clipper with bezier path masking and edge stroke"
```

---

### Task 7: Puzzle Cutter (Orchestrator)

**Files:**
- Create: `JigsawPuzzle/Engine/PuzzleCutter.swift`
- Create: `JigsawPuzzle/Tests/PuzzleCutterTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
import SpriteKit
@testable import JigsawPuzzleEngine

final class PuzzleCutterTests: XCTestCase {

    func testCutProducesCorrectNumberOfPieces() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        // Grid should be close to 24 pieces
        XCTAssertTrue(pieces.count >= 20 && pieces.count <= 28,
            "Expected ~24 pieces, got \(pieces.count)")
    }

    func testAllPiecesHaveTextures() {
        let image = createTestImage(width: 400, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 16, seed: 42)

        for piece in pieces {
            XCTAssertNotNil(piece.texture, "Piece (\(piece.row),\(piece.col)) should have a texture")
        }
    }

    func testPiecesHaveUniquePositions() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        let positions = pieces.map { "\($0.row),\($0.col)" }
        let uniquePositions = Set(positions)
        XCTAssertEqual(positions.count, uniquePositions.count, "All pieces should have unique grid positions")
    }

    func testPiecesHaveCorrectPositions() {
        let image = createTestImage(width: 400, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 16, seed: 42)

        for piece in pieces {
            // Correct position should be somewhere within the puzzle area
            XCTAssertGreaterThanOrEqual(piece.correctPosition.x, 0)
            XCTAssertGreaterThanOrEqual(piece.correctPosition.y, 0)
        }
    }

    func testNeighborReferencesAreSymmetric() {
        let image = createTestImage(width: 600, height: 400)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: 24, seed: 42)

        let pieceMap: [PieceID: PuzzleCutter.CutPiece] = Dictionary(uniqueKeysWithValues: pieces.map { ($0.id, $0) })

        for piece in pieces {
            for (edge, neighborID) in piece.neighbors {
                guard let neighbor = pieceMap[neighborID] else {
                    XCTFail("Neighbor \(neighborID) not found for piece \(piece.id)")
                    continue
                }
                XCTAssertEqual(neighbor.neighbors[edge.opposite], piece.id,
                    "Neighbor relationship should be symmetric")
            }
        }
    }

    private func createTestImage(width: Int, height: Int) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        return renderer.image { ctx in
            UIColor.orange.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `PuzzleCutter` not defined

- [ ] **Step 3: Implement PuzzleCutter**

```swift
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

        // Build ID map: row,col → PieceID
        var idMap: [[PieceID]] = []
        var nextID = 0
        for row in 0..<rows {
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All PuzzleCutterTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/PuzzleCutter.swift JigsawPuzzle/Tests/PuzzleCutterTests.swift
git commit -m "feat: add puzzle cutter orchestrating the full cutting pipeline"
```

---

### Task 8: Snap Manager

**Files:**
- Create: `JigsawPuzzle/Engine/SnapManager.swift`
- Create: `JigsawPuzzle/Tests/SnapManagerTests.swift`

- [ ] **Step 1: Write failing tests**

```swift
import XCTest
@testable import JigsawPuzzleEngine

final class SnapManagerTests: XCTestCase {

    let pieceSize = CGSize(width: 100, height: 100)

    func testSnapWhenCloseAndAligned() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should snap when close and aligned")
    }

    func testNoSnapWhenTooFar() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 200, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when too far apart")
    }

    func testNoSnapWhenRotationOff() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 45,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when rotation is too far off")
    }

    func testNoSnapWhenMovingTooFast() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 0,
            targetRotation: 0,
            velocity: CGVector(dx: 800, dy: 800),
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not snap when moving too fast")
    }

    func testSnapWithSmallRotationDifference() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldSnap(
            piecePosition: CGPoint(x: 105, y: 0),
            targetPosition: CGPoint(x: 100, y: 0),
            pieceRotation: 5,
            targetRotation: 0,
            velocity: CGVector(dx: 10, dy: 10),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should snap when rotation is within threshold")
    }

    func testBoardLockWhenAtCorrectPosition() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldBoardLock(
            piecePosition: CGPoint(x: 102, y: 98),
            correctPosition: CGPoint(x: 100, y: 100),
            pieceRotation: 2,
            velocity: CGVector(dx: 5, dy: 5),
            pieceSize: pieceSize
        )

        XCTAssertTrue(result, "Should board-lock when at correct position and rotation")
    }

    func testNoBoardLockWhenRotated() {
        let snapManager = SnapManager(snapThresholdRatio: 0.2, rotationThreshold: 10, maxSnapVelocity: 500)

        let result = snapManager.shouldBoardLock(
            piecePosition: CGPoint(x: 100, y: 100),
            correctPosition: CGPoint(x: 100, y: 100),
            pieceRotation: 90,
            velocity: .zero,
            pieceSize: pieceSize
        )

        XCTAssertFalse(result, "Should not board-lock when rotated 90 degrees")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: FAIL — `SnapManager` not defined

- [ ] **Step 3: Implement SnapManager**

```swift
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
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All SnapManagerTests PASS

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/Engine/SnapManager.swift JigsawPuzzle/Tests/SnapManagerTests.swift
git commit -m "feat: add snap manager with proximity, rotation, and velocity checks"
```

---

### Task 9: PuzzlePieceNode

**Files:**
- Create: `JigsawPuzzle/Scene/PuzzlePieceNode.swift`

- [ ] **Step 1: Implement PuzzlePieceNode**

```swift
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
    }

    /// Visual feedback: put piece down
    func putDown() {
        let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
        scaleDown.timingMode = .easeOut
        run(scaleDown, withKey: "lift")
    }

    /// Lock this piece to the board (make immovable, visual feedback)
    func lockToBoard() {
        isLockedToBoard = true
        zPosition = -1
        let brighten = SKAction.colorize(with: .white, colorBlendFactor: 0.1, duration: 0.2)
        run(brighten)
    }
}
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add JigsawPuzzle/Scene/PuzzlePieceNode.swift
git commit -m "feat: add PuzzlePieceNode with lift/drop/snap animations"
```

---

### Task 10: PieceGroupNode

**Files:**
- Create: `JigsawPuzzle/Scene/PieceGroupNode.swift`

- [ ] **Step 1: Implement PieceGroupNode**

```swift
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

        // Account for rotation difference
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
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add JigsawPuzzle/Scene/PieceGroupNode.swift
git commit -m "feat: add PieceGroupNode with merge and exposed edge tracking"
```

---

### Task 11: PuzzleScene — Core Setup and Rendering

**Files:**
- Create: `JigsawPuzzle/Scene/PuzzleScene.swift`

- [ ] **Step 1: Implement PuzzleScene with camera, ghost outline, piece placement**

```swift
import SpriteKit
import UIKit

protocol PuzzleSceneDelegate: AnyObject {
    func puzzleScene(_ scene: PuzzleScene, didUpdateProgress placed: Int, of total: Int)
    func puzzleSceneDidComplete(_ scene: PuzzleScene, time: TimeInterval)
}

class PuzzleScene: SKScene {
    weak var puzzleDelegate: PuzzleSceneDelegate?

    private var cameraNode = SKCameraNode()
    private var allGroups: [PieceGroupNode] = []
    private var pieceMap: [PieceID: PuzzlePieceNode] = [:]
    private var groupMap: [PieceID: PieceGroupNode] = [:]  // pieceID → group

    private let snapManager = SnapManager(
        snapThresholdRatio: 0.2,
        rotationThreshold: 10,
        maxSnapVelocity: 500
    )

    private var puzzleConfig: PuzzleConfig?
    private var totalPieces: Int = 0
    private var lockedPieces: Int = 0
    private var startTime: Date?

    // Touch state
    private var activePieceGroup: PieceGroupNode?
    private var touchOffset: CGPoint = .zero
    private var lastTouchPosition: CGPoint = .zero
    private var lastTouchTime: TimeInterval = 0
    private var currentVelocity: CGVector = .zero
    private var isPanning: Bool = false
    private var initialCameraPosition: CGPoint = .zero
    private var initialPinchScale: CGFloat = 1.0

    // Ghost outline
    private var ghostNode: SKSpriteNode?

    func setupPuzzle(image: UIImage, pieceCount: Int) {
        backgroundColor = SKColor(white: 0.15, alpha: 1.0)

        // Setup camera
        camera = cameraNode
        addChild(cameraNode)
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        // Cut the puzzle
        let seed = UInt64(Date().timeIntervalSince1970)
        let pieces = PuzzleCutter.cut(image: image, requestedPieceCount: pieceCount, seed: seed)
        totalPieces = pieces.count

        // Compute puzzle dimensions for ghost outline
        if let firstPiece = pieces.first {
            let puzzleWidth = firstPiece.pieceSize.width * CGFloat(GridComputer.computeGrid(pieceCount: pieceCount, imageWidth: image.size.width, imageHeight: image.size.height).cols)
            let puzzleHeight = firstPiece.pieceSize.height * CGFloat(GridComputer.computeGrid(pieceCount: pieceCount, imageWidth: image.size.width, imageHeight: image.size.height).rows)

            // Add ghost outline
            let ghostTexture = SKTexture(image: image)
            ghostNode = SKSpriteNode(texture: ghostTexture, size: CGSize(width: puzzleWidth, height: puzzleHeight))
            ghostNode?.position = CGPoint(x: puzzleWidth / 2, y: puzzleHeight / 2)
            ghostNode?.alpha = 0.2
            ghostNode?.zPosition = -100
            addChild(ghostNode!)
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
        // Check if all pieces are in one group and board-locked, or all individually board-locked
        let unlockedGroups = allGroups.filter { !$0.isLockedToBoard && !$0.pieces.isEmpty }

        if unlockedGroups.isEmpty {
            // All locked — victory!
            triggerVictory()
            return
        }

        if unlockedGroups.count == 1 {
            let group = unlockedGroups[0]
            if group.pieces.count == totalPieces {
                // All pieces in one group — check if it's in the right spot
                // For simplicity, auto-lock if all pieces connected
                group.lockToBoard()
                triggerVictory()
                return
            }
        }
    }

    private func triggerVictory() {
        let elapsed = Date().timeIntervalSince(startTime ?? Date())

        // Fade out piece edges — set all pieces to show clean image
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
            confetti.position = CGPoint(x: size.width / 2, y: size.height)
            confetti.zPosition = 2000
            cameraNode.addChild(confetti)

            // Remove after 3 seconds
            confetti.run(SKAction.sequence([
                SKAction.wait(forDuration: 3.0),
                SKAction.removeFromParent()
            ]))
        }

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
                // Animate to correct position
                let targetPos = CGPoint(
                    x: piece.correctPosition.x - group.position.x + piece.position.x,
                    y: piece.correctPosition.y - group.position.y + piece.position.y
                )
                group.run(SKAction.move(to: CGPoint(
                    x: group.position.x + (piece.correctPosition.x - piece.convert(.zero, to: self).x),
                    y: group.position.y + (piece.correctPosition.y - piece.convert(.zero, to: self).y)
                ), duration: 0.15)) {
                    group.lockToBoard()
                    self.lockedPieces = group.pieces.count
                    self.updateProgress()
                    self.generateHaptic(style: .medium)
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
                // Snap! Merge groups
                let moveOffset = CGPoint(
                    x: targetPos.x - pieceWorldPos.x,
                    y: targetPos.y - pieceWorldPos.y
                )

                // Animate snap
                let snapAction = SKAction.moveBy(x: moveOffset.x, y: moveOffset.y, duration: 0.15)
                snapAction.timingMode = .easeOut
                group.run(snapAction) {
                    // Merge smaller group into larger
                    if group.pieces.count >= neighborGroup.pieces.count {
                        group.merge(otherGroup: neighborGroup)
                        self.allGroups.removeAll { $0 === neighborGroup }
                        // Update groupMap
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
                    self.updateProgress()
                    self.checkVictory()
                }
                return  // Only snap to one neighbor per release
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
        // Also count connected pieces (in groups > 1)
        let connectedCount = allGroups.filter { $0.pieces.count > 1 }.reduce(0) { $0 + $1.pieces.count }
        puzzleDelegate?.puzzleScene(self, didUpdateProgress: max(placed, connectedCount), of: totalPieces)
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
```

- [ ] **Step 2: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add JigsawPuzzle/Scene/PuzzleScene.swift
git commit -m "feat: add PuzzleScene with setup, snap integration, and victory detection"
```

---

### Task 12: PuzzleScene — Touch Handling

**Files:**
- Modify: `JigsawPuzzle/Scene/PuzzleScene.swift`

- [ ] **Step 1: Add touch handling methods to PuzzleScene**

Add the following touch handling to `PuzzleScene.swift`:

```swift
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
        initialCameraPosition = cameraNode.position
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        if let group = activePieceGroup {
            // Dragging a piece/group
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
            // Panning the camera
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

            // Snap rotation to nearest 90°
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

// MARK: - Gesture Recognizers (added to view)

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
            let rotationDelta = -gesture.rotation * 180 / .pi
            for piece in group.pieces {
                piece.rotationDegrees += rotationDelta
            }
            gesture.rotation = 0
        case .ended:
            for piece in group.pieces {
                piece.snapRotation()
            }
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        let sceneLocation = convertPoint(fromView: location)

        let touchedNodes = nodes(at: sceneLocation)
        for node in touchedNodes {
            if let piece = node as? PuzzlePieceNode,
               let group = piece.parent as? PieceGroupNode,
               !group.isLockedToBoard {
                // Rotate 90° clockwise
                for p in group.pieces {
                    p.rotationDegrees += 90
                    p.snapRotation()
                }
                generateHaptic(style: .light)
                return
            }
        }
    }
}
```

- [ ] **Step 2: Add `didMove(to:)` to call `setupGestureRecognizers`**

In `PuzzleScene.swift`, add:
```swift
override func didMove(to view: SKView) {
    super.didMove(to: view)
    setupGestureRecognizers()
}
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add JigsawPuzzle/Scene/PuzzleScene.swift
git commit -m "feat: add touch handling with drag, rotate, pinch-zoom, and double-tap"
```

---

### Task 13: Home Screen (SwiftUI)

**Files:**
- Create: `JigsawPuzzle/Views/HomeView.swift`

- [ ] **Step 1: Implement HomeView**

```swift
import SwiftUI

struct HomeView: View {
    @State private var selectedPuzzle: PuzzleInfo?
    @State private var selectedPieceCount: Int = 48
    @State private var isPlayingPuzzle = false

    let pieceCountOptions = [10, 24, 48, 72, 100]

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Jigsaw Puzzle")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Choose a puzzle to play")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(PuzzleCatalog.puzzles) { puzzle in
                            PuzzleCard(puzzle: puzzle, isSelected: selectedPuzzle?.id == puzzle.id)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedPuzzle = puzzle
                                    }
                                }
                        }
                    }
                    .padding(.horizontal)

                    if let puzzle = selectedPuzzle {
                        VStack(spacing: 12) {
                            Text("SELECT PIECE COUNT")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .tracking(1)

                            HStack(spacing: 8) {
                                ForEach(pieceCountOptions, id: \.self) { count in
                                    Button {
                                        selectedPieceCount = count
                                    } label: {
                                        Text("\(count)")
                                            .font(.system(size: 14, weight: selectedPieceCount == count ? .semibold : .regular))
                                            .foregroundColor(selectedPieceCount == count ? .white : .gray)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(selectedPieceCount == count ? Color.purple : Color(white: 0.25))
                                            )
                                    }
                                }
                            }

                            Button {
                                isPlayingPuzzle = true
                            } label: {
                                Text("Start Puzzle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.purple)
                                    )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(white: 0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(white: 0.25), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal)
                        .fullScreenCover(isPresented: $isPlayingPuzzle) {
                            PuzzleContainerView(
                                puzzleInfo: puzzle,
                                pieceCount: selectedPieceCount,
                                onDismiss: { isPlayingPuzzle = false }
                            )
                        }
                    }
                }
                .padding(.top, 20)
            }
            .background(Color(white: 0.1).ignoresSafeArea())
        }
    }
}

struct PuzzleCard: View {
    let puzzle: PuzzleInfo
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Puzzle image preview
            Image(puzzle.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 100)
                .clipped()

            VStack(alignment: .leading, spacing: 2) {
                Text(puzzle.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(puzzle.category)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(10)
        }
        .background(Color(white: 0.17))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
    }
}
```

- [ ] **Step 2: Update JigsawPuzzleApp to use HomeView**

```swift
import SwiftUI

@main
struct JigsawPuzzleApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
        }
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add JigsawPuzzle/Views/HomeView.swift JigsawPuzzle/JigsawPuzzleApp.swift
git commit -m "feat: add home screen with puzzle grid and piece count selector"
```

---

### Task 14: Puzzle Container and HUD

**Files:**
- Create: `JigsawPuzzle/Views/PuzzleContainerView.swift`
- Create: `JigsawPuzzle/Views/VictoryOverlayView.swift`

- [ ] **Step 1: Implement PuzzleContainerView**

```swift
import SwiftUI
import SpriteKit

struct PuzzleContainerView: View {
    let puzzleInfo: PuzzleInfo
    let pieceCount: Int
    let onDismiss: () -> Void

    @StateObject private var viewModel = PuzzleViewModel()

    var body: some View {
        ZStack {
            // SpriteKit scene
            SpriteView(scene: viewModel.scene)
                .ignoresSafeArea()
                .onAppear {
                    if let image = UIImage(named: puzzleInfo.imageName) {
                        viewModel.startPuzzle(image: image, pieceCount: pieceCount)
                    }
                }

            // HUD overlay
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()

                    Spacer()

                    Text(viewModel.timerText)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))

                    Spacer()

                    Text("\(viewModel.placedCount)/\(viewModel.totalCount)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                }
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.6), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 80)
                    .allowsHitTesting(false)
                )

                Spacer()
            }

            // Victory overlay
            if viewModel.isComplete {
                VictoryOverlayView(
                    time: viewModel.completionTime,
                    pieceCount: viewModel.totalCount,
                    onDismiss: onDismiss
                )
            }
        }
    }
}

@MainActor
class PuzzleViewModel: ObservableObject {
    let scene: PuzzleScene

    @Published var placedCount: Int = 0
    @Published var totalCount: Int = 0
    @Published var timerText: String = "0:00"
    @Published var isComplete: Bool = false
    @Published var completionTime: TimeInterval = 0

    private var timer: Timer?

    init() {
        let scene = PuzzleScene(size: UIScreen.main.bounds.size)
        scene.scaleMode = .resizeFill
        self.scene = scene
        scene.puzzleDelegate = self
    }

    func startPuzzle(image: UIImage, pieceCount: Int) {
        scene.setupPuzzle(image: image, pieceCount: pieceCount)
        totalCount = pieceCount

        // Start timer
        let startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(startDate)
                let minutes = Int(elapsed) / 60
                let seconds = Int(elapsed) % 60
                self?.timerText = String(format: "%d:%02d", minutes, seconds)
            }
        }
    }
}

extension PuzzleViewModel: PuzzleSceneDelegate {
    nonisolated func puzzleScene(_ scene: PuzzleScene, didUpdateProgress placed: Int, of total: Int) {
        Task { @MainActor in
            placedCount = placed
            totalCount = total
        }
    }

    nonisolated func puzzleSceneDidComplete(_ scene: PuzzleScene, time: TimeInterval) {
        Task { @MainActor in
            completionTime = time
            isComplete = true
            timer?.invalidate()
        }
    }
}
```

- [ ] **Step 2: Implement VictoryOverlayView**

```swift
import SwiftUI

struct VictoryOverlayView: View {
    let time: TimeInterval
    let pieceCount: Int
    let onDismiss: () -> Void

    var timeText: String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Congratulations!")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "clock")
                        Text("Time: \(timeText)")
                    }
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))

                    HStack {
                        Image(systemName: "puzzlepiece")
                        Text("Pieces: \(pieceCount)")
                    }
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.9))
                }

                Button(action: onDismiss) {
                    Text("Back to Menu")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.purple)
                        )
                }
                .padding(.top, 10)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(white: 0.15))
            )
        }
        .transition(.opacity)
    }
}
```

- [ ] **Step 3: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add JigsawPuzzle/Views/PuzzleContainerView.swift JigsawPuzzle/Views/VictoryOverlayView.swift
git commit -m "feat: add puzzle container with SpriteView bridge, HUD, and victory overlay"
```

---

### Task 15: Puzzle Assets and Integration

**Files:**
- Add: 6 placeholder puzzle images to `Assets.xcassets/`
- Modify: `JigsawPuzzle/Models/PuzzleCatalog.swift` (if image names need adjustment)

- [ ] **Step 1: Add placeholder puzzle images**

Create 6 colorful gradient images (512x384 each) programmatically as placeholders, or download 6 royalty-free images. Add them to `Assets.xcassets` with names: `puzzle_mountain`, `puzzle_ocean`, `puzzle_sunflower`, `puzzle_temple`, `puzzle_safari`, `puzzle_abstract`.

For the POC, you can generate placeholder images in code if no assets are available:

```swift
// Add to PuzzleCatalog.swift
extension PuzzleCatalog {
    /// Generate a placeholder gradient image for a puzzle
    static func placeholderImage(for puzzleID: String, size: CGSize = CGSize(width: 1024, height: 768)) -> UIImage {
        let colors: [String: (UIColor, UIColor)] = [
            "mountain": (.systemRed, .systemOrange),
            "ocean": (.systemCyan, (.systemBlue)),
            "sunflower": (.systemYellow, (.systemOrange)),
            "temple": (.systemPurple, (.systemIndigo)),
            "safari": (.systemGreen, (.systemTeal)),
            "abstract": (.systemPink, (.systemPurple)),
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
```

- [ ] **Step 2: Update PuzzleContainerView to use placeholder if asset not found**

In `PuzzleContainerView.swift`, update the `onAppear`:
```swift
.onAppear {
    let image = UIImage(named: puzzleInfo.imageName)
        ?? PuzzleCatalog.placeholderImage(for: puzzleInfo.id)
    viewModel.startPuzzle(image: image, pieceCount: pieceCount)
}
```

- [ ] **Step 3: Verify it compiles and runs in simulator**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Manual smoke test in simulator**

Launch the app in the iOS Simulator:
- Verify home screen shows 6 puzzle cards
- Tap a card → piece count selector appears
- Tap "Start Puzzle" → SpriteKit scene loads with scattered pieces
- Drag a piece → it moves
- Double-tap a piece → it rotates 90°
- Pinch → camera zooms
- Ghost outline is visible

- [ ] **Step 5: Commit**

```bash
git add JigsawPuzzle/
git commit -m "feat: add placeholder puzzle assets and full app integration"
```

---

### Task 16: Polish — Haptics, Sounds, Animation Refinement

**Files:**
- Modify: `JigsawPuzzle/Scene/PuzzleScene.swift`
- Modify: `JigsawPuzzle/Scene/PuzzlePieceNode.swift`

- [ ] **Step 1: Add snap sound effect**

Create a simple snap sound using `AudioServicesPlaySystemSound` (system sound — no audio file needed):

Add to `PuzzleScene.swift`:
```swift
import AudioToolbox

// In handlePieceRelease, after successful snap:
AudioServicesPlaySystemSound(1104)  // System "tick" sound
```

- [ ] **Step 2: Add success haptic on victory**

In `triggerVictory()`, add:
```swift
generateSuccessHaptic()
```

- [ ] **Step 3: Refine piece shadow on lift**

In `PuzzlePieceNode.liftUp()`, enhance the lift effect:
```swift
func liftUp() {
    let scaleUp = SKAction.scale(to: 1.05, duration: 0.1)
    scaleUp.timingMode = .easeOut
    run(scaleUp, withKey: "lift")
    zPosition = 1000

    // Add shadow
    let shadow = SKShapeNode(rectOf: CGSize(width: size.width * 0.95, height: size.height * 0.95), cornerRadius: 4)
    shadow.fillColor = SKColor.black.withAlphaComponent(0.3)
    shadow.strokeColor = .clear
    shadow.position = CGPoint(x: 4, y: -4)
    shadow.zPosition = -1
    shadow.name = "shadow"
    addChild(shadow)
}

func putDown() {
    let scaleDown = SKAction.scale(to: 1.0, duration: 0.1)
    scaleDown.timingMode = .easeOut
    run(scaleDown, withKey: "lift")

    // Remove shadow
    childNode(withName: "shadow")?.removeFromParent()
}
```

- [ ] **Step 4: Verify it compiles**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 5: Final manual test**

Run in simulator and verify:
- Piece lifts with shadow on drag
- Snap produces haptic + sound
- Double-tap rotates with haptic
- Victory shows confetti, haptic, overlay
- Timer works correctly
- Progress counter updates

- [ ] **Step 6: Commit**

```bash
git add JigsawPuzzle/
git commit -m "feat: add haptics, snap sound, and piece shadow polish"
```

---

### Task 17: Final Integration Test and Cleanup

**Files:**
- All files — review for compilation and consistency

- [ ] **Step 1: Run all unit tests**

```bash
xcodebuild test -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzleTests -destination 'platform=iOS Simulator,name=iPhone 16'
```

Expected: All tests PASS

- [ ] **Step 2: Full build**

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: BUILD SUCCEEDED with no warnings (or only minor ones)

- [ ] **Step 3: End-to-end manual test**

In the simulator:
1. Launch app → home screen with 6 puzzles
2. Select "Mountain Lake" → select 10 pieces → Start
3. Drag pieces, connect two pieces → they snap and group
4. Double-tap to rotate, pinch to zoom, pan the canvas
5. Complete the puzzle → victory confetti + overlay
6. "Back to Menu" → returns to home screen
7. Try again with 48 pieces → verify performance is smooth

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "fix: final integration fixes and cleanup"
```
