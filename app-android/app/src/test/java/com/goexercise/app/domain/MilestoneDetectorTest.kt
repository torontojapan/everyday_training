package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate

/**
 * iOS `MilestoneDetector` / `WeightLossMilestoneDetector` の純粋判定を移植検証(#8)。
 */
class MilestoneDetectorTest {

    private val today = LocalDate.of(2026, 6, 3)

    @Test
    fun currentStreakMilestones_thresholds() {
        assertEquals(emptyList<Int>(), MilestoneDetector.currentStreakMilestones(9))
        assertEquals(listOf(10), MilestoneDetector.currentStreakMilestones(10))
        assertEquals(listOf(10, 30, 50), MilestoneDetector.currentStreakMilestones(99))
        assertEquals(listOf(10, 30, 50, 100), MilestoneDetector.currentStreakMilestones(100))
        assertEquals(listOf(10, 30, 50, 100, 200, 300), MilestoneDetector.currentStreakMilestones(350))
        // 上限 2000 で打ち切り。
        assertEquals(2000, MilestoneDetector.currentStreakMilestones(5000).last())
    }

    @Test
    fun candidates_anniversaryNeedsAYear() {
        val nonePass = MilestoneDetector.candidates(today.minusMonths(6), today, 0, 0)
        assertEquals(emptyList<Milestone>(), nonePass)
        val oneYear = MilestoneDetector.candidates(today.minusYears(2), today, 0, 0)
        assertEquals(listOf(Milestone.Anniversary(2)), oneYear)
    }

    @Test
    fun candidates_lifetimeAndStreak_order() {
        val c = MilestoneDetector.candidates(
            firstUseDate = null, today = today, lifetimeAchieved = 400, currentStreak = 30,
        )
        // lifetime(100,365 昇順)→ streak(10,30 昇順)。anniversary は firstUse=null で無し。
        assertEquals(
            listOf(
                Milestone.LifetimeDays(100),
                Milestone.LifetimeDays(365),
                Milestone.CurrentStreak(10),
                Milestone.CurrentStreak(30),
            ),
            c,
        )
    }

    @Test
    fun nextPending_returnsFirstUnacknowledged() {
        val c = MilestoneDetector.candidates(null, today, 100, 30)
        // candidates = [lifetime.100, streak.10, streak.30]
        assertEquals(Milestone.LifetimeDays(100), MilestoneDetector.nextPending(c, emptySet()))
        assertEquals(Milestone.CurrentStreak(10), MilestoneDetector.nextPending(c, setOf("lifetime.100")))
        assertEquals(Milestone.CurrentStreak(30), MilestoneDetector.nextPending(c, setOf("lifetime.100", "streak.10")))
        assertNull(MilestoneDetector.nextPending(c, setOf("lifetime.100", "streak.10", "streak.30")))
    }

    @Test
    fun keys_matchIosFormat() {
        assertEquals("anniv.2", Milestone.Anniversary(2).key)
        assertEquals("lifetime.365", Milestone.LifetimeDays(365).key)
        assertEquals("streak.100", Milestone.CurrentStreak(100).key)
        assertEquals("weightLoss.5", Milestone.WeightLoss(5).key)
    }

    @Test
    fun weightLoss_onlyForLossGoalWithProgress() {
        assertEquals(listOf(3, 5), WeightLossMilestoneDetector.reachedThresholds(70.0, 64.8, true))
        assertEquals(emptyList<Int>(), WeightLossMilestoneDetector.reachedThresholds(70.0, 64.8, false)) // 増量目標
        assertEquals(emptyList<Int>(), WeightLossMilestoneDetector.reachedThresholds(70.0, 72.0, true)) // 増えた
        assertEquals(emptyList<Int>(), WeightLossMilestoneDetector.reachedThresholds(null, 64.8, true)) // 開始不明
        assertEquals(listOf(3, 5, 10), WeightLossMilestoneDetector.reachedThresholds(80.0, 69.0, true))
    }

    @Test
    fun weightLoss_flowsIntoCandidates() {
        val snap = MilestoneDetector.WeightLossSnapshot(startKg = 70.0, currentKg = 64.0, isLossGoal = true)
        val c = MilestoneDetector.candidates(null, today, 0, 0, snap)
        assertEquals(listOf(Milestone.WeightLoss(3), Milestone.WeightLoss(5)), c)
    }
}
