import SwiftUI
import UIKit

/// ウィジェット内のブランド猫アイコン。本体と同じオレンジトラ猫を状態別に表示する
/// (絵文字ではなく実キャラ画像。WidgetCatAssets.xcassets に縮小版を同梱)。
struct WidgetCatView: View {
    let rawState: String
    var size: CGFloat = 58

    var body: some View {
        catImage
            .frame(width: size * 0.78, height: size * 0.78)
            .frame(width: size, height: size)
            .background(
                Circle().fill(
                    RadialGradient(
                        colors: [haloColor.opacity(0.9), haloColor.opacity(0.35)],
                        center: .center, startRadius: 2, endRadius: size * 0.6
                    )
                )
            )
            .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5))
            .accessibilityLabel("猫キャラクター \(catState.displayName)")
    }

    /// アセットが見つかればブランド猫画像、無ければ肉球記号にフォールバックして
    /// 空白描画を防ぐ (Codex 指摘: 将来 state 追加やカタログ欠落時の保険)。
    @ViewBuilder
    private var catImage: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "pawprint.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.30))
                .padding(size * 0.18)
        }
    }

    private var catState: CatState {
        CatState(rawValue: rawState) ?? .waitingMorning
    }

    /// オレンジ猫の状態別アセット名 (widget 専用カタログ内)。
    private var assetName: String {
        "cat_orange_\(catState.rawValue)"
    }

    private var haloColor: Color {
        switch catState {
        case .celebrating, .streakExtended:
            return Color(red: 0.58, green: 0.85, blue: 0.55)
        case .resting:
            return Color(red: 0.72, green: 0.83, blue: 0.98)
        case .beggingNight:
            return Color(red: 0.70, green: 0.80, blue: 0.95)
        case .worriedNoon:
            return Color(red: 1.00, green: 0.80, blue: 0.62)
        default:
            return Color(red: 1.00, green: 0.86, blue: 0.66)
        }
    }
}
