import Foundation

struct WeeklyRankingEntry: Identifiable, Hashable, Sendable {
    var id: String { profile.friendCode }
    let profile: FriendProfile
    let weeklyAchievedCount: Int
    let rank: Int
    let isMe: Bool
}

enum WeeklyRankingCalculator {
    /// Build a ranked list of `friends + myProfile` for the current week.
    /// Sort key: weekly achieved count desc, tiebreaker = currentStreak desc.
    /// Each entry exposes its 1-based rank with **dense ranking** so ties
    /// share the same number ("1 1 3" not "1 1 2") — this matches user
    /// intuition: if two friends are tied for #1, the next one is #3.
    static func rank(friends: [FriendProfile], myProfile: FriendProfile?) -> [WeeklyRankingEntry] {
        var all = friends
        if let me = myProfile {
            all.append(me)
        }

        let sorted = all.sorted { lhs, rhs in
            let lhsCount = lhs.weeklyAchievementsOrEmpty.filter { $0 }.count
            let rhsCount = rhs.weeklyAchievementsOrEmpty.filter { $0 }.count
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            if lhs.currentStreak != rhs.currentStreak { return lhs.currentStreak > rhs.currentStreak }
            // Stable: lexicographic on friendCode so the order is deterministic
            // for screenshots / tests.
            return lhs.friendCode < rhs.friendCode
        }

        var entries: [WeeklyRankingEntry] = []
        var currentRank = 0
        var lastCount = -1
        var lastStreak = -1
        for (index, profile) in sorted.enumerated() {
            let count = profile.weeklyAchievementsOrEmpty.filter { $0 }.count
            // Tie definition: same achievement count AND same streak. Otherwise
            // they get distinct ranks even if the achievement count matches.
            if count != lastCount || profile.currentStreak != lastStreak {
                currentRank = index + 1
                lastCount = count
                lastStreak = profile.currentStreak
            }
            entries.append(WeeklyRankingEntry(
                profile: profile,
                weeklyAchievedCount: count,
                rank: currentRank,
                isMe: myProfile?.friendCode == profile.friendCode
            ))
        }
        return entries
    }
}
