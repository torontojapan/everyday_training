import SwiftUI

/// GOプレミアムの統合ペイウォール。月額 / 年額を選んで購入する。
///
/// Apple の IAP 審査要件 (App Review Guidelines 3.1.2 / 3.1.1) を満たすため:
/// - 価格 / 期間 / 自動更新の明示
/// - 「購入を復元」を必ず提供
/// - プライバシーポリシー / 利用規約 (EULA) リンク
/// - キャンセル方法 (設定 > Apple ID > サブスクリプション)
struct PremiumPaywallSheet: View {
    /// 呼び出し文脈で見出しを出し分ける。
    enum Context {
        case weight   // 体重タブから
        case freeze   // フリーズ枠から
        case general  // 設定など

        var headline: String {
            switch self {
            case .weight:  return "体重タブの全機能を解放しよう"
            case .freeze:  return "連続記録フリーズを月4回に"
            case .general: return "GOプレミアムで全機能を解放"
            }
        }
    }

    @Bindable var store: StoreKitManager
    let context: Context
    var onPurchaseCompleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = ProductID.premiumYearly
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    benefitList
                    planSelector
                    purchaseButton
                    if let err = store.lastError {
                        Text(err)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    restoreButton
                    disclosureBlock
                    legalLinks
                }
                .padding(20)
            }
            .navigationTitle("GOプレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    }
                    .accessibilityLabel("閉じる")
                }
            }
            .task {
                // 表示時点ではプラン未選択なので、特定 SKU ではなくオファリング
                // ("premium") に紐づける。具体的なプランは purchaseStarted で記録。
                Analytics.track(.paywallViewed(product: "premium"))
                await store.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(Palette.primary)
            Text(context.headline)
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("14日間無料。いつでも解約できます。")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("scalemass", "体重の記録 + 推移グラフ (日 / 週 / 月)")
            benefitRow("chart.xyaxis.line", "週次 / 月次レポート + トレンドライン")
            benefitRow("calendar", "周期オーバーレイで体調と体重を重ねて可視化")
            benefitRow("target", "目標 / BMI / 達成リング / 進捗バー")
            benefitRow("snowflake", "連続記録フリーズ 月4回 (無料は月1回)")
            benefitRow("sparkles", "減量ご褒美マイルストーン (-3 / -5 / -10 kg)")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.15), lineWidth: 1)
        )
    }

    private func benefitRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(Palette.primary)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
    }

    private var planSelector: some View {
        VStack(spacing: 10) {
            planCard(
                productID: ProductID.premiumYearly,
                title: "年額",
                price: "\(store.displayPrice(for: ProductID.premiumYearly)) / 年",
                caption: "実質 約¥317/月 ・ 月額より約34%お得",
                badge: "おすすめ"
            )
            planCard(
                productID: ProductID.premiumMonthly,
                title: "月額",
                price: "\(store.displayPrice(for: ProductID.premiumMonthly)) / 月",
                caption: "まずは気軽に",
                badge: nil
            )
        }
    }

    private func planCard(productID: String, title: String, price: String, caption: String, badge: String?) -> some View {
        let isSelected = selectedProductID == productID
        return Button {
            selectedProductID = productID
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.primary : Palette.textSecondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title).font(.headline)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(Palette.primary, in: Capsule())
                        }
                    }
                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                Text(price)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(Palette.primaryDeep)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(
                (isSelected ? Palette.primary.opacity(0.08) : Palette.surface),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Palette.primary : Palette.primary.opacity(0.15),
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("plan-\(productID)")
    }

    private var purchaseButton: some View {
        let productLoaded = store.products[selectedProductID] != nil
        return Button {
            Task { await performPurchase() }
        } label: {
            HStack {
                if isPurchasing { ProgressView().tint(.white) }
                Text(isPurchasing ? "処理中..."
                     : productLoaded ? "14日間無料で始める" : "商品情報読込中...")
                    .font(.headline.weight(.heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                (productLoaded ? Palette.primary : Palette.textSecondary.opacity(0.5)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .disabled(isPurchasing || !productLoaded)
        .accessibilityIdentifier("premium-purchase-button")
    }

    private var restoreButton: some View {
        Button {
            Task { await performRestore() }
        } label: {
            HStack(spacing: 6) {
                if isRestoring { ProgressView().scaleEffect(0.8) }
                Text(isRestoring ? "復元中..." : "購入を復元")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Palette.primary)
        }
        .disabled(isRestoring)
    }

    private var disclosureBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("サブスクリプションについて")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Palette.textPrimary)
            Text("・14日間の無料体験後、選択したプランで自動更新されます")
            Text("・自動更新: 期間終了 24 時間前までに解約しない限り自動で更新されます")
            Text("・解約方法: 設定 > Apple ID > サブスクリプション からいつでも解約できます")
            Text("・料金は App Store アカウントに請求されます")
            Text("・無料体験中に解約すれば課金されません")
        }
        .font(.caption2)
        .foregroundStyle(Palette.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link("利用規約 (EULA)",
                 destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            Link("プライバシーポリシー",
                 destination: URL(string: "https://torontojapan.github.io/everyday_training/privacy")!)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Palette.primary)
    }

    // MARK: - Actions

    private func performPurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }
        // purchase_complete は StoreKitManager の検証済みトランザクション処理で
        // 計測する (遅延承認も取りこぼさないため)。ここでは開始のみ。
        Analytics.track(.purchaseStarted(product: selectedProductID))
        let ok = await store.purchase(productID: selectedProductID)
        if ok {
            onPurchaseCompleted?()
            dismiss()
        }
    }

    private func performRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        await store.restorePurchases()
        if store.isPremiumActive {
            onPurchaseCompleted?()
            dismiss()
        }
    }
}
