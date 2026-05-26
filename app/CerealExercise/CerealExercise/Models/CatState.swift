import Foundation

enum CatState: String, Codable, CaseIterable, Sendable {
    case waitingMorning
    case worriedNoon
    case beggingNight
    case celebrating
    case streakExtended
    case resting
    case encouraging

    var emoji: String {
        switch self {
        case .waitingMorning: "🐱"
        case .worriedNoon: "😿"
        case .beggingNight: "🙀"
        case .celebrating: "😸"
        case .streakExtended: "😻🔥"
        case .resting: "😽"
        case .encouraging: "🐱"
        }
    }

    var displayName: String {
        switch self {
        case .waitingMorning: "待機中"
        case .worriedNoon: "少し心配"
        case .beggingNight: "お願い中"
        case .celebrating: "達成"
        case .streakExtended: "連続更新"
        case .resting: "回復中"
        case .encouraging: "復帰応援"
        }
    }

    /// orange のみ用意してあるボーナス variant 一覧。
    /// 11 種類すべてに全 variant を作ると 132 画像生成になるので、
    /// orange ユーザーだけがローテーションを楽しめる扱いにしている。
    /// (将来人気の出た猫種だけ拡張すれば良い)
    func orangeOnlyVariants() -> [String] {
        switch self {
        case .celebrating: return ["cat_orange_celebrating", "cat_orange_highFive", "cat_orange_drinking"]
        case .resting:     return ["cat_orange_resting", "cat_orange_yogaPose", "cat_orange_stretching"]
        case .encouraging: return ["cat_orange_encouraging", "cat_orange_running", "cat_orange_stretching"]
        case .waitingMorning: return ["cat_orange_waitingMorning", "cat_orange_drinking"]
        default: return ["cat_orange_\(rawValue)"]
        }
    }

    /// 状態と猫種から daily-rotating asset 名を返す。
    /// orange のみ複数 variant、他猫種は 7 状態固定で各 1 画像。
    func assetName(breed: CatBreed,
                   seedDate: Date = Date(),
                   calendar: Calendar = .current) -> String {
        if breed == .orange {
            let variants = orangeOnlyVariants()
            let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
            return variants[abs(day) % variants.count]
        }
        return breed.assetName(for: self)
    }
}
