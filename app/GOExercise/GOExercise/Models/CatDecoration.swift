import SwiftUI

enum CatDecoration: String, CaseIterable, Identifiable, Sendable {
    case none           //   0 ~ 6 days  — no decoration
    case bandana        //   7 ~ 29 days — coral bandana
    case headband       //  30 ~ 99 days — sport headband
    case medal          // 100 ~ 364 days — bronze medal
    case crown          // 365+ days       — golden crown

    var id: String { rawValue }

    /// `FriendProfile.decorationTier` (0..4) との相互変換用。
    /// none=0 / bandana=1 / headband=2 / medal=3 / crown=4。
    var tier: Int {
        switch self {
        case .none: return 0
        case .bandana: return 1
        case .headband: return 2
        case .medal: return 3
        case .crown: return 4
        }
    }

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
        case .bandana: return "tshirt.fill"
        case .headband: return "sportscourt.fill"
        case .medal: return "medal.fill"
        case .crown: return "crown.fill"
        }
    }

    /// Emoji equivalent for chips/badges where an SF Symbol would look
    /// off-brand (the cat decorations are colorful rather than glyph-like).
    var emoji: String {
        switch self {
        case .none: return ""
        case .bandana: return "🧣"
        case .headband: return "🎀"
        case .medal: return "🥉"
        case .crown: return "👑"
        }
    }

    // RewardCard / FriendAvatarView / FriendDetailView のチップ色に使用。
    // 以前は CatDecorationOverlay でキャラ画像の上に直接描いていたが、
    // Phase 6.4 のキャラ刷新で新アートにヘッドバンド・ジャケット等が
    // 描き込まれたため overlay は二重描画になり顔に色のシミとして残る
    // 不具合を起こしていた (青→緑と色だけ変えても再発)。Phase 7.1 で
    // overlay を撤去、tier はチップ・カード側で表示する方針に統一。
    var accentColor: Color {
        switch self {
        case .none: return .clear
        case .bandana: return Color(red: 1.00, green: 0.55, blue: 0.55)   // 珊瑚赤
        case .headband: return Color(red: 0.45, green: 0.78, blue: 0.55)  // フィットネス緑
        case .medal: return Color(red: 0.90, green: 0.60, blue: 0.20)     // ブロンズ
        case .crown: return Color(red: 1.00, green: 0.82, blue: 0.30)     // 金
        }
    }
}
