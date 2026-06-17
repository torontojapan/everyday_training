package com.goexercise.app.domain.friends

import com.goexercise.app.domain.DailyStatus
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 友達の「今週の達成」状態別表示のデータ層検証(iOS 1.3 パリティ)。
 * weeklyStatusesOrEmpty は状態配列があればそれを、無ければ Bool から近似復元する。
 * DailyStatus.fromRaw は未知の rawValue を Future にフォールバックして 7 要素長を保つ。
 */
class FriendWeeklyStatusesTest {

    private fun profile(
        statuses: List<DailyStatus>? = null,
        achievements: List<Boolean>? = null,
    ) = FriendProfile(
        friendCode = "ABCDEF", username = "u", displayName = "d",
        currentStreak = 0, totalAchievedDays = 0, todayAchieved = false,
        weeklyAchievements = achievements, weeklyStatuses = statuses,
    )

    @Test
    fun `uses weeklyStatuses verbatim when present`() {
        val s = listOf(
            DailyStatus.Achieved, DailyStatus.Rest, DailyStatus.Rescued, DailyStatus.Missed,
            DailyStatus.TodayAchieved, DailyStatus.Future, DailyStatus.Future,
        )
        assertEquals(s, profile(statuses = s).weeklyStatusesOrEmpty)
    }

    @Test
    fun `falls back to bool achievements when statuses missing (true to achieved, false to missed)`() {
        val p = profile(achievements = listOf(true, false, true, false, false, false, false))
        assertEquals(
            listOf(
                DailyStatus.Achieved, DailyStatus.Missed, DailyStatus.Achieved, DailyStatus.Missed,
                DailyStatus.Missed, DailyStatus.Missed, DailyStatus.Missed,
            ),
            p.weeklyStatusesOrEmpty,
        )
    }

    @Test
    fun `pads short status lists to 7 with future`() {
        val p = profile(statuses = listOf(DailyStatus.Achieved, DailyStatus.Rest))
        val out = p.weeklyStatusesOrEmpty
        assertEquals(7, out.size)
        assertEquals(DailyStatus.Achieved, out[0])
        assertEquals(DailyStatus.Future, out[6])
    }

    @Test
    fun `empty profile yields 7 missed via bool fallback`() {
        assertEquals(7, profile().weeklyStatusesOrEmpty.size)
        assertEquals(List(7) { DailyStatus.Missed }, profile().weeklyStatusesOrEmpty)
    }

    @Test
    fun `DailyStatus fromRaw matches cross-OS rawValues and falls back to Future for unknown`() {
        assertEquals(DailyStatus.Achieved, DailyStatus.fromRaw("achieved"))
        assertEquals(DailyStatus.Rescued, DailyStatus.fromRaw("rescued"))
        assertEquals(DailyStatus.Rest, DailyStatus.fromRaw("rest"))
        assertEquals(DailyStatus.Missed, DailyStatus.fromRaw("missed"))
        assertEquals(DailyStatus.TodayPending, DailyStatus.fromRaw("todayPending"))
        assertEquals(DailyStatus.TodayAchieved, DailyStatus.fromRaw("todayAchieved"))
        assertEquals(DailyStatus.Future, DailyStatus.fromRaw("future"))
        // 未知値(将来 iOS が追加した case 等)は Future = 配列長を保ち曜日ズレを防ぐ
        assertEquals(DailyStatus.Future, DailyStatus.fromRaw("somethingNew"))
    }

    @Test
    fun `rawValue round-trips through fromRaw`() {
        DailyStatus.entries.forEach { assertEquals(it, DailyStatus.fromRaw(it.rawValue)) }
    }
}
