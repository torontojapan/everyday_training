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

    /// 状態と猫種から asset 名を返す。各 state × breed で 1 画像 (7 × 11 = 77 枚)。
    /// 以前は orange のみ daily-rotating の variant (highFive / drinking /
    /// running / stretching / yogaPose) を持っていたが、これらの画像に青色滲み
    /// や他 breed とのスタイル不一致があったため一掃して各 state 単一画像に絞った。
    func assetName(breed: CatBreed,
                   seedDate: Date = Date(),
                   calendar: Calendar = .current) -> String {
        breed.assetName(for: self)
    }
}
