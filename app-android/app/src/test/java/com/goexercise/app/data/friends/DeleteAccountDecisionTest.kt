package com.goexercise.app.data.friends

import org.junit.Assert.assertEquals
import org.junit.Test

/** アカウント削除 fail-closed 判定の回帰テスト(anti-resurrection 中核)。 */
class DeleteAccountDecisionTest {

    @Test
    fun success_on2xx() {
        assertEquals(DeleteAccountDecision.Success, DeleteAccountDecision.fromStatus(200))
        assertEquals(DeleteAccountDecision.Success, DeleteAccountDecision.fromStatus(204))
        assertEquals(DeleteAccountDecision.Success, DeleteAccountDecision.fromStatus(299))
    }

    @Test
    fun fallback_on404_orNetworkUnknown() {
        assertEquals(DeleteAccountDecision.Fallback, DeleteAccountDecision.fromStatus(404)) // EF 未デプロイ
        assertEquals(DeleteAccountDecision.Fallback, DeleteAccountDecision.fromStatus(-1)) // ネット断/不確定
    }

    @Test
    fun failClosed_onReachedButFailed() {
        // EF に到達した上での失敗は success と誤報告せず例外(復活防止)。
        assertEquals(DeleteAccountDecision.FailClosed, DeleteAccountDecision.fromStatus(401))
        assertEquals(DeleteAccountDecision.FailClosed, DeleteAccountDecision.fromStatus(405))
        assertEquals(DeleteAccountDecision.FailClosed, DeleteAccountDecision.fromStatus(500))
        assertEquals(DeleteAccountDecision.FailClosed, DeleteAccountDecision.fromStatus(403))
    }
}
