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
                    let image = UIImage(named: puzzleInfo.imageName)
                        ?? PuzzleCatalog.placeholderImage(for: puzzleInfo.id)
                    viewModel.startPuzzle(image: image, pieceCount: pieceCount)
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

    deinit {
        timer?.invalidate()
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
