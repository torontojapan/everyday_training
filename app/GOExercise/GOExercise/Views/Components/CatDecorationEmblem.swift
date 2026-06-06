import SwiftUI

/// 達成段階(`CatDecoration`)を表す、猫の「頭上に浮かべる」コードエンブレム。
/// 全猫種・全ポーズで自動対応(画像アセット不要)。猫の体/顔には描かない
/// (体に焼き込み済みの装飾と二重にならないよう、頭上の空きスペースにのみ浮かせる)。
struct CatDecorationEmblem: View {
    let decoration: CatDecoration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    private var size: CGFloat {
        switch decoration {
        case .crown:  return 38
        case .medal:  return 30
        case .headband, .bandana: return 24
        case .none:   return 0
        }
    }

    var body: some View {
        if decoration != .none {
            ZStack {
                // 柔らかいグローの土台。
                Circle()
                    .fill(decoration.accentColor.opacity(0.32))
                    .frame(width: size * 1.7, height: size * 1.7)
                    .blur(radius: 11)
                Image(systemName: decoration.catEmblemSymbol)
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [decoration.accentColor, decoration.accentColor.opacity(0.7)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            }
            .offset(y: reduceMotion ? 0 : (bob ? -3 : 3))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
        }
    }
}
