package com.goexercise.app.domain.friends

/**
 * ランキングの集計期間。週間/月間の両方を 1 つの画面で扱う。iOS `RankingPeriod` の移植。
 */
enum class RankingPeriod(val label: String, val rulesTitle: String, val resetHint: String) {
    Weekly("今週", "今週の順位ルール", "毎週月曜日にリセットされます。"),
    Monthly("今月", "今月の順位ルール", "毎月 1 日にリセットされます。"),
}

/** ランキング 1 行。iOS `WeeklyRankingEntry` の移植。 */
data class WeeklyRankingEntry(
    val profile: FriendProfile,
    /** 期間内の達成日数。 */
    val achievedCount: Int,
    /** 期間内の合計運動時間 (分)。 */
    val totalMinutes: Int,
    val rank: Int,
    val isMe: Boolean,
) {
    val id: String get() = profile.friendCode
}

/**
 * 友達 + 自分を順位化する純粋ロジック。iOS `WeeklyRankingCalculator` の 1:1 移植。
 *
 * 順位ルール (両 period 共通):
 *   1. currentStreak desc
 *   2. period 内 totalMinutes desc
 *   3. period 内 achievedCount desc
 *   4. friendCode 辞書順 (安定ソートのためだけ。順位の根拠にはしない)
 */
object WeeklyRankingCalculator {

    fun rank(
        friends: List<FriendProfile>,
        myProfile: FriendProfile?,
        period: RankingPeriod = RankingPeriod.Weekly,
    ): List<WeeklyRankingEntry> {
        // backend が myProfile を friends にも返すと重複登場するため、
        // friendCode で重複排除してから自分を追加する。
        val all = friends.toMutableList()
        if (myProfile != null) {
            all.removeAll { it.friendCode == myProfile.friendCode }
            all.add(myProfile)
        }

        val sorted = all.sortedWith(
            compareByDescending<FriendProfile> { it.currentStreak }
                .thenByDescending { totalMinutes(it, period) }
                .thenByDescending { achievedCount(it, period) }
                .thenBy { it.friendCode },
        )

        // 完全同点 (streak / minutes / achievedCount すべて一致) は同順位。
        // 例: 1, 1, 3, 4。friendCode の辞書順は安定ソートのためだけに使う。
        val entries = mutableListOf<WeeklyRankingEntry>()
        var lastRank = 0
        sorted.forEachIndexed { index, profile ->
            val ac = achievedCount(profile, period)
            val tm = totalMinutes(profile, period)
            val rank = when {
                index == 0 -> { lastRank = 1; 1 }
                isTied(sorted[index - 1], profile, period) -> lastRank
                else -> { lastRank = index + 1; index + 1 }
            }
            entries.add(
                WeeklyRankingEntry(
                    profile = profile,
                    achievedCount = ac,
                    totalMinutes = tm,
                    rank = rank,
                    isMe = myProfile?.friendCode == profile.friendCode,
                ),
            )
        }
        return entries
    }

    /** ランクづけ上の同点判定 (friendCode は順位の根拠にしない)。 */
    private fun isTied(lhs: FriendProfile, rhs: FriendProfile, period: RankingPeriod): Boolean =
        lhs.currentStreak == rhs.currentStreak &&
            totalMinutes(lhs, period) == totalMinutes(rhs, period) &&
            achievedCount(lhs, period) == achievedCount(rhs, period)

    private fun totalMinutes(profile: FriendProfile, period: RankingPeriod): Int = when (period) {
        RankingPeriod.Weekly -> profile.weeklyTotalMinutes ?: 0
        RankingPeriod.Monthly -> profile.monthlyTotalMinutes ?: 0
    }

    private fun achievedCount(profile: FriendProfile, period: RankingPeriod): Int = when (period) {
        RankingPeriod.Weekly -> profile.weeklyAchievementsOrEmpty.count { it }
        RankingPeriod.Monthly -> profile.monthlyAchievedDays ?: 0
    }
}
