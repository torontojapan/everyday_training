import SwiftUI

/// メタリックな称号カプセル。`CatRank` 駆動。rank0(連続7日未満)は何も描かない。
/// `animateShimmer` を true にすると、表示時に斜めハイライトが一度流れ + 軽い pop。
struct RankBadge: View {
    let rank: CatRank
    /// 昇格直後など、初表示で shimmer/pop を一度だけ流すか。
    var animateShimmer: Bool = false
    var compact: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shimmerX: CGFloat = -1.0
    @State private var popped = false

    var body: some View {
        if rank.rank > 0, let title = rank.title, let metal = rank.metalKind {
            content(title: title, metal: metal)
                .scaleEffect(popped ? 1.0 : (animateShimmer && !reduceMotion ? 0.92 : 1.0))
                .onAppear { runEntranceIfNeeded() }
                .accessibilityElement()
                .accessibilityLabel("称号 \(title)")
        }
    }

    @ViewBuilder
    private func content(title: String, metal: MetalKind) -> some View {
        let fill: AnyShapeStyle = MetalStyle.isRainbow(metal)
            ? AnyShapeStyle(AngularGradient(colors: MetalStyle.rainbowColors, center: .center))
            : AnyShapeStyle(MetalStyle.fillGradient(metal))

        HStack(spacing: 5) {
            Image(systemName: rank.iconSymbol)
                .font(.system(size: compact ? 10 : 12, weight: .bold))
                .accessibilityHidden(true)
            Text(title)
                .font(.system(compact ? .caption2 : .footnote, design: .rounded, weight: .heavy))
        }
        .foregroundStyle(Color.black.opacity(0.78)) // メタル地に黒文字でコントラスト確保(WCAG)
        .padding(.horizontal, compact ? 8 : 11)
        .padding(.vertical, compact ? 4 : 6)
        .background {
            Capsule()
                .fill(fill)
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75) // 金属フチ
                )
                .overlay(shimmerOverlay) // 斜めハイライト
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { geo in
            Capsule()
                .fill(LinearGradient(
                    colors: [.clear, .white.opacity(0.65), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: geo.size.width * 0.5)
                .offset(x: shimmerX * geo.size.width)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .clipShape(Capsule())
    }

    private func runEntranceIfNeeded() {
        guard animateShimmer, !reduceMotion else { popped = true; return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) { popped = true } // pop ~280ms
        withAnimation(.easeInOut(duration: 0.55)) { shimmerX = 1.0 } // shimmer 一度流す
    }
}
