package com.goexercise.app.data.friends

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * MockFriendsService の連携シミュレーション(#5)の検証。実通信なしで連携 VM/UI フローを
 * 通せること、エラー写像(衝突/キャンセル)が正しいことを機械検証する。
 */
class MockFriendsServiceLinkingTest {

    private fun signedIn() = MockFriendsService().apply { runBlocking { signIn("テスト", "t") } }

    @Test
    fun linkGoogle_marksBackedUp() = runBlocking {
        val s = signedIn()
        assertFalse(s.backupStatus.isBackedUp)
        s.linkGoogleIdToken("good-token")
        assertTrue(s.backupStatus.isBackedUp)
        assertEquals("google", s.backupStatus.providerName)
    }

    @Test
    fun linkGoogle_collisionThrows() = runBlocking {
        val s = signedIn()
        try {
            s.linkGoogleIdToken("collide-token")
            fail("collision を期待")
        } catch (e: AccountLinkError.AlreadyLinkedToAnotherAccount) {
            // ok
        }
    }

    @Test
    fun appleWeb_accessDenied_mapsCancelled() = runBlocking {
        val s = signedIn()
        try {
            s.linkAppleWeb { "goexercise://auth-callback?error=access_denied" }
            fail("cancelled を期待")
        } catch (e: AccountLinkError.Cancelled) {
            // ok
        }
    }

    @Test
    fun appleWeb_identityExists_mapsCollision() = runBlocking {
        val s = signedIn()
        try {
            s.linkAppleWeb { "goexercise://auth-callback?error_code=identity_already_exists" }
            fail("collision を期待")
        } catch (e: AccountLinkError.AlreadyLinkedToAnotherAccount) {
            // ok
        }
    }

    @Test
    fun appleWeb_success_marksBackedUp() = runBlocking {
        val s = signedIn()
        s.linkAppleWeb { "goexercise://auth-callback?code=ok" }
        assertTrue(s.backupStatus.isBackedUp)
        assertEquals("apple", s.backupStatus.providerName)
    }

    @Test
    fun restoreGoogle_restoredSeedsFriends() = runBlocking {
        val s = MockFriendsService()
        val outcome = s.restoreWithGoogleIdToken("existing-token")
        assertEquals(RestoreOutcome.Restored, outcome)
        assertTrue(s.backupStatus.isBackedUp)
        assertTrue(s.refreshFriends().isNotEmpty())
    }

    @Test
    fun restoreGoogle_newCreatesWithoutFriends() = runBlocking {
        val s = MockFriendsService()
        val outcome = s.restoreWithGoogleIdToken("new-token")
        assertEquals(RestoreOutcome.Created, outcome)
        assertTrue(s.refreshFriends().isEmpty())
    }

    @Test
    fun deleteAccount_clearsEverything() = runBlocking {
        val s = signedIn()
        s.linkGoogleIdToken("g")
        s.deleteAccount()
        assertNull(s.myProfile())
        assertFalse(s.backupStatus.isBackedUp)
        assertTrue(s.refreshFriends().isEmpty())
    }

    @Test
    fun anonymousSessionHasData_trueOnlyWhileAnonymousWithFriends() = runBlocking {
        val s = signedIn() // signIn が demo friends をシードする
        assertTrue(s.anonymousSessionHasData())
        s.linkGoogleIdToken("g") // backed up になれば上書き確認は不要
        assertFalse(s.anonymousSessionHasData())
    }
}
