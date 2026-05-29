import SwiftUI

enum ConfettiShape: CaseIterable, Sendable {
    case circle, star, diamond, triangle, sparkle
}

struct ConfettiView: View {
    private let pieces: [ConfettiPiece]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isFalling = false

    init(count: Int = 30, intensity: Intensity = .standard) {
        let effectiveCount: Int
        switch intensity {
        case .subtle:   effectiveCount = max(count, 18)
        case .standard: effectiveCount = max(count, 36)
        case .heroic:   effectiveCount = max(count, 70)
        }
        pieces = (0..<effectiveCount).map { ConfettiPiece(index: $0, intensity: intensity) }
    }

    enum Intensity: Sendable {
        case subtle, standard, heroic
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(pieces) { piece in
                    shapeView(for: piece)
                        .frame(width: piece.size, height: piece.size)
                        .rotationEffect(.degrees(isFalling ? piece.endRotation : 0))
                        .position(
                            x: geometry.size.width * (isFalling ? piece.endXRatio : piece.xRatio),
                            y: reduceMotion ? geometry.size.height * 0.18 : (isFalling ? geometry.size.height * piece.endYRatio : -28)
                        )
                        .opacity(reduceMotion ? 0.45 : (isFalling ? 0 : 1))
                        .animation(
                            Motion.animation(.easeOut(duration: piece.duration).delay(piece.delay), reduceMotion: reduceMotion),
                            value: isFalling
                        )
                }
            }
            .onAppear {
                if !reduceMotion {
                    isFalling = true
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shapeView(for piece: ConfettiPiece) -> some View {
        switch piece.shape {
        case .circle:
            Circle().fill(piece.color)
        case .star:
            Image(systemName: "star.fill").foregroundStyle(piece.color).font(.system(size: piece.size))
        case .diamond:
            Rectangle().fill(piece.color).rotationEffect(.degrees(45))
        case .triangle:
            TriangleShape().fill(piece.color)
        case .sparkle:
            Image(systemName: "sparkle").foregroundStyle(piece.color).font(.system(size: piece.size))
        }
    }
}

private struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let xRatio: CGFloat
    let endXRatio: CGFloat
    let endYRatio: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let color: Color
    let shape: ConfettiShape
    let endRotation: Double

    @MainActor
    init(index: Int, intensity: ConfettiView.Intensity = .standard) {
        xRatio = CGFloat((index * 37) % 100) / 100
        endXRatio = xRatio + CGFloat(((index * 13) % 41) - 20) / 100   // ±20% 横ドリフト
        endYRatio = 0.40 + CGFloat((index * 19) % 65) / 100
        switch intensity {
        case .subtle:   size = CGFloat(5 + (index % 4))
        case .standard: size = CGFloat(7 + (index % 6))
        case .heroic:   size = CGFloat(9 + (index % 9))
        }
        delay = Double(index % 10) * 0.05
        duration = 1.1 + Double(index % 7) * 0.13
        let palette: [Color] = [
            Palette.primary,
            Palette.success,
            Palette.restDay,
            Color(red: 1.00, green: 0.82, blue: 0.30),
            Color(red: 0.56, green: 0.76, blue: 0.92),
            Color(red: 0.95, green: 0.45, blue: 0.75),
            Color(red: 0.60, green: 0.35, blue: 0.90)
        ]
        color = palette[index % palette.count]
        let shapes: [ConfettiShape]
        switch intensity {
        case .subtle:   shapes = [.circle, .circle, .sparkle]
        case .standard: shapes = [.circle, .star, .diamond, .triangle, .sparkle]
        case .heroic:   shapes = [.star, .sparkle, .diamond, .circle, .star, .sparkle, .triangle]
        }
        shape = shapes[index % shapes.count]
        endRotation = Double((index * 47) % 720) - 360
    }
}
