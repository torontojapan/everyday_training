package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.FriendCodeValidator
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mock(Supabase 未設定時フォールバック)の挙動。実 Supabase 経路は実機 PoC で別途検証。 */
class MockFriendsServiceTest {

    @Test
    fun uidIsStableAcrossCalls() = runBlocking {
        val svc = MockFriendsService()
        val a = svc.ensureSignedInUid()
        val b = svc.ensureSignedInUid()
        assertEquals(a, b)
        assertTrue(svc.isMock)
    }

    @Test
    fun upsertThenFindRoundTrips() = runBlocking {
        val svc = MockFriendsService()
        assertNull(svc.findProfile("ABC234"))
        svc.upsertProfile(ProfileRow(userId = "u1", friendCode = "ABC234", displayName = "ジュン", currentStreak = 5))
        val found = svc.findProfile("ABC234")
        assertEquals("ジュン", found?.displayName)
        assertEquals(5, found?.currentStreak)
    }

    @Test
    fun generateUniqueCodeIsValid() = runBlocking {
        val svc = MockFriendsService()
        repeat(50) {
            val code = svc.generateUniqueCode()
            assertTrue(FriendCodeValidator.isValid(code))
        }
    }
}
