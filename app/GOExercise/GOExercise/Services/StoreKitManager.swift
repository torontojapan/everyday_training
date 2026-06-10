import Foundation
import StoreKit

/// 商品 ID 定数 (App Store Connect / Products.storekit と一致させる)。
enum ProductID {
    static let premiumMonthly = "com.goexercise.app.premium_monthly"
    static let premiumYearly = "com.goexercise.app.premium_yearly"
    static let all: [String] = [premiumMonthly, premiumYearly]

    /// GOプレミアムの subscription productID 集合 (entitlement 判定用)。
    static let premiumIDs: Set<String> = [premiumMonthly, premiumYearly]
}

/// StoreKit 2 の薄い wrapper。商品ロード・購入・entitlement 監視を集約する。
@MainActor
@Observable
final class StoreKitManager {
    /// 取得済の Product (商品 ID をキーに保持)。
    private(set) var products: [String: Product] = [:]
    /// GOプレミアム (月額 or 年額) が現在有効か (entitlement listener が更新)。
    private(set) var isPremiumActive: Bool = false
    /// 無料トライアル(イントロオファー)対象か。Apple ID × サブスクグループにつき一度きりのため、
    /// トライアル消化済み/再購読ユーザーには「14日間無料」を出さず即課金になる誤表示を防ぐ
    /// (審査 2.3.1/3.1.2 のミスリーディング価格リスク。監査 P1)。商品ロード後に再評価。
    private(set) var isEligibleForIntroOffer: Bool = false
    /// 直近の購入エラー (UI で軽く出す用)。
    var lastError: String?

    /// `purchase_complete` 計測の in-memory dedup。同一トランザクションの再配信で
    /// 二重計測しないため。session 内で十分 (finish 済 txn は再起動毎には再配信されない)。
    @ObservationIgnored private var analyticsTrackedPurchaseIDs: Set<UInt64> = []

