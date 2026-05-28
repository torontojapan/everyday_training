import Foundation
import StoreKit

/// 商品 ID 定数 (App Store Connect / Products.storekit と一致させる)。
enum ProductID {
    static let rescueTicket1 = "com.serial.cerealexercise.rescue_ticket_1"
    static let weightProMonthly = "com.serial.cerealexercise.weight_pro_monthly"
    static let all: [String] = [rescueTicket1, weightProMonthly]
}

/// StoreKit 2 の薄い wrapper。商品ロード・購入・entitlement 監視を集約する。
@MainActor
@Observable
final class StoreKitManager {
    /// 永続化用 UserDefaults keys。
    /// - `pendingQueueKey`: hook 未設定時に保留した consumable productID 配列。
    ///   in-memory のみだとアプリ強制終了で消えて user 課金損失になる (Codex 致命的指摘)。
    /// - `processedConsumableIDsKey`: consumable transaction ID dedup 用。
    ///   購入確定後の immediate fulfill と listener fulfill の二重実行を防ぐ。
    static let pendingQueueKey = "storekit.pendingConsumables.v2"
    static let processedConsumableIDsKey = "storekit.processedConsumableIDs.v1"

    /// 取得済の Product (商品 ID をキーに保持)。
    private(set) var products: [String: Product] = [:]
    /// 体重 Pro subscription が現在有効か (entitlement listener が更新)。
    private(set) var isWeightProActive: Bool = false
    /// 直近の購入エラー (UI で軽く出す用)。
    var lastError: String?

    /// `purchase_complete` 計測の in-memory dedup。同一トランザクションの再配信で
    /// 二重計測しないため。session 内で十分 (finish 済 txn は再起動毎には再配信されない)。
    @ObservationIgnored private var analyticsTrackedPurchaseIDs: Set<UInt64> = []

    /// 購入成功時のフック (consumable に対応するため)。
    /// hook が設定される前に届いた transaction は UserDefaults 永続キューに積まれ、
    /// hook 設定時に flush される。永続化により app 強制終了でも grant が残る。
    var onConsumablePurchased: ((String) -> Void)? {
        didSet {
            if onConsumablePurchased != nil { flushPendingConsumables() }
        }
    }

