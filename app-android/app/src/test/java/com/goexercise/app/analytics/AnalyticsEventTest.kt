package com.goexercise.app.analytics

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * signal 名は iOS `Analytics.swift` と完全一致させる(同一 TelemetryDeck プロジェクトで集計するため、
 * 名前がズレるとプラットフォーム間でファネルが分断される)。ここで固定して回帰を防ぐ。
 */
class AnalyticsEventTest {

    @Test
    fun `signal names match iOS`() {
        assertEquals("app_open", AnalyticsEvent.AppOpen.name)
        assertEquals("onboarding_complete", AnalyticsEvent.OnboardingCompleted.name)
        assertEquals("record_created", AnalyticsEvent.RecordCreated("strength").name)
        assertEquals("view_paywall", AnalyticsEvent.PaywallViewed("monthly").name)
        assertEquals("start_purchase", AnalyticsEvent.PurchaseStarted("monthly").name)
        assertEquals("purchase_complete", AnalyticsEvent.PurchaseCompleted("monthly").name)
        assertEquals("data_exported", AnalyticsEvent.DataExported.name)
        assertEquals("data_deleted", AnalyticsEvent.DataDeleted.name)
    }

    @Test
    fun `parameters carry only non-PII context`() {
        assertEquals(mapOf("category" to "strength"), AnalyticsEvent.RecordCreated("strength").parameters)
        assertEquals(mapOf("product" to "monthly"), AnalyticsEvent.PaywallViewed("monthly").parameters)
        assertEquals(mapOf("product" to "monthly"), AnalyticsEvent.PurchaseStarted("monthly").parameters)
        assertEquals(mapOf("product" to "monthly"), AnalyticsEvent.PurchaseCompleted("monthly").parameters)
        assertEquals(emptyMap<String, String>(), AnalyticsEvent.AppOpen.parameters)
        assertEquals(emptyMap<String, String>(), AnalyticsEvent.DataExported.parameters)
    }

    @Test
    fun `default facade does not send`() {
        // 既定は Noop(App ID 未設定/DEBUG)。track は例外なく no-op で返る。
        Analytics.service = NoopAnalytics
        Analytics.track(AnalyticsEvent.AppOpen)
        Analytics.track(AnalyticsEvent.RecordCreated("cardio"))
    }
}
