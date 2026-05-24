import SwiftUI

enum CatDecoration: String, CaseIterable, Identifiable, Sendable {
    case none           //   0 ~ 6 days  — no decoration
    case bandana        //   7 ~ 29 days — coral bandana
    case headband       //  30 ~ 99 days — sport headband
    case medal          // 100 ~ 364 days — bronze medal
    case crown          // 365+ days       — golden crown

    var id: String { rawValue }

    init(totalAchievedDays: Int) {
        switch totalAchievedDays {
        case ..<7: self = .none
        case 7..<30: self = .bandana
        case 30..<100: self = .headband
        case 100..<365: self = .medal
        default: self = .crown
        }
    }

    var displayName: String {
        switch self {
        case .none: return "なし"
        case .bandana: return "バンダナ"
        case .headband: return "ヘッドバンド"
        case .medal: return "メダル"
        case .crown: return "王冠"
        }
    }

    var unlockHint: String {
        switch self {
        case .none: return "7日達成でバンダナがもらえます"
        case .bandana: return "30日達成でヘッドバンドにレベルアップ"
        case .headband: return "100日達成で金色のメダル"
        case .medal: return "365日達成で王冠に!!"
        case .crown: return "最高ランク達成 ✨"
        }
    }

    var symbolName: String {
        switch self {
        case .none: return ""
        case .bandana: return "scribble"        // placeholder
        case .headband: return "sportscourt.fill"
        case .medal: return "medal.fill"
        case .crown: return "crown.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .none: return .clear
        case .bandana: return Color(red: 1.00, green: 0.55, blue: 0.55)
        case .headband: return Color(red: 0.60, green: 0.70, blue: 0.95)
        case .medal: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case .crown: return Color(red: 1.00, green: 0.82, blue: 0.30)
        }
    }
}

struct CatDecorationOverlay: View {
    let decoration: CatDecoration

    var body: some View {
        switch decoration {
        case .none:
            EmptyView()
        case .bandana:
            Image(systemName: "rectangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 8)
                .foregroundStyle(decoration.accentColor)
                .rotationEffect(.degrees(-12))
                .offset(x: 0, y: 22)
                .accessibilityLabel("バンダナ装着")
        case .headband:
            Image(systemName: "rectangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 38, height: 6)
                .foregroundStyle(decoration.accentColor)
                .offset(x: 0, y: -28)
                .accessibilityLabel("ヘッドバンド装着")
        case .medal:
            Image(systemName: "medal.fill")
                .font(.system(size: 22))
                .foregroundStyle(decoration.accentColor)
                .offset(x: 22, y: 16)
                .accessibilityLabel("メダル獲得")
        case .crown:
            Image(systemName: "crown.fill")
                .font(.system(size: 24))
                .foregroundStyle(decoration.accentColor)
                .offset(x: 0, y: -32)
                .accessibilityLabel("王冠装着")
        }
    }
}
