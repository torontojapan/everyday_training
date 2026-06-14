package com.goexercise.app.data.friends

import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * anti-resurrection の手順・fail-closed 判断([AccountDeletionFlow])を fake ラムダ + 呼び出し記録で検証。
 * ネットワーク副作用(Supabase)を注入で分離しているため、実クライアント無しで全分岐を機械担保できる。
 */
class AccountDeletionFlowTest {

    // ---- signOut ----

    @Test
    fun signOut_anonymous_deletesOwnedDataThenSignsOut() = runTest {
        val calls = mutableListOf<String>()
        AccountDeletionFlow.signOut(
            user = AccountDeletionFlow.SessionUser(isAnonymous = true),
            deleteOwnedData = { calls += "delete" },
            signOut = { calls += "signOut" },
        )
        // 匿名は「忘れる」= 本人データ削除 → 必ず削除が signOut より前。
        assertEquals(listOf("delete", "signOut"), calls)
    }

    @Test
    fun signOut_anonymous_deleteFailure_isBestEffort_stillSignsOut() = runTest {
        var signedOut = false
        AccountDeletionFlow.signOut(
            user = AccountDeletionFlow.SessionUser(isAnonymous = true),
            deleteOwnedData = { throw RuntimeException("network down") }, // 削除失敗
            signOut = { signedOut = true },
        )
        // best-effort: 削除が失敗しても auth signOut までは必ず到達する。
        assertTrue(signedOut)
    }

    @Test
    fun signOut_linked_doesNotDeleteOwnedData() = runTest {
        var deleted = false
        var signedOut = false
        AccountDeletionFlow.signOut(
            user = AccountDeletionFlow.SessionUser(isAnonymous = false),
            deleteOwnedData = { deleted = true },
            signOut = { signedOut = true },
        )
        // 連携済み=バックアップ保持(別端末で復旧可)。削除はしない・signOut のみ。
        assertFalse(deleted)
        assertTrue(signedOut)
    }

    @Test
    fun signOut_noSession_doesNotDeleteOwnedData() = runTest {
        var deleted = false
        var signedOut = false
        AccountDeletionFlow.signOut(
            user = null, // 未サインイン
            deleteOwnedData = { deleted = true },
            signOut = { signedOut = true },
        )
        assertFalse(deleted)
        assertTrue(signedOut)
    }

    // ---- deleteAccount ----

    @Test
    fun deleteAccount_success_onlySignsOutLocal_noClientDelete() = runTest {
        val calls = mutableListOf<String>()
        AccountDeletionFlow.deleteAccount(
            invokeEdgeFunction = { calls += "ef"; 200 },
            signOutLocal = { calls += "signOutLocal" },
            deleteOwnedData = { calls += "delete" },
            signOutGlobal = { calls += "signOutGlobal" },
            failClosed = { IllegalStateException("should not fail-close") },
        )
        // 2xx: EF が auth cascade 削除済 → ローカル signOut のみ。クライアント削除も global signOut もしない。
        assertEquals(listOf("ef", "signOutLocal"), calls)
    }

    @Test
    fun deleteAccount_fallback_404_deletesThenSignsOutGlobal() = runTest {
        val calls = mutableListOf<String>()
        AccountDeletionFlow.deleteAccount(
            invokeEdgeFunction = { 404 }, // EF 未デプロイ
            signOutLocal = { calls += "signOutLocal" },
            deleteOwnedData = { calls += "delete" },
            signOutGlobal = { calls += "signOutGlobal" },
            failClosed = { IllegalStateException("should not fail-close") },
        )
        // Fallback: クライアント RLS 削除 → global signOut。local signOut は呼ばない。
        assertEquals(listOf("delete", "signOutGlobal"), calls)
    }

    @Test
    fun deleteAccount_fallback_networkDown_minusOne_alsoFallsBack() = runTest {
        val calls = mutableListOf<String>()
        AccountDeletionFlow.deleteAccount(
            invokeEdgeFunction = { -1 }, // ネット断/不確定
            signOutLocal = { calls += "signOutLocal" },
            deleteOwnedData = { calls += "delete" },
            signOutGlobal = { calls += "signOutGlobal" },
            failClosed = { IllegalStateException("should not fail-close") },
        )
        assertEquals(listOf("delete", "signOutGlobal"), calls)
    }

    @Test
    fun deleteAccount_fallback_deleteFailure_propagates_doesNotSignOutGlobal() = runTest {
        var signedOutGlobal = false
        val thrown = runCatching {
            AccountDeletionFlow.deleteAccount(
                invokeEdgeFunction = { 404 },
                signOutLocal = { },
                deleteOwnedData = { throw RuntimeException("RLS delete failed") }, // 削除失敗
                signOutGlobal = { signedOutGlobal = true },
                failClosed = { IllegalStateException("should not fail-close") },
            )
        }
        // 削除失敗は **伝播**(global signOut へ進まない)→ 再試行 = 復活防止。
        assertTrue(thrown.isFailure)
        assertFalse(signedOutGlobal)
    }

    @Test
    fun deleteAccount_failClosed_500_throws_andDoesNothing() = runTest {
        var anyAction = false
        val sentinel = IllegalStateException("fail-closed")
        val thrown = runCatching {
            AccountDeletionFlow.deleteAccount(
                invokeEdgeFunction = { 500 }, // EF 到達後の失敗
                signOutLocal = { anyAction = true },
                deleteOwnedData = { anyAction = true },
                signOutGlobal = { anyAction = true },
                failClosed = { sentinel },
            )
        }
        // FailClosed: success 誤報告を避け failClosed を投げる。削除もサインアウトもしない。
        assertTrue(thrown.isFailure)
        assertEquals(sentinel, thrown.exceptionOrNull())
        assertFalse(anyAction)
    }

    @Test
    fun deleteAccount_failClosed_401_throws() = runTest {
        val sentinel = IllegalStateException("fail-closed")
        val thrown = runCatching {
            AccountDeletionFlow.deleteAccount(
                invokeEdgeFunction = { 401 },
                signOutLocal = { },
                deleteOwnedData = { },
                signOutGlobal = { },
                failClosed = { sentinel },
            )
        }
        assertEquals(sentinel, thrown.exceptionOrNull())
    }

    @Test
    fun deleteAccount_invokeThrows_propagates_andDoesNothing() = runTest {
        var anyAction = false
        val boom = RuntimeException("EF reached but failed (callers map to fail-closed)")
        val thrown = runCatching {
            AccountDeletionFlow.deleteAccount(
                invokeEdgeFunction = { throw boom }, // EF 呼び出し自体が例外
                signOutLocal = { anyAction = true },
                deleteOwnedData = { anyAction = true },
                signOutGlobal = { anyAction = true },
                failClosed = { IllegalStateException("unused") },
            )
        }
        // invokeEdgeFunction の例外はそのまま伝播 → success 誤報告防止。後続アクションは一切なし。
        assertTrue(thrown.isFailure)
        assertEquals(boom, thrown.exceptionOrNull())
        assertFalse(anyAction)
    }
}
