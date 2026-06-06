import SwiftUI

/// 達成日数に応じて「ホーム画面全体の最背面」を段階的に豪華にする背景。
/// 画像カード(旧 `MilestoneBackgroundView`)を廃し、テーマ連動のグラデ + tier で増える
/// 控えめなグロー/きらめき + 最上位のみ淡い光の帯、をすべてコードで描く。
/// tier0(達成 7 日未満)は実質テーマ背景のまま=新規ユーザーに装飾は出ない。
struct MilestoneBackdrop: View {
    let totalAchievedDays: Int

    private var style: MilestoneBackdropStyle { MilestoneBackdropStyle(totalAchievedDays: totalAchievedDays) }
    /// 達成のご褒美色(暖かい琥珀/ゴールド)。全テーマで控えめに重ねて調和させる。
    private let gold = Color(red: 1.0, green: 0.80, blue: 0.42)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 1. テーマ背景(ベース)。
                Palette.background

                // 2. 達成グラデ(ゴールド)を richness で重ねる。tier0 は opacity0=不可視。
                LinearGradient(
                    colors: [
                        gold.opacity(0.07 * style.richness),
                        gold.opacity(0.30 * style.richness)   // 3LLM: 最上位の黄色を抑えて上品に
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // 3. 中心やや上のグロー(猫の後ろを優しく光らせる)。猫を焦点に少し絞る。
                if style.glowOpacity > 0 {
                    RadialGradient(
                        colors: [gold.opacity(style.glowOpacity), .clear],
                        center: UnitPoint(x: 0.5, y: 0.34),
                        startRadius: 0, endRadius: geo.size.width * 0.72
                    )
                }

                // 4. きらめき(tier で数が増える)。決定的配置 + ゆっくり twinkle(軽量に throttle)。
                if style.sparkleCount > 0 {
                    TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        ForEach(0..<style.sparkleCount, id: \.self) { i in
                            sparkle(i, t: t, size: geo.size)
                        }
                    }
                }

                // 5. 最上位(365日〜)のみ、淡い光の帯をゆっくり斜めに流す。
                if style.animated {
                    TimelineView(.animation(minimumInterval: 0.2, paused: false)) { ctx in
                        movingBand(t: ctx.date.timeIntervalSinceReferenceDate, size: geo.size)
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - 粒子

    /// index から決定的に位置を出す(再描画でちらつかせない)。
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
            .font(.system(size: s))
            .foregroundStyle(gold.opacity(op))
            .position(pos)
    }

    // MARK: - 最上位の光帯

    private func movingBand(t: TimeInterval, size: CGSize) -> some View {
        let period = 26.0
        let p = (t.truncatingRemainder(dividingBy: period)) / period   // 0..1
        let travel = size.width * 1.8
        return RoundedRectangle(cornerRadius: 240)
            .fill(LinearGradient(colors: [.clear, gold.opacity(0.10), .clear],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: travel, height: size.height * 0.55)
            .rotationEffect(.degrees(-20))
            .position(x: -travel * 0.4 + travel * p, y: size.height * 0.34)
            .blendMode(.plusLighter)
    }
}
