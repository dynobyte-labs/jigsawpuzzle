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
