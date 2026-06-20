package com.goexercise.app.domain

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** 体重タブ paywall 自動提示判定の境界テスト(iOS WeightTabRootView cooldown パリティ)。 */
class WeightPaywallGateTest {

    private val cd = WeightPaywallGate.COOLDOWN_MS

    @Test fun premiumNeverPresents() {
        // 加入済みは dismissedAt が古かろうと提示しない。
        assertFalse(WeightPaywallGate.shouldAutoPresent(isPremium = true, nowMs = cd * 10, dismissedAtMs = 0))
    }

    @Test fun firstRunAutoPresents() {
        // 未設定(dismissedAt=0)で now が cooldown を超えていれば初回提示。
        assertTrue(WeightPaywallGate.shouldAutoPresent(isPremium = false, nowMs = cd, dismissedAtMs = 0))
    }

    @Test fun withinCooldownSuppressed() {
        val now = 100_000_000L
        // 閉じた直後〜6h 未満は提示しない。
        assertFalse(WeightPaywallGate.shouldAutoPresent(false, now, dismissedAtMs = now))
        assertFalse(WeightPaywallGate.shouldAutoPresent(false, now, dismissedAtMs = now - (cd - 1)))
    }

    @Test fun atAndAfterCooldownPresents() {
        val now = 100_000_000L
        // ちょうど 6h 経過(>=)で再提示。
        assertTrue(WeightPaywallGate.shouldAutoPresent(false, now, dismissedAtMs = now - cd))
        assertTrue(WeightPaywallGate.shouldAutoPresent(false, now, dismissedAtMs = now - (cd + 1)))
    }
}
