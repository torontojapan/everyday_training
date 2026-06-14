package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * CatBreed の drawable 名生成(#7)。**全 lowercase**で res/drawable の webp 名と一致することを
 * 機械検証する(camelCase の state rawValue を取りこぼすと画像が出ないため)。
 */
class CatBreedTest {

    @Test
    fun assetName_isAllLowercase() {
        assertEquals("cat_orange_waitingmorning", CatBreed.Orange.assetName(CatState.WaitingMorning))
        assertEquals("cat_black_streakextended", CatBreed.Black.assetName(CatState.StreakExtended))
        assertEquals("cat_calico_beggingnight", CatBreed.Calico.assetName(CatState.BeggingNight))
    }

    @Test
    fun avatarAndFallback_namesMatchAssets() {
        assertEquals("cat_silvertabby_waitingmorning", CatBreed.SilverTabby.avatarAssetName)
        assertEquals("cat_orange_celebrating", CatBreed.fallbackAssetName(CatState.Celebrating))
        assertEquals("cat_orange_waitingmorning", CatBreed.FALLBACK_AVATAR)
    }

    @Test
    fun fromRaw_defaultsToOrange() {
        assertEquals(CatBreed.Black, CatBreed.fromRaw("black"))
        assertEquals(CatBreed.Default, CatBreed.fromRaw(null))
        assertEquals(CatBreed.Default, CatBreed.fromRaw("bogus"))
        assertEquals(CatBreed.Orange, CatBreed.Default)
    }

    @Test
    fun randomHappyPose_cyclesAllThree_whenPresent() {
        val names = (0..2).map { CatBreed.Orange.randomHappyPoseAsset(it) { true } }.toSet()
        assertEquals(
            setOf("cat_orange_celebrating", "cat_orange_happy2", "cat_orange_happy3"),
            names,
        )
    }

    @Test
    fun randomHappyPose_isDeterministicForSameSeed() {
        assertEquals(
            CatBreed.Black.randomHappyPoseAsset(42) { true },
            CatBreed.Black.randomHappyPoseAsset(42) { true },
        )
    }

    @Test
    fun randomHappyPose_onlyCelebrating_whenOthersMissing() {
        for (seed in 0..4) {
            assertEquals(
                "cat_calico_celebrating",
                CatBreed.Calico.randomHappyPoseAsset(seed) { it == "cat_calico_celebrating" },
            )
        }
    }

    @Test
    fun randomHappyPose_fallsBackToOrange_whenNonePresent() {
        assertEquals("cat_orange_celebrating", CatBreed.Persian.randomHappyPoseAsset(7) { false })
    }

    @Test
    fun randomHappyPose_handlesNegativeSeed() {
        // Math.floorMod で負 seed でも 0..size-1 に収まる(crash しない)。
        val name = CatBreed.Orange.randomHappyPoseAsset(-5) { true }
        assert(name.startsWith("cat_orange_")) { name }
    }

    @Test
    fun allBreeds_haveValidResourceNames() {
        // 11 breeds × 7 states = 77、全て [a-z0-9_] で res 名規約を満たす。
        val pattern = Regex("^cat_[a-z]+_[a-z]+$")
        CatBreed.entries.forEach { breed ->
            CatState.entries.forEach { state ->
                val name = breed.assetName(state)
                assert(pattern.matches(name)) { "invalid resource name: $name" }
            }
        }
        assertEquals(77, CatBreed.entries.size * CatState.entries.size)
    }
}
