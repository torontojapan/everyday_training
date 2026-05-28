import SwiftUI

/// 体重タブの最上位 View。`WeightView` を gate でラップし、無料体験が切れ、
/// かつ Pro 未購入のときに paywall を被せてロックする。
///
/// User 要件:
/// - 体重 *タブ* (内容) はロックされる
/// - bottom tab のアイコン自体は常に表示
/// - ホームの「記録する」内の体重入力は影響なし (gate なし)
struct WeightTabRootView: View {
    static let paywallCooldownKey = "weightTab.paywallDismissedAt.v1"
    /// X 閉じ後この秒数は自動再表示を抑制 (LLM B 指摘: nag 回避)。
    /// ユーザーは「購入する」ボタンで手動再オープン可能。
    static let paywallCooldownSeconds: TimeInterval = 6 * 60 * 60  // 6 時間

    @Environment(StoreKitManager.self) private var storeKit
    @State private var gate = WeightAccessGate()
    @State private var access: WeightAccess = .freeTrialActive(remainingDays: 30)
    @State private var showPaywall = false
    /// 購入成功直後の dismiss で cooldown を書き込まないためのフラグ
    /// (Codex 指摘: 成功 → onPurchaseCompleted で removeObject → onDismiss で
    /// また書く、を回避するため、成功 dismiss はこのフラグでスキップ)。
    @State private var purchasedDuringSession = false

    var body: some View {
        // NavigationStack は呼び出し側 (MainTabView / RootSplitView) で wrap する。
        // 二重 NavigationStack を避けるため本 View には含めない。
        ZStack {
            WeightView()
                .disabled(!access.isUnlocked)
                .blur(radius: access.isUnlocked ? 0 : 6)
                .overlay(alignment: .top) {
                    if case .freeTrialActive(let days) = access {
                        trialRemainingChip(days: days)
                    }
                }
            if !access.isUnlocked {
                lockedOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            gate.markOpenedIfNeeded()
            updateAccess()
        }
        .onChange(of: storeKit.isWeightProActive) { _, _ in updateAccess() }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // X 閉じ / スワイプ dismiss のみ cooldown 書き込み。
            // 購入成功 dismiss は purchasedDuringSession で skip。
            if !purchasedDuringSession {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.paywallCooldownKey)
            }
            purchasedDuringSession = false
        }) {
            WeightPaywallSheet(store: storeKit) {
                purchasedDuringSession = true
                UserDefaults.standard.removeObject(forKey: Self.paywallCooldownKey)
                updateAccess()
            }
        }
    }

    private func updateAccess() {
        access = gate.currentAccess(isSubscribed: storeKit.isWeightProActive)
        if access.isUnlocked {
            // subscription が startup race で遅れて有効化されても確実に閉じる
            // (Codex 指摘: 購読者が paywall に stuck するのを防ぐ)。
            if showPaywall { showPaywall = false }
        } else if !showPaywall, !isInCooldown() {
            // ロック状態 & cooldown 外なら自動で paywall を出す。
            showPaywall = true
        }
    }

    private func isInCooldown() -> Bool {
        let ts = UserDefaults.standard.double(forKey: Self.paywallCooldownKey)
        guard ts > 0 else { return false }
        return Date().timeIntervalSince1970 - ts < Self.paywallCooldownSeconds
    }

    private func trialRemainingChip(days: Int) -> some View {
        Text("無料体験 残り \(days) 日")
            .font(.caption.weight(.heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Palette.primary.opacity(0.92), in: Capsule())
            .padding(.top, 8)
    }

    private var lockedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(Palette.primary)
            Text("無料体験 30 日が終了しました")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("月額 \(storeKit.displayPrice(for: ProductID.weightProMonthly)) で\n体重タブの全機能を続けて使えます")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("購入する") { showPaywall = true }
                .font(.headline.weight(.heavy))
                .foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 12)
                .background(Palette.primary, in: Capsule())
            Text("ホーム画面の「記録する」からの体重入力は\n引き続き無料でご利用いただけます")
                .font(.caption2)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
        }
        .padding(28)
        .background(Palette.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
        .padding(.horizontal, 32)
    }
}