    /// DEBUG 限定のデモ/スクショ用 Premium 強制フラグ (`--mock-premium`)。
    /// Release ビルドでは常に false。
    @ObservationIgnored private let forcePremiumForDemo: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("--mock-premium")
        #else
        return false
        #endif
    }()

    /// Transaction.updates listener の Task ハンドル。同一インスタンスでの
    /// 重複起動を防ぎ、deinit で確実に cancel するため保持する。
    /// `@ObservationIgnored nonisolated(unsafe)`: @Observable のトラッキング対象外に
    /// した上で、MainActor 隔離 deinit から cancel できるようにする。代入は
    /// init/startTransactionListener (MainActor) のみ、deinit 読み取りは最終 1 回
    /// なので実質レースしない (orphan listener の leak 防止)。
    @ObservationIgnored private nonisolated(unsafe) var transactionListenerTask: Task<Void, Never>?

    init() {
        isPremiumActive = forcePremiumForDemo
        startTransactionListener()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    private func startTransactionListener() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(transactionUpdate: update)
            }
        }
    }

    // MARK: - Loading

    /// 商品情報を App Store / StoreKit Config からロードする。
    /// 商品取得が失敗しても entitlement (= 既存購読の有効性) は別 API から
    /// 取れるので必ず呼ぶ。これによりオフライン購読ユーザーの誤ロックを回避。
    func loadProducts() async {
        // entitlement(既存購読の有効性)は商品フェッチ不要のローカル API。先に評価して
        // おくと、コールド起動でネットワークが遅いときも、ホームの allowance / 復活ポップが
        // 「無料枠」で先に確定して有料ユーザーをペイウォールへ送る誤判定を避けられる(監査 P2)。
        await refreshEntitlements()
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            lastError = nil
        } catch {
            lastError = "商品情報の取得に失敗しました: \(error.localizedDescription)"
        }
        // 商品フェッチ後にトライアル対象を確定(商品が要る)。entitlement も最終確認。
        await refreshEntitlements()
        await refreshIntroEligibility()
    }

    /// 無料トライアル対象かを再評価する。プレミアム商品のいずれかに introductoryOffer があり、
    /// かつ Apple ID がそのグループで未消化(`isEligibleForIntroOffer`)なら true。
    /// 商品未ロード時は false(誤って無料表示を出さない安全側)。
    private func refreshIntroEligibility() async {
        for id in ProductID.all {
            guard let sub = products[id]?.subscription, sub.introductoryOffer != nil else { continue }
            if await sub.isEligibleForIntroOffer {
                isEligibleForIntroOffer = true
                return
            }
        }
        isEligibleForIntroOffer = false
    }

    /// 購読状態を一括で取り直す(entitlement + トライアル対象)。前面復帰時に使う。
    /// entitlement だけ更新するとトライアル消化後にプレミアム失効しても
    /// `isEligibleForIntroOffer` が true のまま残り、「14日間無料」を出して即課金させてしまう
    /// (Codex R1)。両者を必ずセットで更新する。
    func refreshPurchaseState() async {
        await refreshEntitlements()
        await refreshIntroEligibility()
    }

    /// 現在の entitlements を読み直して subscription 状態を再計算する。
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            if ProductID.premiumIDs.contains(txn.productID),
               txn.revocationDate == nil {
                if let expires = txn.expirationDate, expires < Date() { continue }
                active = true
                break  // 最初に見つかった有効 entitlement で確定
            }
        }
        isPremiumActive = active || forcePremiumForDemo
    }

    // MARK: - Purchase

    @discardableResult
    func purchase(productID: String) async -> Bool {
        guard let product = products[productID] else {
            await loadProducts()
            guard let retry = products[productID] else {
                lastError = "商品が見つかりません"
                return false
            }
            return await purchase(product: retry)
        }
        return await purchase(product: product)
    }

    private func purchase(product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let txn) = verification else {
                    lastError = "購入の検証に失敗しました"
                    return false
                }
                await handleVerified(txn: txn)
                return true
            case .userCancelled:
                return false
            case .pending:
                // 親 (ファミリー共有) や ask-to-buy。確定は entitlement listener 任せ。
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "購入に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
        } catch {
            lastError = "復元に失敗しました: \(error.localizedDescription)"
        }
        // sync 成否によらず購読状態(entitlement + トライアル対象)を再評価。
        // 復元でトライアル消化済みが判明したのに intro 対象が残ると「14日間無料」誤表示(Codex R2)。
        await refreshPurchaseState()
    }

    // MARK: - Transaction handling

    private func handle(transactionUpdate: VerificationResult<Transaction>) async {
        guard case .verified(let txn) = transactionUpdate else { return }
        await handleVerified(txn: txn)
    }

    private func handleVerified(txn: Transaction) async {
        await txn.finish()
        if txn.productType == .autoRenewable {
            // subscription は update イベントで再送される (最新の expirationDate を
            // 運ぶ) ので毎回 entitlement を再評価する。返金/失効/購入でトライアル対象も
            // 変わるため intro 対象もまとめて取り直す(Codex R2)。
            await refreshPurchaseState()
        }
        trackPurchaseCompleteOnce(txn)
    }

    /// 検証済みトランザクションを 1 回だけ `purchase_complete` として計測する。
    /// `handleVerified` は即時購入・遅延承認 (Ask to Buy)・listener 再送のすべてを
    /// 通るため、ここで計測すれば保留購入の完了も取りこぼさない。
    /// - 更新 (renewal) は `id != originalID` で除外し、購入ファネルを汚さない。
    /// - 同一トランザクションの再配信は in-memory dedup で二重計測を防ぐ。
    private func trackPurchaseCompleteOnce(_ txn: Transaction) {
        guard txn.id == txn.originalID else { return }
        guard !analyticsTrackedPurchaseIDs.contains(txn.id) else { return }
        analyticsTrackedPurchaseIDs.insert(txn.id)
        Analytics.track(.purchaseCompleted(product: txn.productID))
    }

    // MARK: - Convenience accessors

    var premiumMonthlyProduct: Product? { products[ProductID.premiumMonthly] }
    var premiumYearlyProduct: Product? { products[ProductID.premiumYearly] }

    /// 表示用ローカライズ価格 (例: "¥500" / "¥3,800")。fallback あり。
    func displayPrice(for productID: String) -> String {
        if let p = products[productID] { return p.displayPrice }
        switch productID {
        case ProductID.premiumMonthly: return "¥500"
        case ProductID.premiumYearly:  return "¥3,800"
        default: return "-"
        }
    }
}
