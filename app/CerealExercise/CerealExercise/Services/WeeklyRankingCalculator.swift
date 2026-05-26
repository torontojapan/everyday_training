import Foundation

/// ランキングの集計期間。週間/月間の両方を 1 つの View で扱う。
enum RankingPeriod: String, CaseIterable, Identifiable, Sendable {
    case weekly, monthly
    var id: String { rawValue }

    var label: String {
        switch self {
        case .weekly:  return "今週"
        case .monthly: return "今月"
        }
    }

    var rulesTitle: String {
        switch self {
        case .weekly:  return "今週の順位ルール"
        case .monthly: return "今月の順位ルール"
        }
    }

    var resetHint: String {
        switch self {
        case .weekly:  return "毎週月曜日にリセットされます。"
        case .monthly: return "毎月 1 日にリセットされます。"
        }
    }
}

struct WeeklyRankingEntry: Identifiable, Hashable, Sendable {
    var id: String { profile.friendCode }
    let profile: FriendProfile
    /// 期間内の達成日数。
    let achievedCount: Int
    /// 期間内の合計運動時間 (分)。
    let totalMinutes: Int
    let rank: Int
    let isMe: Bool
}

enum WeeklyRankingCalculator {
    /// 順位ルール (両 period 共通):
    ///   1. currentStreak desc
    ///   2. period 内 totalMinutes desc
    ///   3. period 内 achievedCount desc
    ///   4. friendCode 辞書順 (安定)
    static func rank(friends: [FriendProfile],
                     myProfile: FriendProfile?,
                     period: RankingPeriod = .weekly) -> [WeeklyRankingEntry] {
        var all = friends
        if let me = myProfile { all.append(me) }

        let sorted = all.sorted { lhs, rhs in
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            let lm = totalMinutes(of: lhs, period: period)
            let rm = totalMinutes(of: rhs, period: period)
            if lm != rm { return lm > rm }
            let lc = achievedCount(of: lhs, period: period)
            let rc = achievedCount(of: rhs, period: period)
            if lc != rc { return lc > rc }
            return lhs.friendCode < rhs.friendCode
        }

        return sorted.enumerated().map { index, profile in
            WeeklyRankingEntry(
                profile: profile,
                achievedCount: achievedCount(of: profile, period: period),
                totalMinutes: totalMinutes(of: profile, period: period),
                rank: index + 1,
                isMe: myProfile?.friendCode == profile.friendCode
            )
        }
    }

    private static func totalMinutes(of profile: FriendProfile, period: RankingPeriod) -> Int {
        switch period {
        case .weekly:  return profile.weeklyTotalMinutes ?? 0
        case .monthly: return profile.monthlyTotalMinutes ?? 0
        }
    }

    private static func achievedCount(of profile: FriendProfile, period: RankingPeriod) -> Int {
        switch period {
        case .weekly:  return profile.weeklyAchievementsOrEmpty.filter { $0 }.count
        case .monthly: return profile.monthlyAchievedDays ?? 0
        }
    }
}
