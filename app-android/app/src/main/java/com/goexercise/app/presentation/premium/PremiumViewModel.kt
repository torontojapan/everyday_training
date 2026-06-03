package com.goexercise.app.presentation.premium

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.goexercise.app.analytics.Analytics
import com.goexercise.app.analytics.AnalyticsEvent
import com.goexercise.app.data.billing.PremiumRepository
import com.goexercise.app.data.billing.ProductIds
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

/**
 * GOプレミアム ペイウォールの VM。iOS `PremiumPaywallSheet` の StoreKitManager 駆動部分に対応。
 * [PremiumRepository] を購読し、購入/復元を仲介する。エンタイトルメント確定は
 * `isPremiumActive` の遷移で観測する(Mock は購入で即 true、Play は購入完了リスナで true)。
 */
@HiltViewModel
class PremiumViewModel @Inject constructor(
    private val premium: PremiumRepository,
) : ViewModel() {

    val isPremiumActive: StateFlow<Boolean> = premium.isPremiumActive
    val lastError: StateFlow<String?> = premium.lastError

    private val _isWorking = MutableStateFlow(false)
    val isWorking: StateFlow<Boolean> = _isWorking.asStateFlow()

    private val _prices = MutableStateFlow(ProductIds.all.associateWith { ProductIds.fallbackPrice(it) })
    /** productId → 表示価格。商品ロード後に実価格へ更新(未取得は fallback)。 */
    val prices: StateFlow<Map<String, String>> = _prices.asStateFlow()

    /** 進行中の購入対象 productId。エンタイトルメント確定(false→true)時に completed 計測へ使う。 */
    private var pendingPurchase: String? = null

    init {
        // ペイウォール表示を計測(主商品=月額。iOS view_paywall に対応)。
        Analytics.track(AnalyticsEvent.PaywallViewed(ProductIds.all.firstOrNull() ?: ""))
        viewModelScope.launch {
            premium.refresh()
            _prices.value = ProductIds.all.associateWith { premium.displayPrice(it) }
        }
        // 購入完了は isPremiumActive の false→true 遷移で観測(Mock=即時 / Play=リスナ非同期)。
        // 復元では pendingPurchase=null なので purchase_complete は誤発火しない。
        viewModelScope.launch {
            var was = premium.isPremiumActive.value
            premium.isPremiumActive.collect { active ->
                if (active && !was) {
                    pendingPurchase?.let { Analytics.track(AnalyticsEvent.PurchaseCompleted(it)) }
                    pendingPurchase = null
                }
                was = active
            }
        }
    }

    fun purchase(activity: Activity, productId: String) {
        if (_isWorking.value) return
        _isWorking.value = true
        pendingPurchase = productId
        Analytics.track(AnalyticsEvent.PurchaseStarted(productId))
        viewModelScope.launch {
            try { premium.purchase(activity, productId) } finally { _isWorking.value = false }
        }
    }

    fun restore() {
        if (_isWorking.value) return
        _isWorking.value = true
        // 復元での isPremiumActive false→true を購入完了と誤計測しないよう、進行中の購入対象をクリア。
        pendingPurchase = null
        viewModelScope.launch {
            try { premium.restore() } finally { _isWorking.value = false }
        }
    }

    fun clearError() = premium.clearError()
}
