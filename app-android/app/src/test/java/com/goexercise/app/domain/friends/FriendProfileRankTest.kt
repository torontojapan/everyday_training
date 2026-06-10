package com.goexercise.app.domain.friends

import com.goexercise.app.domain.rank
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * FriendProfile.rank 拡張プロパティ(CatRank.of(currentStreak))の検証。
 */
class FriendProfileRankTest {

    private fun profile(streak: Int) = FriendProfile(
        friendCode = "ABC123",
        username = "tester",
        displayName = "Tester",
        currentStreak = streak,
        totalAchievedDays = streak,
        todayAchieved = false,
    )

    @Test
    fun rankReflectsCurrentStreak() {
        assertEquals(0, profile(0).rank.rank)
        assertEquals(1, profile(7).rank.rank)
        assertEquals(11, profile(500).rank.rank)
    }
}
