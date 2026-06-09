import SwiftUI

enum CelebrationLevel: Sendable {
    case subtle    // 単発の達成 / 軽い祝福
    case standard  // 連続記録更新 / 中位ミルストーン
    case heroic    // 大ミルストーン (30日 / 100日 / レベルアップ)
    case legendary // 365日 / 全実績解除

    var confettiIntensity: ConfettiView.Intensity {
        switch self {
        case .subtle: return .subtle
        case .standard: return .standard
        case .heroic, .legendary: return .heroic
        }
    }

    @MainActor
    var bloomColors: [Color] {
        switch self {
        case .subtle:
            return [Palette.primary.opacity(0.45), .clear]
        case .standard:
            return [Color(red: 1.00, green: 0.85, blue: 0.40).opacity(0.55),
                    Palette.primary.opacity(0.30), .clear]
        case .heroic:
            return [Color(red: 1.00, green: 0.55, blue: 0.30).opacity(0.65),
                    Color(red: 0.95, green: 0.45, blue: 0.75).opacity(0.40), .clear]
        case .legendary:
            return [Color(red: 1.00, green: 0.85, blue: 0.30).opacity(0.75),
                    Color(red: 0.95, green: 0.45, blue: 0.75).opacity(0.55),
                    Color(red: 0.55, green: 0.30, blue: 0.95).opacity(0.35), .clear]
        }
    }

    var bloomScale: CGFloat {
        switch self {
        case .subtle: return 1.6
        case .standard: return 2.0
        case .heroic: return 2.6
        case .legendary: return 3.0
        }
    }

    var pulseCount: Int {
        switch self {
        case .subtle: return 1
        case .standard: return 2
        case .heroic: return 3
        case .legendary: return 4
        }
    }

    var rayCount: Int {
        switch self {
        case .subtle: return 0
        case .standard: return 8
        case .heroic: return 14
        case .legendary: return 24
        }
    }
}

/// Composable celebration overlay: radial bloom + light rays + confetti.
/// Place inside a ZStack with `.celebrate(level:)` modifier on the parent.
struct CelebrationOverlay: View {
    let level: CelebrationLevel
    /// 紙吹雪(星/ひし形/三角などの小アイコン)を出すか。記録完了画面では
    /// 上部にアイコンが散らかって見えるため false を渡して光彩のみにする。
    var showsConfetti: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bloomScale: CGFloat = 0.3
    @State private var bloomOpacity: Double = 0
    @State private var rayRotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: level.bloomColors,
                    center: .center,
                    startRadius: 0,
                    endRadius: max(geo.size.width, geo.size.height) * level.bloomScale * 0.6
                )
                .scaleEffect(bloomScale)
                .opacity(bloomOpacity)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)

                if level.rayCount > 0 && !reduceMotion {
                    ZStack {
                        ForEach(0..<level.rayCount, id: \.self) { i in
                            LinearGradient(
                                colors: [Color.white.opacity(0.0), Color.white.opacity(0.35), Color.white.opacity(0.0)],
                                startPoint: .top, endPoint: .bottom
                            )
                            .frame(width: 4, height: geo.size.height * 1.2)
                            .rotationEffect(.degrees(Double(i) * (360.0 / Double(level.rayCount))))
                        }
                    }
                    .rotationEffect(.degrees(rayRotation))
                    .opacity(bloomOpacity * 0.6)
                    .blendMode(.screen)
                    .allowsHitTesting(false)
                }

                if showsConfetti {
                    ConfettiView(intensity: level.confettiIntensity)
                        .allowsHitTesting(false)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                bloomOpacity = 0.6
                bloomScale = 1.0
                return
            }
            withAnimation(.easeOut(duration: 0.65)) {
                bloomScale = 1.0
                bloomOpacity = 1.0
            }
            // Pulse cycles for stronger levels
            for i in 0..<level.pulseCount {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(550 * (i + 1)))
                    withAnimation(.easeInOut(duration: 0.45).repeatCount(2, autoreverses: true)) {
                        bloomScale = 1.15
                    }
                }
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rayRotation = 360
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.easeOut(duration: 0.7)) {
                    bloomOpacity = 0
                }
            }
        }
    }
}

/// Shimmering text — useful for milestone headlines.
struct ShimmerText: View {
    let text: String
    let font: Font
    var colors: [Color] = [
        Color(red: 1.00, green: 0.85, blue: 0.30),
        Color.white,
        Color(red: 0.98, green: 0.65, blue: 0.85)
    ]
    @State private var phase: CGFloat = -0.5
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(
                LinearGradient(
                    colors: colors,
                    startPoint: UnitPoint(x: phase, y: 0),
                    endPoint: UnitPoint(x: phase + 1, y: 1)
                )
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 2.4).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
            .accessibilityLabel(text)
    }
}

/// Animated number that counts up from 0 to target with spring overshoot at the end.
struct CountUpNumber: View {
    let target: Int
    let font: Font
    let duration: Double
    @State private var current: Int = 0
    @State private var scale: CGFloat = 0.6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(target: Int, font: Font, duration: Double = 1.2) {
        self.target = target
        self.font = font
        self.duration = duration
    }

    var body: some View {
        Text("\(current)")
            .font(font)
            .scaleEffect(scale)
            .accessibilityLabel("\(target)")
            .onAppear { animate() }
    }

    private func animate() {
        guard !reduceMotion, target > 0 else {
            current = target
            scale = 1.0
            return
        }
        let steps = min(target, 28)
        let interval = duration / Double(max(steps, 1))
        Task { @MainActor in
            for step in 1...steps {
                current = Int(Double(target) * Double(step) / Double(steps))
                try? await Task.sleep(for: .seconds(interval))
            }
            current = target
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                scale = 1.0
            }
        }
    }
}
