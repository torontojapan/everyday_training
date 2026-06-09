import SwiftUI

/// 小節目(minor)の軽量オーバーレイ。割り込まない(タップ透過)。
/// 上から称号トーストが短く降り、光のさざ波が一度走り、自動で消える。
struct RankCelebrationOverlay: View {
    /// 表示する称号ランク(昇格後 or 週次時点の現在ランク)。
    let rank: CatRank
    /// トーストの上書きコピー(週次など)。nil なら「達成!」。
    var message: String?
    /// 演出完了時に呼ばれる(呼び出し側で表示フラグを下ろす)。
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dropIn = false
    @State private var rippleScale: CGFloat = 0.2
    @State private var rippleOpacity: Double = 0.0

    var body: some View {
        ZStack(alignment: .top) {
            Circle()
                .stroke(rippleColor, lineWidth: 3)
                .scaleEffect(rippleScale)
                .opacity(rippleOpacity)
                .frame(width: 160, height: 160)
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height * 0.34)
                .allowsHitTesting(false)

            toast
                .offset(y: dropIn ? 8 : -80)
                .opacity(dropIn ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear { run() }
    }

    private var rippleColor: Color {
        guard let metal = rank.metalKind else { return .white }
        return MetalStyle.isRainbow(metal) ? Color(red: 1, green: 0.8, blue: 0.42) : MetalStyle.baseColor(metal)
    }

    private var toast: some View {
        HStack(spacing: 8) {
            RankBadge(rank: rank, animateShimmer: true)
            Text(message ?? "達成!")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("称号 \(rank.title ?? "") を達成")
    }

    private func run() {
        if reduceMotion {
            dropIn = true; rippleOpacity = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { onFinished() }
            return
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dropIn = true }
        withAnimation(.easeOut(duration: 0.8)) { rippleScale = 1.6; rippleOpacity = 0.0 }
        withAnimation(.easeOut(duration: 0.1)) { rippleOpacity = 0.7 }
        withAnimation(.easeOut(duration: 0.8).delay(0.1)) { rippleOpacity = 0.0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeIn(duration: 0.3)) { dropIn = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { onFinished() }
    }
}