    private let defaults: UserDefaults
    /// Transaction.updates listener の Task ハンドル。同一インスタンスでの
    /// 重複起動を防ぎ、deinit で確実に cancel するため保持する。
    /// `@ObservationIgnored nonisolated(unsafe)`: @Observable のトラッキング対象外に
    /// した上で、MainActor 隔離 deinit から cancel できるようにする。代入は
    /// init/startTransactionListener (MainActor) のみ、deinit 読み取りは最終 1 回
    /// なので実質レースしない (Codex 指摘: orphan listener の leak 防止)。
    @ObservationIgnored private nonisolated(unsafe) var transactionListenerTask: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    /// 取れるので必ず呼ぶ。これによりオフライン購読ユーザーの誤ロックを回避
    /// (Codex 指摘: 旧コードは catch path で refreshEntitlements を skip していた)。
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            lastError = nil
        } catch {
            lastError = "商品情報の取得に失敗しました: \(error.localizedDescription)"
        }
        // 成否によらず entitlement は再評価する
        await refreshEntitlements()
    }

    /// 現在の entitlements を読み直して subscription 状態を再計算する。
    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let txn) = result else { continue }
            if txn.productID == ProductID.weightProMonthly,
               txn.revocationDate == nil {
                if let expires = txn.expirationDate, expires < Date() { continue }
                active = true
                break  // 最初に見つかった有効 entitlement で確定 (Codex 指摘)
            }
        }
        isWeightProActive = active
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
        // sync 成否によらず entitlement を再評価
        await refreshEntitlements()
    }

    // MARK: - Transaction handling

    private func handle(transactionUpdate: VerificationResult<Transaction>) async {
        guard case .verified(let txn) = transactionUpdate else { return }
        await handleVerified(txn: txn)
    }

    private func handleVerified(txn: Transaction) async {
        switch txn.productType {
        case .consumable:
            // dedup は consumable のみに限定 (Codex 指摘: 旧コードは productType 分岐前で
            // dedup していたため subscription の update transaction まで dropped されていた)。
            // また dedup ID は永続化することで「fulfill 済だが finish 失敗で listener が
            // 再送する」ケースで二重 grant を防ぐ。
            let alreadyProcessed = processedConsumableIDs.contains(txn.id)
            if !alreadyProcessed {
                if let hook = onConsumablePurchased {
                    hook(txn.productID)
                } else {
                    // hook 未設定 → 永続キューに積む。app 強制終了でも次回起動時に
                    // flushPendingConsumables() で grant される (Codex 致命的指摘修正)。
                    enqueuePendingConsumable(txn.productID)
                }
                markConsumableProcessed(txn.id)
            }
            trackPurchaseCompleteOnce(txn)
            await txn.finish()
        case .autoRenewable:
            // subscription は dedup しない (Apple は同じ txn を update イベントで再送するが、
            // それらは「最新の expirationDate」を運ぶので毎回 refreshEntitlements が必要)。
            await txn.finish()
            await refreshEntitlements()
            trackPurchaseCompleteOnce(txn)
        default:
            await txn.finish()
        }
    }

    /// 検証済みトランザクションを 1 回だけ `purchase_complete` として計測する。
    /// `handleVerified` は即時購入・遅延承認 (Ask to Buy)・listener 再送のすべてを
    /// 通るため、ここで計測すれば保留購入の完了も取りこぼさない (Codex 指摘)。
    /// - 更新 (renewal) は `id != originalID` で除外し、購入ファネルを汚さない。
    /// - 同一トランザクションの再配信は in-memory dedup で二重計測を防ぐ。
    private func trackPurchaseCompleteOnce(_ txn: Transaction) {
        guard txn.id == txn.originalID else { return }
        guard !analyticsTrackedPurchaseIDs.contains(txn.id) else { return }
        analyticsTrackedPurchaseIDs.insert(txn.id)
        Analytics.track(.purchaseCompleted(product: txn.productID))
    }

    // MARK: - Persistent consumable queue

    private var pendingConsumableQueue: [String] {
        defaults.stringArray(forKey: Self.pendingQueueKey) ?? []
    }

    private func enqueuePendingConsumable(_ productID: String) {
        var q = pendingConsumableQueue
        q.append(productID)
        defaults.set(q, forKey: Self.pendingQueueKey)
    }

    private func flushPendingConsumables() {
        guard let hook = onConsumablePurchased else { return }
        // grant → 永続キューから除去 の順で 1 件ずつ処理する (Codex 致命的指摘修正)。
        // 旧コードは「全削除 → grant ループ」だったため、flush 途中で app が
        // 終了すると未 grant 分が永久に失われていた (課金損失)。
        // この順なら、最悪ケースは「grant 済だが除去前に終了」= 再起動で再 grant
        // (= user 有利な over-grant、稀)。under-grant (課金損失) は起きない。
        var q = pendingConsumableQueue
        while let first = q.first {
            hook(first)
            q.removeFirst()
            defaults.set(q, forKey: Self.pendingQueueKey)
        }
    }

    // MARK: - Processed consumable IDs (persisted dedup)

    private var processedConsumableIDs: Set<UInt64> {
        let raw = (defaults.array(forKey: Self.processedConsumableIDsKey) as? [NSNumber]) ?? []
        return Set(raw.map { $0.uint64Value })
    }

    private func markConsumableProcessed(_ id: UInt64) {
        var s = processedConsumableIDs
        s.insert(id)
        // 上限を設けて UserDefaults を肥大化させない (古い ID から消す)。
        let pruned = s.count > 1000 ? Set(s.sorted(by: >).prefix(800)) : s
        defaults.set(pruned.map { NSNumber(value: $0) }, forKey: Self.processedConsumableIDsKey)
    }

    // MARK: - Convenience accessors

    var rescueTicketProduct: Product? { products[ProductID.rescueTicket1] }
    var weightProProduct: Product? { products[ProductID.weightProMonthly] }

    /// 表示用ローカライズ価格 (例: "¥500" / "¥1,000")。fallback あり。
    func displayPrice(for productID: String) -> String {
        if let p = products[productID] { return p.displayPrice }
        switch productID {
        case ProductID.rescueTicket1:    return "¥1,000"
        case ProductID.weightProMonthly: return "¥500"
        default: return "-"
        }
    }
}
