package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendCodeValidator
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** Mock(Supabase 未設定フォールバック)の社交フロー。UI/スクショはこの経路。実 Supabase は実機PoC。 */
class MockFriendsServiceTest {

    private fun signedIn(): MockFriendsService = MockFriendsService().apply {
        runBlocking { signIn(displayName = "ジュン", username = "jun") }
    }

    @Test
    fun signInCreatesProfileWithValidCode() = runBlocking {
        val svc = signedIn()
        val me = svc.myProfile()
        assertNotNull(me)
        assertEquals("ジュン", me!!.displayName)
        assertTrue(FriendCodeValidator.isValid(me.friendCode))
    }

    @Test
    fun seedsDemoFriendsAndRequest() = runBlocking {
        val svc = signedIn()
        assertTrue(svc.refreshFriends().isNotEmpty())
        assertTrue(svc.pendingRequests().isNotEmpty())
    }

    @Test
    fun acceptRequestMovesToFriends() = runBlocking {
        val svc = signedIn()
        val before = svc.refreshFriends().size
        val req = svc.pendingRequests().first()
        svc.acceptRequest(req)
        assertEquals(before + 1, svc.refreshFriends().size)
        assertTrue(svc.pendingRequests().none { it.id == req.id })
    }

    @Test
    fun cannotAddSelf() = runBlocking {
        val svc = signedIn()
        val myCode = svc.myProfile()!!.friendCode
        assertThrows(FriendsError.CannotAddSelf::class.java) {
            runBlocking { svc.sendRequest(myCode) }
        }
        Unit
    }

    @Test
    fun removeFriendWorks() = runBlocking {
        val svc = signedIn()
        val f = svc.refreshFriends().first()
        svc.removeFriend(f)
        assertTrue(svc.refreshFriends().none { it.friendCode == f.friendCode })
    }

    @Test
    fun signOutClears() = runBlocking {
        val svc = signedIn()
        svc.signOut()
        assertNull(svc.myProfile())
        assertTrue(svc.refreshFriends().isEmpty())
    }

    @Test
    fun sendCheerIsNoOp() = runBlocking {
        val svc = signedIn()
        // 一言コメント付き / 無し どちらも例外が出ないこと。
        svc.sendCheer(CheerKind.CatPunch, svc.refreshFriends().first().friendCode, "がんばれ！")
        svc.sendCheer(CheerKind.Fight, svc.refreshFriends().first().friendCode)
    }
}
