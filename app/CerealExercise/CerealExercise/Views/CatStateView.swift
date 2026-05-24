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
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Text(state.emoji)
                    .font(.system(size: state == .streakExtended ? 40 : 46))
            }
            CatDecorationOverlay(decoration: decoration)
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
