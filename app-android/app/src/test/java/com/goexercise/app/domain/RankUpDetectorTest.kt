package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * iOS `RankUpDetector` の移植テスト。In-memory ストアで昇格/週間イベントを検証。
 */
class RankUpDetectorTest {

    private class InMemoryStore : RankUpStore {
        val map = mutableMapOf<String, Int>()
        override fun getInt(key: String): Int? = map[key]
        override fun putInt(key: String, value: Int) {
            map[key] = value
        }
    }

    @Test
    fun firstSevenFiresRankUpAndWeekly() {
        val detector = RankUpDetector(InMemoryStore())
        val events = detector.evaluate(7)
        assertTrue(events.contains(RankUpEvent.RankUp(1)))
        assertTrue(events.contains(RankUpEvent.Weekly(7)))
    }

    @Test
    fun repeatedSameStreakFiresNothing() {
        val detector = RankUpDetector(InMemoryStore())
        detector.evaluate(7)
        val events = detector.evaluate(7)
        assertTrue(events.isEmpty())
    }

    @Test
    fun dropToZeroIsSilentThenSevenRefires() {
        val detector = RankUpDetector(InMemoryStore())
        detector.evaluate(7)

        val zero = detector.evaluate(0)
        assertTrue(zero.isEmpty())

        val again = detector.evaluate(7)
        assertTrue(again.contains(RankUpEvent.RankUp(1)))
        assertTrue(again.contains(RankUpEvent.Weekly(7)))
    }

    @Test
    fun weeklyFiresWithoutRankUpWhenOnlyMultipleAdvances() {
        val detector = RankUpDetector(InMemoryStore())
        detector.evaluate(30) // rank 3, multiple 28
        val events = detector.evaluate(35) // rank 3 (still), multiple 35
        assertTrue(events.contains(RankUpEvent.Weekly(35)))
        assertEquals(1, events.size) // no RankUp
    }
}
