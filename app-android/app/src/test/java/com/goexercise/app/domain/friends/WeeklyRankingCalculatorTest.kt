package com.goexercise.app.domain.friends

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * iOS `GOExerciseTests/WeeklyRankingCalculatorTests.swift` の移植。
 * iOS↔Android のランキング順位ルール一致を機械検証する。
 */
class WeeklyRankingCalculatorTest {

    private fun make(
        code: String,
        streak: Int = 0,
        minutes: Int? = 0,
        weeklyDays: Int = 0,
    ): FriendProfile {
        val weekly = List(7) { it < minOf(weeklyDays, 7) }
        return FriendProfile(
            friendCode = code,
            username = code.lowercase(),
            displayName = code,
            currentStreak = streak,
            totalAchievedDays = 0,
            todayAchieved = false,
            weeklyAchievements = weekly,
            weeklyTotalMinutes = minutes,
        )
    }

    @Test
    fun ranksByStreakDescending() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(make("A", streak = 5), make("B", streak = 30), make("C", streak = 10)),
            myProfile = null,
        )
        assertEquals(listOf("B", "C", "A"), ranked.map { it.profile.friendCode })
        assertEquals(listOf(1, 2, 3), ranked.map { it.rank })
    }

    @Test
    fun streakTieBrokenByMinutes() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(make("A", streak = 10, minutes = 60), make("B", streak = 10, minutes = 180)),
            myProfile = null,
        )
        assertEquals(listOf("B", "A"), ranked.map { it.profile.friendCode })
    }

    @Test
    fun streakAndMinutesTieBrokenByWeeklyDays() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(
                make("AAA", streak = 10, minutes = 100, weeklyDays = 3),
                make("BBB", streak = 10, minutes = 100, weeklyDays = 6),
            ),
            myProfile = null,
        )
        assertEquals(listOf("BBB", "AAA"), ranked.map { it.profile.friendCode })
    }

    @Test
    fun includesAndFlagsMe() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(make("A", streak = 4)),
            myProfile = make("ME", streak = 12),
        )
        assertEquals(2, ranked.size)
        assertEquals("ME", ranked.first().profile.friendCode)
        assertTrue(ranked.first().isMe)
    }

    @Test
    fun entryExposesMinutesAndWeeklyCount() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(make("P", streak = 7, minutes = 95, weeklyDays = 4)),
            myProfile = null,
        )
        assertEquals(95, ranked.first().totalMinutes)
        assertEquals(4, ranked.first().achievedCount)
    }

    @Test
    fun emptyInputYieldsEmptyRanking() {
        assertTrue(WeeklyRankingCalculator.rank(friends = emptyList(), myProfile = null).isEmpty())
    }

    @Test
    fun onlyMeYieldsRank1() {
        val ranked = WeeklyRankingCalculator.rank(friends = emptyList(), myProfile = make("ME", streak = 2))
        assertEquals(1, ranked.size)
        assertEquals(1, ranked.first().rank)
        assertTrue(ranked.first().isMe)
    }

    /** 完全同点 (streak / minutes / achievedCount すべて一致) は同順位 (1, 1, 3 …)。 */
    @Test
    fun fullTieGetsSameRank() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(
                make("AAA", streak = 10, minutes = 60, weeklyDays = 5),
                make("BBB", streak = 10, minutes = 60, weeklyDays = 5),
            ),
            myProfile = null,
        )
        assertEquals(listOf(1, 1), ranked.map { it.rank })
        assertEquals(listOf("AAA", "BBB"), ranked.map { it.profile.friendCode })
    }

    @Test
    fun missingWeeklyMinutesTreatedAsZero() {
        val ranked = WeeklyRankingCalculator.rank(
            friends = listOf(make("BARE", streak = 5, minutes = null), make("OTHER", streak = 5, minutes = 30)),
            myProfile = null,
        )
        assertEquals("OTHER", ranked.first().profile.friendCode)
        assertEquals(0, ranked.last().totalMinutes)
    }

    @Test
    fun monthlyPeriodUsesMonthlyFields() {
        val a = make("A", streak = 5).copy(monthlyTotalMinutes = 200, monthlyAchievedDays = 12)
        val b = make("B", streak = 5).copy(monthlyTotalMinutes = 50, monthlyAchievedDays = 3)
        val ranked = WeeklyRankingCalculator.rank(listOf(a, b), null, RankingPeriod.Monthly)
        assertEquals(listOf("A", "B"), ranked.map { it.profile.friendCode })
        assertEquals(200, ranked.first().totalMinutes)
        assertEquals(12, ranked.first().achievedCount)
    }
}
