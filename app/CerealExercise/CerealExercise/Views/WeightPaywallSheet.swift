import SwiftUI

/// 体重 Pro サブスクリプションへの誘導 sheet。
/// `WeightAccess.freeTrialExpired` のときに体重タブで全画面で出る。
///
/// Apple の IAP 審査要件 (App Review Guidelines 3.1.2 / 3.1.1) を満たすため:
/// - 価格 / 期間 / 自動更新の明示
/// - 「購入を復元」を必ず提供
/// - プライバシーポリシー / 利用規約 (EULA) リンク
/// - キャンセル方法 (設定 > Apple ID > サブスクリプション)
struct WeightPaywallSheet: View {
    @Bindable var store: StoreKitManager
    let onPurchaseCompleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var isRestoring = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefitList
                    purchaseCard
                    if let err = store.lastError {
                        // 直前の購入 / 復元失敗を sheet 内に表示 (LLM A 指摘)。
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
            .navigationTitle("体重 Pro")
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
                Analytics.track(.paywallViewed(product: ProductID.weightProMonthly))
                await store.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "scalemass.fill")
                .font(.system(size: 56, weight: .heavy))
                .foregroundStyle(Palette.primary)
            Text("体重タブの全機能を継続して使う")
                .font(.title2.weight(.heavy))
                .multilineTextAlignment(.center)
            Text("無料体験 30 日が終了しました。\n月額 \(store.displayPrice(for: ProductID.weightProMonthly)) で続けられます。")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefitRow("scalemass", "体重の記録 + 推移グラフ (日 / 週 / 月)")
            benefitRow("chart.xyaxis.line", "週次 / 月次レポート + トレンドライン")
            benefitRow("calendar", "周期オーバーレイで体調と体重を重ねて可視化")
            benefitRow("target", "目標 / BMI / 達成リング / 進捗バー")
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

    private var purchaseCard: some View {
        VStack(spacing: 8) {
            Text("体重 Pro 月額")
                .font(.headline)
            Text(store.displayPrice(for: ProductID.weightProMonthly) + " / 月")
                .font(.title.weight(.heavy))
                .foregroundStyle(Palette.primaryDeep)
            Text("自動更新 (いつでも解約可)")
                .font(.caption)
                .foregroundStyle(Palette.textSecondary)

            let productLoaded = store.weightProProduct != nil
            Button {
                Task { await performPurchase() }
            } label: {
                HStack {
                    if isPurchasing { ProgressView().tint(.white) }
                    Text(isPurchasing ? "処理中..."
                         : productLoaded ? "購入する" : "商品情報読込中...")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    (productLoaded ? Palette.primary : Palette.textSecondary.opacity(0.5)),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .disabled(isPurchasing || !productLoaded)
            .padding(.top, 8)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Palette.surface, Palette.primary.opacity(0.08)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.25), lineWidth: 1)
        )
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
        Analytics.track(.purchaseStarted(product: ProductID.weightProMonthly))
        let ok = await store.purchase(productID: ProductID.weightProMonthly)
        if ok {
            onPurchaseCompleted()
            dismiss()
        }
    }

    private func performRestore() async {
        isRestoring = true
        defer { isRestoring = false }
        await store.restorePurchases()
        if store.isWeightProActive {
            onPurchaseCompleted()
            dismiss()
        }
    }
}
