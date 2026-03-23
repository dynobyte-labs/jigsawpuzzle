# Jigsaw Puzzle App — Design Spec

## Overview

A native iOS jigsaw puzzle app that takes prepackaged images, slices them into interlocking pieces, scrambles them on a pannable/zoomable canvas, and lets the user assemble them with snap-to-connect gameplay. The app recognizes when pieces link together, locks them into movable groups, detects correct board placement, and celebrates completion.

**Target:** iOS 17+, Swift, SpriteKit + SwiftUI
**Scope:** POC/MVP — 6 prepackaged puzzles, 10–100 pieces, classic interlocking cuts
**Future (not MVP):** Specialty wood-cut pieces, additional cut shape styles

## Architecture

Three-layer SpriteKit-centric architecture:

### SwiftUI Layer
Handles non-gameplay UI only.

- **HomeView** — 2-column grid of 6 puzzle cards. Each card shows a preview thumbnail, title, and category. Tapping a card reveals a piece count selector (10, 24, 48, 72, 100) and a "Start Puzzle" button.
- **PuzzleContainerView** — Hosts the SpriteKit scene via `SpriteView`. Overlays a SwiftUI HUD with: back button, elapsed timer, progress indicator (e.g. "12/48 placed").

### SpriteKit Layer
All gameplay lives here.

- **PuzzleScene** — The main `SKScene`. Manages an `SKCameraNode` for pan/zoom. Routes touch events to pieces or camera. Runs snap checks on piece release. Triggers victory sequence when complete.
- **PuzzlePieceNode** — `SKSpriteNode` subclass. Holds its bezier-clipped texture, edge connector metadata (tab/socket per side), grid position (row, col), correct world position, and current rotation state.
- **PieceGroupNode** — `SKNode` that parents one or more locked-together `PuzzlePieceNode`s. Moves and rotates as a unit. Tracks its exposed (unconnected) edges for snap detection. When two groups snap, the smaller merges into the larger.

### Puzzle Engine
Pure Swift, no UI dependencies. Can be tested independently.

- **PuzzleCutter** — Orchestrates the cutting pipeline. Takes a source `UIImage` and desired piece count, produces an array of `PuzzlePieceNode`s ready for the scene.
- **EdgeGenerator** — Creates tab/socket bezier curves with randomized parameters (height, width, neck width, curvature). Uses seeded RNG so the same puzzle config always produces the same cuts. Border edges are flat.
- **SnapManager** — Evaluates snap conditions on piece release. Handles proximity detection, rotation validation, velocity gating, and group merge execution.

## Puzzle Cutting Pipeline

### Step 1: Grid Computation
Given a requested piece count and the source image's aspect ratio, compute the best-fit grid dimensions (rows × cols) where the product is closest to the requested count. For example, a 4:3 image at 48 pieces → 8×6 grid. Each grid cell defines a piece's base rectangle.

### Step 2: Edge Generation
For each internal edge in the grid, randomly assign tab (outward bump) or socket (inward bump). One side's tab is the neighboring piece's socket — they are complementary. Border edges (top row top, bottom row bottom, left col left, right col right) are flat straight lines.

Tab/socket shapes are cubic bezier curves with randomized parameters:
- Tab/socket height (how far it protrudes or recedes)
- Tab/socket width
- Neck width (narrower neck = more pronounced knob)
- Curvature variation

Randomization is seeded per puzzle so cuts are deterministic and reproducible.

### Step 3: Path Assembly
For each piece, construct a closed `CGPath` by concatenating its four edges (top, right, bottom, left). Each edge is one of: flat line, tab bezier, or socket bezier. The resulting path is the piece's precise outline.

### Step 4: Texture Clipping
Use the piece's `CGPath` as a clipping mask on the source `CGImage`:
1. Create a `CGContext` sized to the piece's bounding box
2. Translate to account for the piece's position in the source image
3. Clip to the bezier path
4. Draw the source image
5. Add a subtle stroke along the cut edge for visual definition (1-2pt, semi-transparent dark)
6. Add a slight drop shadow along the edge for depth
7. Create an `SKTexture` from the resulting image

### Step 5: Piece Metadata
Each piece stores:
- Grid position (row, col)
- Edge types: top, right, bottom, left — each is `.flat`, `.tab`, or `.socket`
- Correct world position (where it belongs on the completed puzzle)
- Neighbor references (which piece connects on each side)

## Snap & Grouping System

### Snap Detection
Runs on touch-up (piece/group release). Process:

1. **Velocity gate** — if the piece is moving too fast (above a configurable threshold), skip snap check. This prevents accidental connections while flinging pieces.
2. **Edge iteration** — for the released piece/group, iterate all exposed edges (edges not yet connected to another piece).
3. **Neighbor lookup** — for each exposed edge, identify the piece that should connect there (from metadata).
4. **Proximity check** — is the connector point within the snap threshold? Threshold scales with piece size, approximately 15–20% of piece width.
5. **Rotation check** — is the piece within ~10° of the correct relative orientation to its neighbor?
6. **Snap** — if both checks pass, trigger the snap action.

