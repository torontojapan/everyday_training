package com.goexercise.app.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * iOS `ReviewRequestControllerTests` の移植。同入力で同判定になることで
 * iOS↔Android のレビュー依頼仕様一致を機械検証する。
 */
class ReviewRequestControllerTest {

    private class FakeStore : ReviewPromptStore {
        var last: Long? = null
        val prompted = mutableSetOf<Int>()
        override fun lastRequestEpochDay(): Long? = last
        override fun setLastRequestEpochDay(day: Long) { last = day }
        override fun promptedMilestones(): Set<Int> = prompted
        override fun addPromptedMilestone(streak: Int) { prompted.add(streak) }
    }

    private fun controller() = ReviewRequestController(FakeStore())

    private val day = LocalDate.of(2026, 6, 1)

    @Test
    fun requestsAtMilestoneStreaks() {
        val c = controller()
        assertTrue(c.shouldRequestReview(7, day))
        assertTrue(c.shouldRequestReview(30, day))
        assertTrue(c.shouldRequestReview(100, day))
    }

    @Test
    fun doesNotRequestAtNonMilestoneStreaks() {
        val c = controller()
        assertFalse(c.shouldRequestReview(1, day))
        assertFalse(c.shouldRequestReview(6, day))
        assertFalse(c.shouldRequestReview(8, day))
        assertFalse(c.shouldRequestReview(0, day))
    }

    @Test
    fun sameMilestoneIsNotPromptedTwice() {
        val c = controller()
        assertTrue(c.shouldRequestReview(7, day))
        c.markRequested(7, day)
        // 同じ節目は再達成しても二度と出さない(200 日後でも)。
        assertFalse(c.shouldRequestReview(7, day.plusDays(200)))
    }

    @Test
    fun respectsMinimumIntervalAcrossDifferentMilestones() {
        val c = controller()
        c.markRequested(7, day)
        // 90 日未満では別の節目でも出さない。
        assertFalse(c.shouldRequestReview(30, day.plusDays(30)))
        // 90 日経過後は別の節目で出せる。
        assertTrue(c.shouldRequestReview(30, day.plusDays(95)))
    }
}
