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
}
