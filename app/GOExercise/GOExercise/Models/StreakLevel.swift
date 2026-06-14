import SwiftUI

enum StreakLevel {
    case zero       // 0 days — share is disabled
    case sprout     // 1-6 days
    case week       // 7-13 days
    case twoWeeks   // 14-29 days
    case month      // 30-99 days
    case century    // 100-364 days
    case legend     // 365+ days

    init(streak: Int) {
        switch streak {
        case ..<1: self = .zero
        case 1...6: self = .sprout
        case 7...13: self = .week
        case 14...29: self = .twoWeeks
        case 30...99: self = .month
        case 100...364: self = .century
        default: self = .legend
        }
    }

    /// 称賛の見出し。**具体的な日数には言及しない**(実日数は KPI、英称号はバッジが担う)。
    /// 旧 "1年達成"(legend=365+ 全部で固定)は 500 日でも「1年達成」と出て過小に
    /// 見える指摘があり廃止。絵文字 🎉✨ もブランド方針で除去。
    var headline: String {
        switch self {
        case .zero: return "今日から始めよう"
        case .sprout: return "いい調子！"
        case .week: return "1週間つづいた！"
        case .twoWeeks: return "2週間つづいた！"
        case .month: return "習慣になってきた！"
        case .century: return "偉業の領域！"
        case .legend: return "継続のレジェンド！"
        }
    }

    var fireCount: Int {
        switch self {
        case .zero: return 0
        case .sprout: return 1
        case .week: return 2
        case .twoWeeks: return 3
        case .month: return 4
        case .century: return 5
        case .legend: return 6
        }
    }

    var sparkleCount: Int {
        switch self {
        case .zero: return 0
        case .sprout: return 3
        case .week: return 6
        case .twoWeeks: return 10
        case .month: return 14
        case .century: return 20
        case .legend: return 28
        }
    }

    @MainActor
    var gradientColors: [Color] {
        switch self {
        case .zero, .sprout:
            return [Palette.secondary, Palette.primary.opacity(0.7)]
        case .week:
            return [Palette.primary, Palette.success.opacity(0.7)]
        case .twoWeeks:
            return [Color(red: 1.00, green: 0.55, blue: 0.50), Color(red: 0.95, green: 0.78, blue: 0.30)]
        case .month:
            return [Color(red: 1.00, green: 0.43, blue: 0.31), Color(red: 0.96, green: 0.62, blue: 0.20)]
        case .century:
            return [Color(red: 0.55, green: 0.30, blue: 0.95), Color(red: 1.00, green: 0.55, blue: 0.50), Color(red: 1.00, green: 0.85, blue: 0.30)]
        case .legend:
            return [Color(red: 1.00, green: 0.85, blue: 0.30), Color(red: 0.95, green: 0.45, blue: 0.75), Color(red: 0.55, green: 0.30, blue: 0.95), Color(red: 0.30, green: 0.75, blue: 0.95)]
        }
    }

    /// シェアカードに出す猫キャラ画像。Phase 6.7 以降、ユーザーが選んだ
    /// 猫種で出すために CatState 経由で解決する。
    @MainActor
    var catStateAssetName: String {
        let breed = UserCatPreferences.shared.myCat
        // 全レベルで celebrating(喜ぶ猫)に統一。streakExtended(炎を背負う猫)は
        // 「ダサい」というユーザー指摘で共有カードから廃止。祝祭感は紙吹雪で出す。
        let state: CatState = .celebrating
        return state.assetName(breed: breed)
    }

    var fallbackEmoji: String {
        switch self {
        case .zero, .sprout, .week, .twoWeeks, .month, .century, .legend: return "😻"
        }
    }

    var badgeText: String? {
        switch self {
        case .legend: return "LEGEND"
        case .century: return "CENTURY"
        case .month: return "MONTH"
        case .twoWeeks: return "2 WEEKS"
        case .week: return "1 WEEK"
        case .sprout, .zero: return nil
        }
    }

    var shareMessage: String {
        switch self {
        case .zero:
            return "GO エクササイズで運動を始めました"
        case .sprout:
            return "GO エクササイズで運動継続中"
        case .week, .twoWeeks:
            return "GO エクササイズで運動続けてます"
        case .month, .century:
            return "GO エクササイズで運動の習慣化に成功"
        case .legend:
            return "GO エクササイズで運動を継続中 #LEGEND"
        }
    }
}
