import Foundation

struct MonthlyRankingEntry: Identifiable, Hashable, Sendable {
    var id: String { profile.friendCode }
    let profile: FriendProfile
    let monthlyAchievedDays: Int
    let rank: Int
    let isMe: Bool
}

enum MonthlyRankingCalculator {
    /// Rank friends + self by monthly achieved days (dense ranking, same tie
    /// rules as the weekly variant).
    static func rank(friends: [FriendProfile], myProfile: FriendProfile?) -> [MonthlyRankingEntry] {
        var all = friends
        if let me = myProfile { all.append(me) }

        let sorted = all.sorted { lhs, rhs in
            let l = lhs.monthlyAchievedDays ?? 0
            let r = rhs.monthlyAchievedDays ?? 0
            if l != r { return l > r }
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            return lhs.friendCode < rhs.friendCode
        }

        var entries: [MonthlyRankingEntry] = []
        var currentRank = 0
        var lastCount = -1
        var lastStreak = -1
        for (index, profile) in sorted.enumerated() {
            let count = profile.monthlyAchievedDays ?? 0
            if count != lastCount || profile.currentStreak != lastStreak {
                currentRank = index + 1
                lastCount = count
                lastStreak = profile.currentStreak
            }
            entries.append(MonthlyRankingEntry(
                profile: profile,
                monthlyAchievedDays: count,
                rank: currentRank,
                isMe: myProfile?.friendCode == profile.friendCode
            ))
        }
        return entries
    }
}