### Snap Action
- Animate the piece smoothly to its exact correct position relative to the neighbor (~0.15s ease-out).
- Play a click sound effect.
- Fire a medium impact haptic.

### Group Merging
When piece A (in group G1) snaps to piece B (in group G2):
1. Determine the larger group (by piece count).
2. Reparent all children of the smaller `PieceGroupNode` into the larger one, adjusting positions to maintain correct spatial relationships.
3. Recalculate exposed edges for the merged group.
4. Remove the now-empty smaller group node.

### Board Lock
Independently of piece-to-piece snapping, when a piece or group is released:
1. Check if it is near its correct absolute position on the canvas.
2. Check if it is at the correct rotation.
3. If both pass, lock it to the board:
   - Position snaps to exact correct location (animated).
   - Piece/group becomes immovable (touch interactions pass through).
   - Visual feedback: slight brightness increase.
   - Z-position drops to background layer so other pieces render on top.
   - Locked pieces serve as anchoring points for the player.

### Victory Detection
After every successful snap or board lock:
1. Check if there is exactly one group containing all pieces.
2. Check if that group is in the correct board position (or all pieces are board-locked).
3. If complete → trigger victory sequence.

## Touch Handling & Gestures

### Piece Interaction
- **Single-finger drag** — move a piece/group. On pickup: scale up slightly (~1.05x), add drop shadow, raise z-position to top. On release: restore scale, run snap checks.
- **Two-finger rotation** — rotate the held piece/group freely. On release: spring-animate to nearest 90° increment.
- **Double-tap** — quick-rotate 90° clockwise (shortcut for rotation).

### Canvas Navigation
- **Two-finger pan** (on empty canvas) — pan the `SKCameraNode`.
- **Pinch** (on empty canvas) — zoom the camera. Clamped to min/max zoom levels.

### Touch Disambiguation
- If touch begins on a piece → piece interaction mode.
- If touch begins on empty canvas → camera navigation mode.
- Mode is locked for the duration of the gesture.

## UI Screens

### Home Screen
- Dark theme.
- App title at top.
- 2-column scrollable grid of 6 puzzle cards.
- Each card: preview thumbnail image, puzzle title, category label.
- Tapping a card shows piece count selector: preset buttons for 10, 24, 48, 72, 100.
- "Start Puzzle" button launches the game with selected image and piece count.

### Puzzle Gameplay Screen
- Full-screen SpriteKit scene.
- SwiftUI HUD overlay at top: back/menu button (left), elapsed timer (center), progress "X/Y placed" (right).
- Ghost outline of the target image centered on the canvas as a placement reference (semi-transparent, ~20% opacity).
- Pieces start scrambled at random positions around the edges of the visible canvas area, at random rotations.

### Victory Screen
- Triggered on puzzle completion.
- Piece edges fade away over ~0.5s revealing the clean, uncut image.
- Confetti particle effect via `SKEmitterNode` (2–3 seconds).
- Overlay appears: "Congratulations!", completion time, piece count, "Back to Menu" button.

## Haptic Feedback
- **Light tap** — on piece pickup.
- **Medium impact** — on successful snap.
- **Success notification** — on victory/completion.

## Performance Notes
- Snap checks run only on touch-up, not per-frame. At 100 pieces with ~400 edges, this is negligible.
- Texture clipping is a one-time cost at puzzle start. After that, gameplay is standard sprite rendering.
- Group merging is O(n) where n = pieces in the smaller group.
- SpriteKit handles z-ordering, hit testing, and rendering of 100+ sprite nodes efficiently on modern iOS hardware.

## Bundled Puzzle Images
6 images prepackaged in the app asset catalog:
1. Mountain Lake (Landscape)
2. Ocean Sunset (Seascape)
3. Sunflower Field (Nature)
4. Ancient Temple (Architecture)
5. Safari Wildlife (Animals)
6. Abstract Art (Art)

Images should be high resolution (at least 2048px on the long edge) to support clean texture clipping at high piece counts.

## Data Model

```swift
enum EdgeType {
    case flat
    case tab
    case socket
}

struct PieceEdges {
    let top: EdgeType
    let right: EdgeType
    let bottom: EdgeType
    let left: EdgeType
}

struct PieceMetadata {
    let row: Int
    let col: Int
    let edges: PieceEdges
    let correctPosition: CGPoint
    let neighbors: [Edge: PieceID]  // which piece connects on each side
}

struct PuzzleConfig {
    let image: UIImage
    let rows: Int
    let cols: Int
    let seed: UInt64
}
```

## Future Enhancements (Not MVP)
- Specialty wood-cut pieces (irregular, artistic shapes)
- Additional cut styles (wavy, straight-edge variants)
- Custom image import (photo library)
- Difficulty ratings
- Puzzle save/resume
- Multiplayer
