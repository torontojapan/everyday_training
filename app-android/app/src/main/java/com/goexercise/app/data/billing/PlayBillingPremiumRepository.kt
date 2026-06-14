package com.goexercise.app.data.billing

import android.app.Activity
import android.content.Context
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.resume

/**
 * Google Play Billing(v8)実装。iOS `StoreKitManager` 相当(商品ロード・購入・entitlement 監視)。
 * **コンパイル = Billing v8 API 実在確認**(queryProductDetails/queryPurchasesAsync/acknowledgePurchase の
 * ktx suspend + launchBillingFlow)。**実 Play での購入/エンタイトルメント E2E は #10**(Play Console に
 * サブスク商品 + base plan の 14日 free-trial offer を作成し内部テスト配信)。
 *
 * client-only entitlement(plan §7): Play Store が唯一の正本。`queryPurchasesAsync` で active な
 * subscription を再評価し、未 ack の購入は acknowledge する(3日以内に ack しないと払い戻される)。
 */
class PlayBillingPremiumRepository(context: Context) : PremiumRepository {

    override val isMock: Boolean = false

    private val _isPremiumActive = MutableStateFlow(false)
    override val isPremiumActive: StateFlow<Boolean> = _isPremiumActive.asStateFlow()

    // 既定 false(商品ロード前は不明=控えめ)。loadProducts で無料トライアル offer の有無により確定。
    private val _isTrialEligible = MutableStateFlow(false)
    override val isTrialEligible: StateFlow<Boolean> = _isTrialEligible.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    override val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val productDetailsCache = mutableMapOf<String, ProductDetails>()

    // 購入完了(即時/Ask to Buy 承認/再配信)で entitlement を再評価する。
    private val purchasesListener = PurchasesUpdatedListener { result, _ ->
        if (result.responseCode == BillingClient.BillingResponseCode.OK) {
            scope.launch { refreshEntitlements() }
        }
    }

    private val client: BillingClient = BillingClient.newBuilder(context)
        .setListener(purchasesListener)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    private val connectMutex = Mutex()

    init {
        // 起動時にエンタイトルメントを取得(購読済ユーザーが paywall を開かなくても premium を反映。
        // rescue 等の gate が cold-start 直後から正しい付与枠で動く)。失敗は無視(次の操作で再試行)。
        scope.launch { runCatching { refresh() } }
    }

    /** 接続を直列化(複数の呼び出しが同一 BillingClient を二重 startConnection しないように)。 */
    private suspend fun ensureConnected(): Boolean = connectMutex.withLock {
        if (client.isReady) return@withLock true
        suspendCancellableCoroutine { cont ->
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(result: BillingResult) {
                    if (cont.isActive) cont.resume(result.responseCode == BillingClient.BillingResponseCode.OK)
                }
                override fun onBillingServiceDisconnected() {
                    if (cont.isActive) cont.resume(false)
                }
            })
        }
    }

    override suspend fun refresh() {
        if (!ensureConnected()) { _lastError.value = CONNECT_ERROR; return }
        loadProducts()
        refreshEntitlements()
    }

    private suspend fun loadProducts() {
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                ProductIds.all.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                },
            ).build()
        val result = client.queryProductDetails(params)
        result.productDetailsList?.forEach { productDetailsCache[it.productId] = it }
        // 無料トライアル offer が1商品でも返れば適格(Play は消化済みユーザーには trial offer を返さない)。
        _isTrialEligible.value = ProductIds.all.any { id ->
            productDetailsCache[id]?.let { trialOffer(it) != null } == true
        }
    }

    private suspend fun refreshEntitlements() {
        val result = client.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build(),
        )
        // 取得失敗(ネット断/サービスエラー)時は既存の entitlement を維持する。空リストで上書きすると
        // 購読中ユーザーを誤ってダウングレードしてしまうため(rescue 付与枠も誤って月1 に戻る)。
        if (result.billingResult.responseCode != BillingClient.BillingResponseCode.OK) return
        val purchases = result.purchasesList
        // 未 ack の有効購入を acknowledge(払い戻し回避)。
        purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED && !it.isAcknowledged }
            .forEach { acknowledge(it.purchaseToken) }
        _isPremiumActive.value = purchases.any { p ->
            p.purchaseState == Purchase.PurchaseState.PURCHASED && p.products.any { it in ProductIds.all }
        }
    }

    private suspend fun acknowledge(token: String) {
        runCatching {
            client.acknowledgePurchase(AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build())
        }
    }

    override suspend fun purchase(activity: Activity, productId: String): Boolean {
        if (!ensureConnected()) { _lastError.value = CONNECT_ERROR; return false }
        val details = productDetailsCache[productId] ?: run { loadProducts(); productDetailsCache[productId] }
        if (details == null) { _lastError.value = "商品が見つかりません"; return false }
        val offerToken = trialOffer(details)?.offerToken
        if (offerToken == null) { _lastError.value = "プランが見つかりません"; return false }
        val flowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(details)
                        .setOfferToken(offerToken)
                        .build(),
                ),
            ).build()
        // 起動の成否を返す。エンタイトルメント確定は purchasesListener → refreshEntitlements。
        val result = client.launchBillingFlow(activity, flowParams)
        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            _lastError.value = "購入を開始できませんでした"
            return false
        }
        _lastError.value = null
        return true
    }

    override suspend fun restore() {
        if (!ensureConnected()) { _lastError.value = CONNECT_ERROR; return }
        refreshEntitlements()
    }

    override fun displayPrice(productId: String): String {
        val details = productDetailsCache[productId] ?: return ProductIds.fallbackPrice(productId)
        // 購入と同じ offer の最終フェーズ(= 無料体験後の通常価格)を表示し、CTA/開示と一致させる。
        val phase = trialOffer(details)?.pricingPhases?.pricingPhaseList?.lastOrNull()
        return phase?.formattedPrice ?: ProductIds.fallbackPrice(productId)
    }

    /**
     * 購入に使う offer を選ぶ。**無料トライアル(priceAmountMicros==0 のフェーズ)を含む offer を優先**し、
     * 無ければ先頭。
     *
     * eligibility について: Play は **queryProductDetails の時点で、そのユーザーが適格な offer だけを返す**
     * (トライアル消化済みなら無料トライアル offer は含まれない)。したがって「返ってきた offer の中から
     * 無料フェーズ付きを選ぶ」=適格ユーザーにのみ無料トライアルで購入を開始する、で eligibility は満たされる
     * (StoreKit の isEligibleForIntroOffer 相当を Play はサーバ側フィルタで担保。paywall 文言の出し分けも
     * 同じ trialOffer 有無=[isTrialEligible] に基づく)。base-plan/offer タグでの厳密選択は将来の精緻化余地。
     */
    private fun trialOffer(details: ProductDetails): ProductDetails.SubscriptionOfferDetails? {
        val offers = details.subscriptionOfferDetails ?: return null
        return offers.firstOrNull { o -> o.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L } }
            ?: offers.firstOrNull()
    }

    override fun clearError() { _lastError.value = null }

    private companion object {
        const val CONNECT_ERROR = "ストアに接続できませんでした"
    }
}
