package com.goexercise.app.presentation.premium

import android.app.Activity
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
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

    init {
        viewModelScope.launch {
            premium.refresh()
            _prices.value = ProductIds.all.associateWith { premium.displayPrice(it) }
        }
    }

    fun purchase(activity: Activity, productId: String) {
        if (_isWorking.value) return
        _isWorking.value = true
        viewModelScope.launch {
            try { premium.purchase(activity, productId) } finally { _isWorking.value = false }
        }
    }

    fun restore() {
        if (_isWorking.value) return
        _isWorking.value = true
        viewModelScope.launch {
            try { premium.restore() } finally { _isWorking.value = false }
        }
    }

    fun clearError() = premium.clearError()
}
