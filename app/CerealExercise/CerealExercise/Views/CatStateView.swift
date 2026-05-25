import SwiftUI
import UIKit

struct CatStateView: View {
    let state: CatState
    var decoration: CatDecoration = .none

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimated = false

    var body: some View {
        character
        .frame(width: 72, height: 72)
        .background(backgroundColor, in: Circle())
        .overlay {
            Circle()
                .strokeBorder(borderColor, lineWidth: 2)
        }
        .offset(y: Motion.offset(verticalOffset, reduceMotion: reduceMotion))
        .scaleEffect(Motion.scale(scale, reduceMotion: reduceMotion))
        .rotationEffect(.degrees(Motion.rotation(rotation, reduceMotion: reduceMotion)))
        .accessibilityLabel("猫キャラクター \(state.displayName)")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(animation.repeatForever(autoreverses: true)) {
                isAnimated = true
            }
        }
    }

    @ViewBuilder
    private var character: some View {
        ZStack {
            let assetName = "cat_\(state.rawValue)"
            if UIImage(named: assetName) != nil {
                // 以前は scaledToFit + padding(8) で表示していたが、AI 生成
                // 元画像の被写体周囲に背景 (窓 / 花瓶 / 紙吹雪など) が含まれて
                // いたため、円フレーム内で猫が小さく見え「余白がある」印象に
                // なっていた。scaledToFill + clipShape(Circle) で円形マスクし、
                // さらに状態ごとに被写体サイズに合わせて scale を補正する。
                Image(assetName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(imageScale(for: state))
                    .frame(width: 72, height: 72)
                    .clipShape(Circle())
            } else {
                Text(state.emoji)
                    .font(.system(size: state == .streakExtended ? 40 : 46))
            }
            CatDecorationOverlay(decoration: decoration)
        }
    }

    /// 各 AI 生成画像で被写体 (猫) が占める割合が違うため、円形マスクで
    /// 切り抜く際に「被写体がフレーム一杯に入る」よう状態ごとに微調整。
    private func imageScale(for state: CatState) -> CGFloat {
        switch state {
        case .waitingMorning: return 1.25   // 背景に窓+花瓶があり猫が小さめ
        case .streakExtended: return 1.30   // 周囲に炎装飾が多く猫が小さめ
        case .beggingNight:   return 1.20   // 背景に植物+ランタン
        case .worriedNoon:    return 1.15   // 花の装飾あり
        case .encouraging:    return 1.15   // 比較的余白少なめ
        case .celebrating:    return 1.20   // 紙吹雪あるが猫が大きめ
        case .resting:        return 1.20   // 背景シンプル、猫が中央
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .waitingMorning: Palette.secondary.opacity(0.75)
        case .worriedNoon: Color(red: 0.93, green: 0.91, blue: 0.72)
        case .beggingNight: Color(red: 0.68, green: 0.78, blue: 0.92)
        case .celebrating: Palette.success.opacity(0.55)
        case .streakExtended: Palette.primary.opacity(0.45)
        case .resting: Palette.restDay.opacity(0.65)
        case .encouraging: Color(red: 0.95, green: 0.82, blue: 0.72)
        }
    }

    private var borderColor: Color {
        switch state {
        case .celebrating, .streakExtended: Palette.primaryDeep
        case .resting: Palette.restDay
        default: Palette.surface
        }
    }

    private var scale: CGFloat {
        switch state {
        case .beggingNight: isAnimated ? 1.06 : 0.98
        case .celebrating: isAnimated ? 1.12 : 0.94
        case .streakExtended: isAnimated ? 1.18 : 0.95
        case .resting: isAnimated ? 1.04 : 0.98
        default: isAnimated ? 1.02 : 1
        }
    }

    private var rotation: Double {
        switch state {
        case .worriedNoon: isAnimated ? 3 : -3
        case .beggingNight: isAnimated ? 5 : -5
        case .celebrating: isAnimated ? 8 : -4
        case .streakExtended: isAnimated ? 10 : -8
        case .encouraging: isAnimated ? 6 : -3
        default: 0
        }
    }

    private var verticalOffset: CGFloat {
        switch state {
        case .waitingMorning: isAnimated ? -5 : 3
        case .beggingNight: isAnimated ? -7 : 4
        case .celebrating: isAnimated ? -9 : 2
        case .streakExtended: isAnimated ? -12 : 4
        default: 0
        }
    }

    private var animation: Animation {
        switch state {
        case .waitingMorning, .resting: Motion.gentle
        case .worriedNoon: .easeInOut(duration: 0.7)
        case .beggingNight, .celebrating, .streakExtended: Motion.bouncy
        case .encouraging: Motion.snappy
        }
    }
}
