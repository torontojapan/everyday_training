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

    // 決定論的な粒子位置(再描画でちらつかない)。
    // 全画面ランダムだと大半が猫・カード・下部ボタンの裏に隠れて「粒子が見えない」
    // (ユーザー指摘 2026-06-13)ため、中央域に落ちた粒子は左右マージンへ寄せ、
    // 下端 18% (ボタン+タブバー) には置かない。
    // 注: 旧 `(i * 2654435761) % 997` は 2654435761 mod 997 = 30 のため x = 30i/997 の
    // 等差数列に退化し、全粒子が左側へ一列に固まっていた → splitmix64 系で分散させる。
    private func sparkleHash01(_ v: UInt64) -> Double {
        var x = v &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 33
        x &*= 0xC2B2_AE3D_27D4_EB4F
        x ^= x >> 29
        return Double(x % 100_000) / 100_000.0
    }
    private func sparklePosition(_ i: Int, size: CGSize) -> CGPoint {
        // ホームで確実に背景が見えるのは「猫の左右の帯」だけ
        // (上 0.28 まではカード列、下 0.78 からは吹き出し+ボタン+タブバー)。
        // 左右は i の偶奇で交互に割り当てて偏りを防ぐ(ハッシュ任せだと
        // 片側に寄る — ユーザー指摘 2026-06-13「左半分に無い」)。
        let inset = 0.03 + sparkleHash01(UInt64(i) * 2 + 1) * 0.13   // 端から 3〜16%
        let x = (i % 2 == 0) ? inset : 1.0 - inset
        let y = 0.28 + sparkleHash01(UInt64(i) * 2 + 2) * 0.50       // 0.28〜0.78
        return CGPoint(x: x * size.width, y: y * size.height)
    }
    private func sparkle(_ i: Int, t: TimeInterval, size: CGSize) -> some View {
        let phase = Double(i) * 0.7
        let op = 0.55 + 0.35 * (0.5 + 0.5 * sin(t * 1.1 + phase))
        return sparkleGlyph(i, op: op, size: size)
    }
    private func staticSparkle(_ i: Int, size: CGSize) -> some View {
        sparkleGlyph(i, op: 0.75, size: size)
    }
    /// メタル色の濃い縁 + 白いコアの2枚重ね。帯と同系色の背景(下部の黄など)でも
    /// 縁のコントラストで形が出て、白コアで「光っている」質感を出す
    /// (単色だと背景同化して見えない問題の根治。ユーザー指摘 2026-06-13)。
    private func sparkleGlyph(_ i: Int, op: Double, size: CGSize) -> some View {
        let pos = sparklePosition(i, size: size)
        let s = CGFloat(10 + (i % 4) * 4)
        return ZStack {
            // 縁(やや大きく・メタル色を暗めにしてどの背景でも輪郭が立つ)
            Image(systemName: "sparkle")
                .font(.system(size: s * 1.25, weight: .semibold))
                .foregroundStyle(bandColor.opacity(op))
                .brightness(-0.38)
            // コア(白く抜いて発光感)
            Image(systemName: "sparkle")
                .font(.system(size: s, weight: .semibold))
                .foregroundStyle(Color.white.opacity(op * 0.95))
        }
        .shadow(color: bandColor.opacity(op * 0.6), radius: 3)
        .position(pos)
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
