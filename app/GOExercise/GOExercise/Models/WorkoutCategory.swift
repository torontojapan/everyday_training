import Foundation

enum WorkoutCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case cardio
    case strength
    case yoga
    case stretch
    case fasciaRelease
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cardio: "有酸素"
        case .strength: "筋トレ"
        case .yoga: "ヨガ"
        case .stretch: "ストレッチ"
        case .fasciaRelease: "筋膜リリース"
        case .other: "その他"
        }
    }

    var symbolName: String {
        switch self {
        case .cardio: "figure.run"
        case .strength: "dumbbell.fill"
        case .yoga: "figure.mind.and.body"
        case .stretch: "figure.cooldown"
        case .fasciaRelease: "figure.flexibility"
        case .other: "sparkles"
        }
    }
}
