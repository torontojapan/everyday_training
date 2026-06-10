package com.goexercise.app.presentation

import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatDecoration
import com.goexercise.app.domain.CatRank
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.domain.ExerciseTrendSummary
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.StreakState
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.presentation.home.HomeUiState
import com.goexercise.app.presentation.home.MyFriendProfileBuilder
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import java.time.LocalDate

/** 自分の HomeUiState から友達BEへ publish する FriendProfile を組む純粋関数の検証(iOS HomeView ミラー)。 */
class MyFriendProfileBuilderTest {

    private val monday = LocalDate.of(2026, 6, 1) // 月曜
    private val identity = FriendProfile(
        friendCode = "ABCDEF", username = "jun", displayName = "ジュン",
        currentStreak = 0, totalAchievedDays = 0, todayAchieved = false,
    )

    private fun state(): HomeUiState {
        // 月=achieved, 火=rest(=達成扱い), 水=missed, 木=todayAchieved, 金-日=future
        val week = listOf(
            DailyStatusEntry(monday, DailyStatus.Achieved, emptyList()),
            DailyStatusEntry(monday.plusDays(1), DailyStatus.Rest, emptyList()),
            DailyStatusEntry(monday.plusDays(2), DailyStatus.Missed, emptyList()),
            DailyStatusEntry(monday.plusDays(3), DailyStatus.TodayAchieved, emptyList()),
            DailyStatusEntry(monday.plusDays(4), DailyStatus.Future, emptyList()),
            DailyStatusEntry(monday.plusDays(5), DailyStatus.Future, emptyList()),
            DailyStatusEntry(monday.plusDays(6), DailyStatus.Future, emptyList()),
        )
        return HomeUiState(
            streak = StreakState(currentStreak = 5, longestStreak = 9, lastAchievedDate = monday.plusDays(3)),
            weekStatuses = week,
            todayStatus = DailyStatus.TodayAchieved,
            catBreed = CatBreed.Black,
            lifetimeStats = LifetimeStatsCalculator.Stats(achievedDays = 23, usedDays = 30),
            catDecoration = CatDecoration.of(23),
            todaySummary = ExerciseTrendSummary.DailySummary(
                categoryCounts = mapOf(WorkoutCategory.Strength to 2, WorkoutCategory.Cardio to 1),
                exerciseCount = 3, totalDurationSeconds = 600,
            ),
            weeklySummary = ExerciseTrendSummary.WeeklySummary(
                usedCategories = listOf(WorkoutCategory.Strength),
                totalDurationSeconds = 1800, topExerciseNames = emptyList(),
            ),
            monthlyTotalMinutes = 240,
            monthlyAchievedDays = 12,
        )
    }

    @Test
    fun `build merges live stats while keeping identity`() {
        val p = MyFriendProfileBuilder.build(state(), identity)
        // identity 不変
        assertEquals("ABCDEF", p.friendCode)
        assertEquals("jun", p.username)
        assertEquals("ジュン", p.displayName)
        // 統計は state 由来
        assertEquals(5, p.currentStreak)
        assertEquals(23, p.totalAchievedDays)
        assertEquals(true, p.todayAchieved)
        assertEquals(CatBreed.Black, p.myCatBreed)
        assertEquals(30, p.weeklyTotalMinutes) // 1800s / 60
        assertEquals(240, p.monthlyTotalMinutes)
        assertEquals(12, p.monthlyAchievedDays)
        // iOS パリティ: decorationTier は CatRank.rank(連続記録ベース)を publish する。
        // currentStreak=5 は最初の閾値 7 未満なので rank=0(旧 CatDecoration.of(23).tier ではない)。
        assertEquals(CatRank.of(5).rank, p.decorationTier)
        // weekly_achievements は countsAsAchieved(rest/todayAchieved 含む)= iOS と同一
        assertEquals(
            listOf(true, true, false, true, false, false, false),
            p.weeklyAchievements,
        )
        // today カテゴリは最多カウントの displayName(筋トレ)
        assertEquals(WorkoutCategory.Strength.displayName, p.todayCategoryName)
    }

    @Test
    fun `statsSignature changes when a stat changes but not for identity`() {
        val s = state()
        val base = MyFriendProfileBuilder.statsSignature(s)
        // identity を変えてもシグネチャは不変(identity 非依存)
        assertEquals(base, MyFriendProfileBuilder.statsSignature(s))
        // streak が変わるとシグネチャが変わる
        val changed = s.copy(streak = s.streak.copy(currentStreak = 6))
        assertNotEquals(base, MyFriendProfileBuilder.statsSignature(changed))
    }

    @Test
    fun `decorationTier publishes streak-based CatRank, not lifetime CatDecoration`() {
        // currentStreak=7 はランク閾値(最初の閾値 7)を跨ぐので rank=1。
        // 旧実装は生涯達成 23 日由来の CatDecoration.of(23).tier を publish していた(divergence の原因)。
        val s = state().copy(streak = state().streak.copy(currentStreak = 7))
        val p = MyFriendProfileBuilder.build(s, identity)
        assertEquals(CatRank.of(7).rank, p.decorationTier)
        assertEquals(1, p.decorationTier)
        // 連続が閾値を跨ぐとシグネチャも変わる(再 publish が走る)。
        assertNotEquals(
            MyFriendProfileBuilder.statsSignature(state().copy(streak = state().streak.copy(currentStreak = 6))),
            MyFriendProfileBuilder.statsSignature(s),
        )
    }
}
