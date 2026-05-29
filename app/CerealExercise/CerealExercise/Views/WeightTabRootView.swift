import SwiftUI

/// 体重タブの最上位 View。体重タブは GOプレミアム機能なので、未加入のときは
/// 内容をぼかして paywall を被せる。
///
/// User 要件:
/// - 体重 *タブ* (内容) は Premium 未加入だとロックされる
/// - bottom tab のアイコン自体は常に表示
/// - ホームの「記録する」内の体重入力は影響なし (gate なし)
struct WeightTabRootView: View {
    static let paywallCooldownKey = "weightTab.paywallDismissedAt.v1"
    /// X 閉じ後この秒数は自動再表示を抑制 (nag 回避)。
    /// ユーザーは「GOプレミアムを見る」ボタンで手動再オープン可能。
    static let paywallCooldownSeconds: TimeInterval = 6 * 60 * 60  // 6 時間

    @Environment(StoreKitManager.self) private var storeKit
    @State private var showPaywall = false
    /// 購入成功直後の dismiss で cooldown を書き込まないためのフラグ。
    @State private var purchasedDuringSession = false

    private var isUnlocked: Bool { storeKit.isPremiumActive }

    var body: some View {
        // NavigationStack は呼び出し側 (MainTabView / RootSplitView) で wrap する。
        ZStack {
            WeightView()
                .disabled(!isUnlocked)
                .blur(radius: isUnlocked ? 0 : 6)
            if !isUnlocked {
                lockedOverlay
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { updateGate() }
        .onChange(of: storeKit.isPremiumActive) { _, _ in updateGate() }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // X 閉じ / スワイプ dismiss のみ cooldown 書き込み。
            // 購入成功 dismiss は purchasedDuringSession で skip。
            if !purchasedDuringSession {
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.paywallCooldownKey)
            }
            purchasedDuringSession = false
        }) {
            PremiumPaywallSheet(store: storeKit, context: .weight) {
                purchasedDuringSession = true
                UserDefaults.standard.removeObject(forKey: Self.paywallCooldownKey)
            }
        }
    }

    private func updateGate() {
        if isUnlocked {
            // subscription が startup race で遅れて有効化されても確実に閉じる。
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

    private var lockedOverlay: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44, weight: .heavy))
                .foregroundStyle(Palette.primary)
            Text("体重タブは GOプレミアム機能です")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("14日間無料でお試しいただけます。\n推移グラフ・BMI・レポート・周期オーバーレイなどを解放。")
                .font(.subheadline)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Button("GOプレミアムを見る") { showPaywall = true }
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
