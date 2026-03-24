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
            // Puzzle image preview — use asset or placeholder color
            ZStack {
                // Gradient placeholder background
                LinearGradient(
                    colors: gradientColors(for: puzzle.id),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Try loading the actual image
                Image(puzzle.imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
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

    private func gradientColors(for id: String) -> [Color] {
        switch id {
        case "mountain": return [.red, .orange]
        case "ocean": return [.cyan, .blue]
        case "sunflower": return [.yellow, .orange]
        case "temple": return [.purple, .indigo]
        case "safari": return [.green, .teal]
        case "abstract": return [.pink, .purple]
        default: return [.gray, .gray]
        }
    }
}
