package com.goexercise.app.domain.friends

import org.junit.Assert.assertEquals
import org.junit.Test

/** iOS `FriendSorter` の移植検証 (連続日数順 / 今日達成順)。 */
class FriendSorterTest {

    private fun p(code: String, streak: Int, total: Int = 0, today: Boolean = false) =
        FriendProfile(
            friendCode = code,
            username = code.lowercase(),
            displayName = code,
            currentStreak = streak,
            totalAchievedDays = total,
            todayAchieved = today,
        )

    @Test
    fun streakDesc_ordersByStreakThenTotal() {
        val sorted = FriendSorter.sort(
            listOf(p("A", 5, total = 10), p("B", 30, total = 1), p("C", 5, total = 40)),
            FriendSortOrder.StreakDesc,
        )
        // B(30) 先頭、A と C は streak 同点 → totalAchievedDays で C(40) > A(10)。
        assertEquals(listOf("B", "C", "A"), sorted.map { it.friendCode })
    }

    @Test
    fun todayFirst_putsAchievedFirstThenStreak() {
        val sorted = FriendSorter.sort(
            listOf(p("A", 20, today = false), p("B", 3, today = true), p("C", 8, today = true)),
            FriendSortOrder.TodayFirst,
        )
        // 今日達成 (B,C) が先、その中で streak desc → C(8) > B(3)、未達成 A は最後。
        assertEquals(listOf("C", "B", "A"), sorted.map { it.friendCode })
    }
}
