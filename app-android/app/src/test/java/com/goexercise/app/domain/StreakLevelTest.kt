package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** iOS `StreakLevelTests.swift` の移植(純粋部分)。 */
class StreakLevelTest {

    @Test
    fun boundaryAssignments() {
        assertEquals(StreakLevel.Zero, StreakLevel.of(0))
        assertEquals(StreakLevel.Sprout, StreakLevel.of(1))
        assertEquals(StreakLevel.Sprout, StreakLevel.of(6))
        assertEquals(StreakLevel.Week, StreakLevel.of(7))
        assertEquals(StreakLevel.Week, StreakLevel.of(13))
        assertEquals(StreakLevel.TwoWeeks, StreakLevel.of(14))
        assertEquals(StreakLevel.TwoWeeks, StreakLevel.of(29))
        assertEquals(StreakLevel.Month, StreakLevel.of(30))
        assertEquals(StreakLevel.Month, StreakLevel.of(99))
        assertEquals(StreakLevel.Century, StreakLevel.of(100))
        assertEquals(StreakLevel.Century, StreakLevel.of(364))
        assertEquals(StreakLevel.Legend, StreakLevel.of(365))
        assertEquals(StreakLevel.Legend, StreakLevel.of(9999))
    }

    @Test
    fun negativeStreakFallsToZero() {
        assertEquals(StreakLevel.Zero, StreakLevel.of(-5))
    }

    @Test
    fun fireCountIncreasesWithLevel() {
        assertEquals(0, StreakLevel.of(0).fireCount)
        assertTrue(StreakLevel.of(5).fireCount < StreakLevel.of(50).fireCount)
        assertTrue(StreakLevel.of(50).fireCount < StreakLevel.of(500).fireCount)
    }

    @Test
    fun sparkleCountIncreasesWithLevel() {
        assertTrue(StreakLevel.of(5).sparkleCount < StreakLevel.of(50).sparkleCount)
        assertTrue(StreakLevel.of(50).sparkleCount < StreakLevel.of(500).sparkleCount)
    }

    @Test
    fun badgeText() {
        assertNull(StreakLevel.of(5).badgeText)
        assertEquals("1 WEEK", StreakLevel.of(7).badgeText)
        assertEquals("CENTURY", StreakLevel.of(100).badgeText)
        assertEquals("LEGEND", StreakLevel.of(365).badgeText)
    }

    @Test
    fun shareMessageContainsAppName() {
        for (streak in listOf(1, 7, 14, 30, 100, 365)) {
            assertTrue(StreakLevel.of(streak).shareMessage.contains("GO エクササイズ"))
        }
    }

    @Test
    fun gradientHasAtLeastTwoColors() {
        // シェアカードの背景は最低 2 色のグラデーション(LinearGradient が成立する)。
        StreakLevel.entries.forEach { assertTrue(it.gradientColors.size >= 2) }
    }

    @Test
    fun catStateMapsLowToCelebratingHighToStreakExtended() {
        assertEquals(CatState.Celebrating, StreakLevel.of(1).catState)
        assertEquals(CatState.Celebrating, StreakLevel.of(14).catState)
        assertEquals(CatState.StreakExtended, StreakLevel.of(30).catState)
        assertEquals(CatState.StreakExtended, StreakLevel.of(365).catState)
    }
}
