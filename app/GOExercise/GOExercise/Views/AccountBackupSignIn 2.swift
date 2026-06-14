import SwiftUI

/// バックアップ用サインイン(Apple / Google)の共有部品。
/// オンボーディングの「機種変更でも引き継ぐ」ステップと、設定の「アカウントとバックアップ」の
/// 両方で使う。サインイン = 既存アカウントの復元(無ければ新規作成)+ 記録バックアップ自動 ON。
///
/// 連携が成功すると、HomeView の friendCode 変化フックが restoreAfterSignIn を走らせ、
/// ここでも明示的に `recordSync.enableBackup()` を呼ぶことで、新規アカウントでも確実に
/// バックアップが ON になる(どちらも同期 mutex で直列化されるので競合しない)。
struct AccountBackupSignIn: View {
    /// 完了コールバック。`true` = サインインしてバックアップ ON、`false` = スキップ/未完了。
    var onFinished: (Bool) -> Void = { _ in }
    /// スキップボタンを出すか(オンボーディングでは出す。設定では出さない)。
    var showsSkip: Bool = false

    @Environment(FriendsStore.self) private var friendsStore
    @Environment(RecordSyncCoordinator.self) private var recordSync
    @Environment(\.colorScheme) private var colorScheme

    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var googleCoordinator = GoogleSignInCoordinator()
    @State private var isWorking = false
    @State private var errorText: String?

    var body: some View {
        VStack(spacing: 12) {
            if isWorking {
                ProgressView()
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
            } else {
                if SupabaseConfig.appleLinkEnabled {
                    AppleIDButton(type: .signIn, style: colorScheme == .dark ? .white : .black) {
                        Task { await signInWithApple() }
                    }
                    .frame(height: 46)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("backup-signin-apple")
                }
                if SupabaseConfig.googleLinkEnabled {
                    GoogleSignInButton(title: "Google で続ける") {
                        Task { await signInWithGoogle() }
                    }
                    .accessibilityIdentifier("backup-signin-google")
                }
                if showsSkip {
                    Button("あとで") { onFinished(false) }
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 4)
                        .accessibilityIdentifier("backup-signin-skip")
                }
            }
            if let errorText {
                Text(errorText)
                    .font(Typography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Sign-in flows

    private func signInWithApple() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        errorText = nil
        do {
            let cred = try await appleCoordinator.requestIdToken()
            let result = await friendsStore.restoreWithApple(idToken: cred.idToken, nonce: cred.nonce)
            await finish(result, appleFullName: cred.fullName)
        } catch AccountLinkError.cancelled {
            // 認可前キャンセル: 何もしない(welcome/設定に留まる)。
        } catch {
            errorText = AccountLinkError.failed.errorDescription
        }
    }

    private func signInWithGoogle() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        errorText = nil
        let coordinator = googleCoordinator
        let flow: WebAuthFlow = { url in try await coordinator.presentWebFlow(url: url) }
        let result = await friendsStore.restoreWithGoogle(presenting: flow)
        await finish(result, appleFullName: nil)
    }

    private func finish(_ result: FriendsStore.RestoreResult, appleFullName: String?) async {
        switch result {
        case .restored, .created:
            // Apple から表示名が取れた新規アカウントは反映(同名は no-op)。
            if result == .created, let name = appleFullName {
                await friendsStore.updateDisplayName(name)
            }
            // 記録バックアップを ON にして同期(新規なら push、既存なら pull で復元)。
            await recordSync.enableBackup()
            onFinished(true)
        case .cancelled:
            break
        case .failed(let message):
            errorText = message
        }
    }
}
