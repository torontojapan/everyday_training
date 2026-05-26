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
        // backend (将来の CloudKit) が myProfile を friends にも返すと
        // 重複登場するため、friendCode で重複排除してから自分を追加する。
        var all = friends
        if let me = myProfile {
            all.removeAll { $0.friendCode == me.friendCode }
            all.append(me)
        }

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

        // 同点 (currentStreak / totalMinutes / achievedCount すべて一致) は
        // 同順位で並べる。friendCode の辞書順は安定ソートのためだけに使い、
        // 順位の根拠にはしない。例: 1, 1, 3, 4。
        var entries: [WeeklyRankingEntry] = []
        var lastRank = 0
        for (index, profile) in sorted.enumerated() {
            let ac = achievedCount(of: profile, period: period)
            let tm = totalMinutes(of: profile, period: period)
            let rank: Int
            if index == 0 {
                rank = 1
                lastRank = 1
            } else if isTied(sorted[index - 1], profile, period: period) {
                rank = lastRank
            } else {
                rank = index + 1
                lastRank = rank
            }
            entries.append(WeeklyRankingEntry(
                profile: profile,
                achievedCount: ac,
                totalMinutes: tm,
                rank: rank,
                isMe: myProfile?.friendCode == profile.friendCode
            ))
        }
        return entries
    }

    /// ランクづけ上の同点判定 (friendCode は順位の根拠にしない)。
    private static func isTied(_ lhs: FriendProfile, _ rhs: FriendProfile, period: RankingPeriod) -> Bool {
        lhs.currentStreak == rhs.currentStreak
            && totalMinutes(of: lhs, period: period) == totalMinutes(of: rhs, period: period)
            && achievedCount(of: lhs, period: period) == achievedCount(of: rhs, period: period)
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
