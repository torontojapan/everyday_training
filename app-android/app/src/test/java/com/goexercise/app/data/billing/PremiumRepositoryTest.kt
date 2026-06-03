package com.goexercise.app.data.billing

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * MockPremiumRepository + ProductIds の検証(#6)。Activity を要する purchase() の実フローは
 * emulator スクショで確認(Mock 購入→isPremium→rescue 月4)。ここでは Activity 非依存の挙動を検証。
 */
class PremiumRepositoryTest {

    @Test
    fun productIds_fallbackPrices() {
        assertEquals("¥500", ProductIds.fallbackPrice(ProductIds.PREMIUM_MONTHLY))
        assertEquals("¥3,800", ProductIds.fallbackPrice(ProductIds.PREMIUM_YEARLY))
        assertEquals("-", ProductIds.fallbackPrice("unknown.product"))
        assertEquals(listOf(ProductIds.PREMIUM_MONTHLY, ProductIds.PREMIUM_YEARLY), ProductIds.all)
    }

    @Test
    fun mock_startsNonPremium() {
        val repo = MockPremiumRepository()
        assertTrue(repo.isMock)
        assertFalse(repo.isPremiumActive.value)
        assertNull(repo.lastError.value)
    }

    @Test
    fun mock_initialPremiumOverride() {
        assertTrue(MockPremiumRepository(initialPremium = true).isPremiumActive.value)
    }

    @Test
    fun mock_displayPriceUsesFallback() {
        val repo = MockPremiumRepository()
        assertEquals("¥500", repo.displayPrice(ProductIds.PREMIUM_MONTHLY))
        assertEquals("¥3,800", repo.displayPrice(ProductIds.PREMIUM_YEARLY))
    }

    @Test
    fun mock_restoreAndRefreshAreSafeNoops() = runBlocking {
        val repo = MockPremiumRepository()
        repo.refresh()
        repo.restore()
        assertFalse(repo.isPremiumActive.value) // 購入していないので未加入のまま
    }

    @Test
    fun mock_clearError() {
        val repo = MockPremiumRepository()
        repo.clearError()
        assertNull(repo.lastError.value)
    }
}
