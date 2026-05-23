import SwiftUI

struct ConfettiView: View {
    private let pieces: [ConfettiPiece]
    @State private var isFalling = false

    init(count: Int = 30) {
        pieces = (0..<count).map { ConfettiPiece(index: $0) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    Circle()
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size)
                        .position(
                            x: geometry.size.width * piece.xRatio,
                            y: isFalling ? geometry.size.height * piece.endYRatio : -24
                        )
                        .opacity(isFalling ? 0 : 1)
                        .animation(
                            .easeOut(duration: piece.duration).delay(piece.delay),
                            value: isFalling
                        )
                }
            }
            .onAppear {
                isFalling = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let xRatio: CGFloat
    let endYRatio: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let color: Color

    init(index: Int) {
        xRatio = CGFloat((index * 37) % 100) / 100
        endYRatio = 0.35 + CGFloat((index * 19) % 65) / 100
        size = CGFloat(6 + (index % 5))
        delay = Double(index % 8) * 0.06
        duration = 1.1 + Double(index % 6) * 0.12
        color = [
            Palette.primary,
            Palette.success,
            Palette.restDay,
            Color(red: 0.98, green: 0.78, blue: 0.34),
            Color(red: 0.56, green: 0.76, blue: 0.86)
        ][index % 5]
    }
}
