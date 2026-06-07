package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * iOS `CatRank` の純ロジック移植テスト。閾値境界/称号/メタル/richness を機械検証。
 */
class CatRankTest {

    @Test
    fun rankBoundaries() {
        assertEquals(0, CatRank.of(0).rank)
        assertEquals(0, CatRank.of(6).rank)
        assertEquals(1, CatRank.of(7).rank)
        assertEquals(1, CatRank.of(13).rank)
        assertEquals(2, CatRank.of(14).rank)
        assertEquals(2, CatRank.of(29).rank)
        assertEquals(3, CatRank.of(30).rank)
        assertEquals(3, CatRank.of(49).rank)
        assertEquals(4, CatRank.of(50).rank)
        assertEquals(5, CatRank.of(75).rank)
        assertEquals(6, CatRank.of(100).rank)
        assertEquals(7, CatRank.of(150).rank)
        assertEquals(8, CatRank.of(200).rank)
        assertEquals(9, CatRank.of(300).rank)
        assertEquals(10, CatRank.of(365).rank)
        assertEquals(10, CatRank.of(499).rank)
        assertEquals(11, CatRank.of(500).rank)
        assertEquals(11, CatRank.of(99999).rank)
    }

    @Test
    fun negativeStreakClampsToZero() {
        assertEquals(0, CatRank.of(-1).rank)
        assertEquals(0, CatRank.of(-100).rank)
    }

    @Test
    fun titleAndMetalAtKeyRanks() {
        // rank 0 → null
        assertNull(CatRank.of(0).title)
        assertNull(CatRank.of(0).metalKind)

        // rank 1 (7) → みならい / Bronze
        assertEquals("みならいネコ", CatRank.of(7).title)
        assertEquals(MetalKind.Bronze, CatRank.of(7).metalKind)

        // rank 3 (30) → Silver
        assertEquals(MetalKind.Silver, CatRank.of(30).metalKind)

        // rank 6 (100) → Gold
        assertEquals(MetalKind.Gold, CatRank.of(100).metalKind)

        // rank 10 (365) → Platinum
        assertEquals(MetalKind.Platinum, CatRank.of(365).metalKind)

        // rank 11 (500) → ぬし / Rainbow
        assertEquals("ぬしネコ", CatRank.of(500).title)
        assertEquals(MetalKind.Rainbow, CatRank.of(500).metalKind)
    }

    @Test
    fun richnessBounds() {
        assertEquals(0.0, CatRank.of(0).richness, 1e-9)
        assertEquals(1.0, CatRank.of(500).richness, 1e-9)
    }
}
