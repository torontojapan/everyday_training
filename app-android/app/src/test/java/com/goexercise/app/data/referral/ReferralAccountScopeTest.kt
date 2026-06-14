package com.goexercise.app.data.referral

import org.junit.Assert.assertEquals
import org.junit.Test

class ReferralAccountScopeTest {

    @Test
    fun passesValue_whenSummaryMatchesCurrentAccount() {
        assertEquals(7, ReferralAccountScope.scoped(7, summaryAccountCode = "ABC123", currentAccountCode = "ABC123"))
    }

    @Test
    fun zero_whenSummaryFromDifferentAccount() {
        // 切替後: summary がまだ前アカウント由来 → 新アカウント文脈では 0(口座跨ぎ stale 防止)。
        assertEquals(0, ReferralAccountScope.scoped(7, summaryAccountCode = "OLD999", currentAccountCode = "NEW111"))
    }

    @Test
    fun zero_whenSummaryAccountUnknown() {
        // resetForIdentityChange 直後など summary 未確定の間は通さない。
        assertEquals(0, ReferralAccountScope.scoped(7, summaryAccountCode = null, currentAccountCode = "NEW111"))
    }

    @Test
    fun zero_whenCurrentAccountUnknown() {
        // 現アカウント未確定(サインアウト直後 等)も通さない。
        assertEquals(0, ReferralAccountScope.scoped(7, summaryAccountCode = "ABC123", currentAccountCode = null))
    }

    @Test
    fun zero_whenBothNull() {
        assertEquals(0, ReferralAccountScope.scoped(7, summaryAccountCode = null, currentAccountCode = null))
    }
}
