package com.goexercise.app.domain.friends

/**
 * 友達一覧の並び順。iOS `FriendSortOrder` の移植。
 * iOS の `.recentlyUpdated` は `lastUpdated` 依存だが、Android [FriendProfile] は
 * その項目を持たない (P1b-1 で必要な集計に絞った) ため、当面 2 種に絞る。
 */
enum class FriendSortOrder(val label: String) {
    StreakDesc("連続日数順"),
    TodayFirst("今日達成順"),
}

/** 友達一覧のソート。iOS `FriendSorter` の移植 (純粋・安定)。 */
object FriendSorter {
    fun sort(friends: List<FriendProfile>, order: FriendSortOrder): List<FriendProfile> = when (order) {
        FriendSortOrder.StreakDesc ->
            friends.sortedWith(
                compareByDescending<FriendProfile> { it.currentStreak }
                    .thenByDescending { it.totalAchievedDays },
            )
        FriendSortOrder.TodayFirst ->
            friends.sortedWith(
                compareByDescending<FriendProfile> { it.todayAchieved }
                    .thenByDescending { it.currentStreak },
            )
    }
}
