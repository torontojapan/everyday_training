import Foundation

struct WeeklyRankingEntry: Identifiable, Hashable, Sendable {
    var id: String { profile.friendCode }
    let profile: FriendProfile
    /// 今週の達成日数 (0..7)。
    let weeklyAchievedCount: Int
    /// 今週の合計運動時間 (分)。共有していない友達は 0。
    let weeklyMinutes: Int
    let rank: Int
    let isMe: Bool
}

enum WeeklyRankingCalculator {
    /// 順位の決め方:
    ///   1. **今の連続記録 (currentStreak) 降順** — 第一基準。続けている人ほど上。
    ///   2. **今週の合計運動時間 (weeklyTotalMinutes) 降順** — 同点ブレーカー。
    ///   3. **今週の達成日数 (weeklyAchievementsOrEmpty) 降順** — 第三ブレーカー。
    ///   4. friendCode の辞書順 — 完全に等しい場合の安定化。
    ///
    /// 同じ rank が並ばないように dense ranking ではなく **strict ranking**
    /// で 1 つずつ番号を振る (連番 1, 2, 3, ...)。週間ランキングはチーム戦
    /// ではなく個人戦の比較なので「同率 1 位」より「微差でも順位が出る」
    /// 方が運動モチベーションになる。
    static func rank(friends: [FriendProfile], myProfile: FriendProfile?) -> [WeeklyRankingEntry] {
        var all = friends
        if let me = myProfile { all.append(me) }

        let sorted = all.sorted { lhs, rhs in
            if lhs.currentStreak != rhs.currentStreak {
                return lhs.currentStreak > rhs.currentStreak
            }
            let lm = lhs.weeklyTotalMinutes ?? 0
            let rm = rhs.weeklyTotalMinutes ?? 0
            if lm != rm { return lm > rm }
            let lc = lhs.weeklyAchievementsOrEmpty.filter { $0 }.count
            let rc = rhs.weeklyAchievementsOrEmpty.filter { $0 }.count
            if lc != rc { return lc > rc }
            return lhs.friendCode < rhs.friendCode
        }

        return sorted.enumerated().map { index, profile in
            WeeklyRankingEntry(
                profile: profile,
                weeklyAchievedCount: profile.weeklyAchievementsOrEmpty.filter { $0 }.count,
                weeklyMinutes: profile.weeklyTotalMinutes ?? 0,
                rank: index + 1,
                isMe: myProfile?.friendCode == profile.friendCode
            )
        }
    }
}
