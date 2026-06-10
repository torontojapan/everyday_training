// ReferralStarsDisplay.swift
import Foundation

/// ホームの紹介スター行の表示モード(純ロジック)。
enum ReferralStarsDisplay: Equatable {
    case ghost
    case progress(filled: Int, total: Int)
    case complete
    case collapsed(Int)

    static func style(count: Int) -> ReferralStarsDisplay {
        switch count {
        case ..<1:  return .ghost
        case 1...9: return .progress(filled: count, total: ReferralReward.breedUnlockThreshold)
        case 10:    return .complete
        default:    return .collapsed(count)
        }
    }
}

/// 紹介の報酬閾値と解放判定(純ロジック)。
enum ReferralReward {
    static let breedUnlockThreshold = 10
    static func isBreedUnlocked(starBadges: Int) -> Bool {
        starBadges >= breedUnlockThreshold
    }
}
