import SwiftUI

/// 画像カード(旧 `MilestoneBackgroundView`)を廃し、**現在の連続日数**で段階的に
/// 豪華になるコード背景。色帯は rank のメタル系統、richness で濃さ。粒子・時間帯
/// トーン・最上位の光を重ねる。装飾専用なので hitTesting/VoiceOver から完全に外す。
struct MilestoneBackdrop: View {
    let streak: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: MilestoneBackdropStyle { MilestoneBackdropStyle(streak: streak) }

    /// 色帯の基準色。rank0 は背景テーマのみ。
    private var bandColor: Color {
        guard let kind = style.metalKind else { return .clear }
        if MetalStyle.isRainbow(kind) { return Color(red: 1.0, green: 0.80, blue: 0.42) }
        return MetalStyle.baseColor(kind)
    }

    /// 時間帯トーン(暖→昼白→紺)を ~6% かぶせる。
    private var timeTone: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return Color(red: 1.0, green: 0.85, blue: 0.6)   // 朝 暖
        case 11..<17: return Color.white                                // 昼 白
        default:      return Color(red: 0.20, green: 0.24, blue: 0.45)  // 夜 紺
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Palette.background

                // 1. メタル色帯(richness で濃さ)
                if style.rank > 0 {
                    LinearGradient(
                        colors: [
                            bandColor.opacity(0.07 * style.richness),
                            bandColor.opacity(0.30 * style.richness)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                // 2. 中心グロー
                if style.glowOpacity > 0 {
                    RadialGradient(
                        colors: [bandColor.opacity(style.glowOpacity), .clear],
                        center: UnitPoint(x: 0.5, y: 0.34),
                        startRadius: 0, endRadius: geo.size.width * 0.72
                    )
                }

                // 3. 時間帯トーン(全体に淡く)
                timeTone.opacity(0.06).blendMode(.plusLighter)

                // 4. 粒子(reduceMotion で静止)
                if style.sparkleCount > 0 {
                    if reduceMotion {
                        ForEach(0..<style.sparkleCount, id: \.self) { i in
                            staticSparkle(i, size: geo.size)
                        }
                    } else {
                        TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                            let t = ctx.date.timeIntervalSinceReferenceDate
                            ForEach(0..<style.sparkleCount, id: \.self) { i in
                                sparkle(i, t: t, size: geo.size)
                            }
                        }
                    }
                }

                // 5. 最上位の光帯(rank>=10)。reduceMotion で静止。
                if style.animated {
                    if reduceMotion {
                        movingBand(t: 0, size: geo.size)
                    } else {
                        TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                            movingBand(t: ctx.date.timeIntervalSinceReferenceDate, size: geo.size)
                        }
                    }
                }

                // 6. rank11 のゴッドレイ + 虹の微反射
                if style.rank >= 11 {
                    godRays(size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // 決定論的な粒子位置(再描画でちらつかない)
    private func sparklePosition(_ i: Int, size: CGSize) -> CGPoint {
        let x = Double((i &* 2_654_435_761) % 997) / 997.0
        let y = Double((i &* 40_503 &+ 12_345) % 991) / 991.0
        return CGPoint(x: x * size.width, y: y * size.height)
    }
    private func sparkle(_ i: Int, t: TimeInterval, size: CGSize) -> some View {
        let pos = sparklePosition(i, size: size)
        let phase = Double(i) * 0.7
        let op = 0.28 + 0.42 * (0.5 + 0.5 * sin(t * 1.1 + phase))
        let s = CGFloat(6 + (i % 4) * 3)
        return Image(systemName: "sparkle")
            .font(.system(size: s)).foregroundStyle(bandColor.opacity(op)).position(pos)
    }
    private func staticSparkle(_ i: Int, size: CGSize) -> some View {
        let pos = sparklePosition(i, size: size)
        let s = CGFloat(6 + (i % 4) * 3)
        return Image(systemName: "sparkle")
            .font(.system(size: s)).foregroundStyle(bandColor.opacity(0.45)).position(pos)
    }
    private func movingBand(t: TimeInterval, size: CGSize) -> some View {
        let period = 26.0
        let p = (t.truncatingRemainder(dividingBy: period)) / period
        let travel = size.width * 1.8
        // rank10+(platinum/rainbow)の上位感は「色の濃さ」でなく「光の艶」で出す
        // (3LLM A1: 上位が gold より地味に見える ↔ 上品さ維持の両立)。白寄りの
        // 光沢帯を少し強める。
        return RoundedRectangle(cornerRadius: 240)
            .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.10), bandColor.opacity(0.18), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: travel, height: size.height * 0.6)
            .rotationEffect(.degrees(-20))
            .position(x: -travel * 0.4 + travel * p, y: size.height * 0.34)
            .blendMode(.plusLighter)
    }
    // rank11: 中心から放射する淡いレイ + 虹の微反射(静止・上品に)
    private func godRays(size: CGSize) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 80)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: size.width * 0.10, height: size.height * 0.9)
                    .rotationEffect(.degrees(Double(i) * 45))
                    .position(x: size.width * 0.5, y: size.height * 0.34)
            }
            AngularGradient(colors: MetalStyle.rainbowColors, center: UnitPoint(x: 0.5, y: 0.34))
                .opacity(0.05).blendMode(.plusLighter)
        }
    }
}
