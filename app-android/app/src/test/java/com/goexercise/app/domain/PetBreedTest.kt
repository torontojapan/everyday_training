package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PetBreed(猫 or 犬)の asset 名生成 / 永続化文字列の往復 / フォールバックを機械検証する。
 * 犬の drawable 名も **全 lowercase**(dog_<breed>_<state>)で res の webp 名と一致する必要がある。
 */
class PetBreedTest {

    @Test
    fun dogAssetName_isAllLowercase() {
        assertEquals("dog_shiba_waitingmorning", DogBreed.Shiba.assetName(CatState.WaitingMorning))
        assertEquals("dog_golden_streakextended", DogBreed.Golden.assetName(CatState.StreakExtended))
        assertEquals("dog_bulldog_beggingnight", DogBreed.Bulldog.assetName(CatState.BeggingNight))
    }

    @Test
    fun petAssetName_routesBySpecies() {
        assertEquals("cat_orange_celebrating", PetBreed.Cat(CatBreed.Orange).assetName(CatState.Celebrating))
        assertEquals("dog_toypoodle_celebrating", PetBreed.Dog(DogBreed.ToyPoodle).assetName(CatState.Celebrating))
    }

    @Test
    fun storage_roundTrips() {
        val cases = listOf(
            PetBreed.Cat(CatBreed.Orange),
            PetBreed.Cat(CatBreed.Tuxedo),
            PetBreed.Dog(DogBreed.Shiba),
            PetBreed.Dog(DogBreed.Chihuahua),
        )
        cases.forEach { pet ->
            assertEquals(pet, PetBreed.fromStorage(pet.storageValue))
        }
        assertEquals("cat:orange", PetBreed.Cat(CatBreed.Orange).storageValue)
        assertEquals("dog:shiba", PetBreed.Dog(DogBreed.Shiba).storageValue)
    }

    @Test
    fun fromStorage_legacyAndBogus_fallBackToCat() {
        // 旧形式(prefix 無し = 猫 rawValue)の救済。
        assertEquals(PetBreed.Cat(CatBreed.Black), PetBreed.fromStorage("black"))
        // null/空/未知は既定(orange 猫)。
        assertEquals(PetBreed.Default, PetBreed.fromStorage(null))
        assertEquals(PetBreed.Default, PetBreed.fromStorage(""))
        assertEquals(PetBreed.Cat(CatBreed.Orange), PetBreed.Default)
    }

    @Test
    fun fallback_staysWithinSpecies() {
        assertEquals("cat_orange_resting", PetBreed.Cat(CatBreed.Persian).fallbackAssetName(CatState.Resting))
        assertEquals("dog_shiba_resting", PetBreed.Dog(DogBreed.Bulldog).fallbackAssetName(CatState.Resting))
    }

    @Test
    fun dogRandomHappyPose_isDogPrefixedAndDeterministic() {
        val a = PetBreed.Dog(DogBreed.Golden).randomHappyPoseAsset(42) { true }
        val b = PetBreed.Dog(DogBreed.Golden).randomHappyPoseAsset(42) { true }
        assertEquals(a, b)
        assertTrue(a, a.startsWith("dog_golden_"))
    }

    @Test
    fun dogRandomHappyPose_fallsBackToDogShiba_whenNonePresent() {
        assertEquals("dog_shiba_celebrating", PetBreed.Dog(DogBreed.Chihuahua).randomHappyPoseAsset(3) { false })
    }

    @Test
    fun allDogAssetNames_matchResourceConvention() {
        val pattern = Regex("^dog_[a-z]+_[a-z]+$")
        DogBreed.entries.forEach { breed ->
            CatState.entries.forEach { state ->
                val name = breed.assetName(state)
                assertTrue("invalid resource name: $name", pattern.matches(name))
            }
        }
        // 5 dogs × 7 states = 35(+ happy2/happy3/shaker は別名で計 50 枚)。
        assertEquals(35, DogBreed.entries.size * CatState.entries.size)
    }

    @Test
    fun lock_blocksOtherPet_forFreeUser() {
        val current = PetBreed.Cat(CatBreed.Orange)
        // 非プレミアム・未解放: 別キャラはロック、同一はロックされない。
        assertTrue(PetBreedAccess.isLocked(PetBreed.Dog(DogBreed.Shiba), current, isPremium = false, referralUnlocked = false))
        assertTrue(!PetBreedAccess.isLocked(current, current, isPremium = false, referralUnlocked = false))
        // プレミアム or 紹介解放で全解放。
        assertTrue(!PetBreedAccess.isLocked(PetBreed.Dog(DogBreed.Shiba), current, isPremium = true, referralUnlocked = false))
        assertTrue(!PetBreedAccess.isLocked(PetBreed.Dog(DogBreed.Shiba), current, isPremium = false, referralUnlocked = true))
    }
}
