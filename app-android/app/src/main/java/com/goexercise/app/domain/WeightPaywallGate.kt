package com.goexercise.app.domain

/**
 * 体重タブ paywall の自動提示判定(純関数)。iOS `WeightTabRootView` の updateGate/isInCooldown 相当。
 * 未加入かつ「閉じてから 6 時間」を過ぎていれば自動提示する。テスト可能なように VM から切り出す。
 */
object WeightPaywallGate {
    const val COOLDOWN_MS = 6L * 60 * 60 * 1000

    /**
     * @param isPremium   加入済みなら常に false(ロックされないので paywall 不要)。
     * @param nowMs       現在時刻(注入 Clock の millis)。
     * @param dismissedAtMs 直近に paywall を閉じた時刻(未設定=0)。
     */
    fun shouldAutoPresent(isPremium: Boolean, nowMs: Long, dismissedAtMs: Long): Boolean =
        !isPremium && (nowMs - dismissedAtMs >= COOLDOWN_MS)
}
