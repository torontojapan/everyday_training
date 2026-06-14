package com.goexercise.app.data.billing

import android.app.Activity
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * GOプレミアム商品 ID。iOS `ProductID` と対応(ただし **Play 上の別 productId**。ストア間で課金は
 * 別管理・BE に紐づけない = 各ストア独立。plan §7)。
 */
object ProductIds {
    const val PREMIUM_MONTHLY = "com.goexercise.app.premium_monthly"
    const val PREMIUM_YEARLY = "com.goexercise.app.premium_yearly"
    val all: List<String> = listOf(PREMIUM_MONTHLY, PREMIUM_YEARLY)

    /** 未取得時の表示フォールバック価格(iOS displayPrice の fallback と同額)。 */
    fun fallbackPrice(productId: String): String = when (productId) {
        PREMIUM_MONTHLY -> "¥500"
        PREMIUM_YEARLY -> "¥3,800"
        else -> "-"
    }
}

/**
 * プレミアム エンタイトルメント + 購入の抽象。iOS `StoreKitManager` 相当(`isPremiumActive` を同じ
 * 意味で公開)。実装は [PlayBillingPremiumRepository](実 BillingClient)/ [MockPremiumRepository](dev)。
 *
 * **client-only entitlement の限界**(plan §7): BE に課金を紐づけないため Play Store が唯一の正本、
 * 復旧は同一 Google アカウントのログイン端末内に限る。
 */
interface PremiumRepository {
    val isMock: Boolean
    /** 月額 or 年額が現在有効か。rescue 月4枚 / P1.x の体重・生理を gate する。 */
    val isPremiumActive: StateFlow<Boolean>
    /** 無料トライアル適格状態。Play は無料トライアル offer が返るか(消化済みなら返らない)で判定。
     *  false のとき paywall は「14日間無料」を出さない(誤無料表示=審査リスク回避)。iOS isEligibleForIntroOffer 相当。 */
    val isTrialEligible: StateFlow<Boolean>
    /** 直近の購入/復元エラー(UI で軽く出す)。 */
    val lastError: StateFlow<String?>

    /** 商品情報ロード + エンタイトルメント再評価。画面表示時に呼ぶ。 */
    suspend fun refresh()
    /** 指定プランを購入(Play の購入フローを起動)。成功=true。 */
    suspend fun purchase(activity: Activity, productId: String): Boolean
    /** 購入の復元(Play は自動だが UI 導線として置く)。 */
    suspend fun restore()
    /** ローカライズ表示価格(未取得は fallback)。 */
    fun displayPrice(productId: String): String

    fun clearError()
}

/**
 * Play 未設定(dev/screenshot/テスト)用の Mock。実 Play なしで paywall とエンタイトルメント遷移を
 * 通せる。購入で isPremiumActive=true に遷移する(iOS の `--mock-premium` 相当の能動版)。
 */
class MockPremiumRepository(
    initialPremium: Boolean = false,
    initialTrialEligible: Boolean = true,
) : PremiumRepository {
    override val isMock: Boolean = true

    private val _isPremiumActive = MutableStateFlow(initialPremium)
    override val isPremiumActive: StateFlow<Boolean> = _isPremiumActive.asStateFlow()

    // Mock は既定で適格(dev/screenshot で「14日間無料」を表示)。
    override val isTrialEligible: StateFlow<Boolean> = MutableStateFlow(initialTrialEligible).asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    override val lastError: StateFlow<String?> = _lastError.asStateFlow()

    override suspend fun refresh() { /* Mock: 状態は購入で変わる。商品ロード不要。 */ }

    override suspend fun purchase(activity: Activity, productId: String): Boolean {
        _isPremiumActive.value = true
        _lastError.value = null
        return true
    }

    override suspend fun restore() { /* Mock: 復元するものは無い(no-op)。 */ }

    override fun displayPrice(productId: String): String = ProductIds.fallbackPrice(productId)

    override fun clearError() { _lastError.value = null }
}
