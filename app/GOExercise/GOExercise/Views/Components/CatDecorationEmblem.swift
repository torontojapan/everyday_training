import SwiftUI

/// 達成段階(`CatDecoration`)を表す、猫の「頭上に浮かべる」コードバッジ。
/// 全猫種・全ポーズで自動対応(画像アセット不要)。猫の体/顔には描かない
/// (体に焼き込み済みの装飾と二重にならないよう、頭上の空きスペースにのみ浮かせる)。
/// 半透明スタンプではなく「ソリッドな円形バッジ(台座+白アイコン+影)」で立体感を出す
/// (3LLMスクショ検証: 透けてチープに見える指摘を反映)。
struct CatDecorationEmblem: View {
    let decoration: CatDecoration
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    /// 顔に被らないよう控えめサイズ(3LLM: 大きすぎ/顔被り指摘を反映)。
    private var size: CGFloat {
        switch decoration {
        case .crown:  return 32
        case .medal:  return 29
        case .headband, .bandana: return 26
        case .none:   return 0
        }
    }

    var body: some View {
        if decoration != .none {
            ZStack {
                // 1. ソフトグロー(達成色)。
                Circle()
                    .fill(decoration.accentColor.opacity(0.28))
                    .frame(width: size * 1.45, height: size * 1.45)
                    .blur(radius: 8)
                // 2. ソリッドなバッジ台座(立体感・全段階で共通形=システム感)。
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [decoration.accentColor, decoration.accentColor.opacity(0.72)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay(Circle().strokeBorder(.white.opacity(0.9), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.22), radius: 3, y: 1.5)
                // 3. 白のアイコン(くっきり)。
                Image(systemName: decoration.catEmblemSymbol)
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(y: reduceMotion ? 0 : (bob ? -2 : 2))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { bob = true }
            }
            .accessibilityHidden(true)
        }
    }
}
