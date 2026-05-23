import SwiftUI

struct WidgetCatView: View {
    let rawState: String

    var body: some View {
        Text(catState.emoji)
            .font(.system(size: 42))
            .frame(width: 58, height: 58)
            .background(backgroundColor, in: Circle())
            .accessibilityLabel("猫キャラクター \(catState.displayName)")
    }

    private var catState: CatState {
        CatState(rawValue: rawState) ?? .waitingMorning
    }

    private var backgroundColor: Color {
        switch catState {
        case .celebrating, .streakExtended:
            return Color(red: 0.55, green: 0.78, blue: 0.55).opacity(0.5)
        case .resting:
            return Color(red: 0.70, green: 0.80, blue: 0.95).opacity(0.65)
        case .beggingNight:
            return Color(red: 0.68, green: 0.78, blue: 0.92)
        default:
            return Color(red: 0.96, green: 0.85, blue: 0.74)
        }
    }
}
