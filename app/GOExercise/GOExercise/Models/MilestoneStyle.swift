import Foundation

/// 達成日数で決まる猫の装着アイテム(累積)。アバター(単一ポーズ)にのみ焼き込む。
enum MilestoneItem: Equatable {
    case none          // 0..<30
    case shaker        // 30..<100
    case shakerCrown   // 100+

    init(totalAchievedDays days: Int) {
        switch days {
        case ..<30: self = .none
        case 30..<100: self = .shaker
        default: self = .shakerCrown
        }
    }

    /// アバター asset 名に付与する接尾辞。crown アートはシェイカーも内包(累積)。
    var assetSuffix: String {
        switch self {
        case .none: return ""
        case .shaker: return "_shaker"
        case .shakerCrown: return "_crown"
        }
    }
}

/// 達成日数で決まる背景ランク。breed 非依存・猫の後ろのレイヤー。
struct MilestoneBackground: Equatable {
    static let thresholds = [7, 14, 30, 50, 75, 100, 150, 200, 300, 365, 500]

    let tier: Int   // 0 = 背景なし、1..thresholds.count

    init(totalAchievedDays days: Int) {
        var t = 0
        for (i, th) in Self.thresholds.enumerated() where days >= th { t = i + 1 }
        self.tier = t
    }

    /// 背景アセット名。tier0 は nil(背景なし)。
    var assetName: String? {
        tier == 0 ? nil : String(format: "bg_milestone_%02d", tier)
    }
}
