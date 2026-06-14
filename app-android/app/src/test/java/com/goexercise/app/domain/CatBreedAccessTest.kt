package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 猫種ロック判定(課金/紹介ゲート)。iOS CatBreedAccess パリティ。 */
class CatBreedAccessTest {

    private val current = CatBreed.Default
    private val other = CatBreed.entries.first { it != current }

    @Test
    fun premium_unlocks_all() {
        assertFalse(CatBreedAccess.isLocked(other, current, isPremium = true, referralUnlocked = false))
    }

    @Test
    fun referralUnlock_unlocks_all() {
        assertFalse(CatBreedAccess.isLocked(other, current, isPremium = false, referralUnlocked = true))
    }

    @Test
    fun free_user_locked_for_breeds_other_than_current() {
        assertTrue(CatBreedAccess.isLocked(other, current, isPremium = false, referralUnlocked = false))
    }

    @Test
    fun current_breed_is_never_locked() {
        // 解約後も「今の猫」は維持できる(変更だけ不可)。
        assertFalse(CatBreedAccess.isLocked(current, current, isPremium = false, referralUnlocked = false))
    }

    @Test
    fun referralUnlocked_threshold_is_10() {
        assertEquals(10, CatBreedAccess.BREED_UNLOCK_STARS)
        assertFalse(CatBreedAccess.referralUnlocked(9))
        assertTrue(CatBreedAccess.referralUnlocked(10))
        assertTrue(CatBreedAccess.referralUnlocked(11))
    }
}
