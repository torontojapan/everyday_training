import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum FriendSortOrder: String, CaseIterable, Identifiable {
    case streakDesc        // 連続日数の多い順
    case todayFirst        // 今日達成済みを先頭に
    case recentlyUpdated   // 最終更新が新しい順

    var id: String { rawValue }

    var label: String {
        switch self {
        case .streakDesc: return "連続日数順"
        case .todayFirst: return "今日達成順"
        case .recentlyUpdated: return "更新順"
        }
    }
}

struct FriendsView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingAdd = false
    @State private var sortOrder: FriendSortOrder = .streakDesc
    @State private var detailFriend: FriendProfile?
    @State private var cheerToast: String?
    @State private var cheerToastToken: UUID?
    @State private var pendingRemovalFriend: FriendProfile?
    @State private var isShowingMyQR = false
    @State private var cheerTarget: FriendProfile?
    /// QR ディープリンクの pending code を監視するための共有ルーター (Codex監査#Major1)。
    @State private var router = DeepLinkRouter.shared
    /// QR ディープリンクから渡された、友達追加画面のプリフィル用コード。
    @State private var addInitialCode: String?
    /// Phase 7.0: 友達画面に「リスト / 公園」切替セグメント追加。
    @State private var displayMode: DisplayMode = .park
    /// チア送信時の喜び演出 (絵文字が弾けて消える)。reduceMotion 時は無効。
    @State private var cheerBurst: CheerBurst?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 初回の「表示名を決めてね」インライン入力を一度きりにするフラグ。
    @AppStorage("friends.didDismissNamePrompt") private var didDismissNamePrompt = false
    /// 初回入力カードのテキスト。
    @State private var namePromptText = ""
    /// ヘッダーの表示名変更 alert 用。
    @State private var isShowingRename = false
    @State private var renameText = ""
    /// Phase 2: アカウント連携(機種変復旧)。バックアップカードの状態。
    @State private var appleCoordinator = AppleSignInCoordinator()
    @State private var isLinkingAccount = false
    @State private var backupToast: String?
    @State private var pendingSwitchCreds: ApplePendingSwitch?
    /// バックアップ促しを「あとで」した時刻 (30日沈黙)。
    @AppStorage("friends.backupPromptDismissedAt") private var backupPromptDismissedAt: Double = 0

    struct ApplePendingSwitch: Identifiable { let id = UUID(); let idToken: String; let nonce: String }
    private let hapticFeedback: any HapticFeedbackProviding = HapticFeedback()

    struct CheerBurst: Identifiable, Equatable { let id = UUID(); let emoji: String }

    enum DisplayMode: String, CaseIterable { case park, list }

    var body: some View {
        Group {
            if let profile = friendsStore.profile {
                signedInBody(profile: profile)
            } else if friendsStore.isSigningIn {
                // 能動操作でサインイン中だけ spinner。
                friendsConnectingBody
            } else {
                // 未サインインの idle ホームは常に welcome (lazy/opt-in)。直前の
                // サインイン失敗は welcome 内にインライン表示し、CTA が再試行を兼ねる
                // (stale な lastError で welcome に戻れなくなる不具合を回避, Codex)。
                friendsWelcomeBody
            }
        }
        .background(Palette.background)
        .navigationTitle("友達")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // lazy 化: タブ表示だけでは匿名アカウントを作らない (孤児/プライバシー対策)。
            // サインイン済みのときだけ最新化。未サインインは welcome を見せ、能動操作
            // (友達とつながる / deep link 承認) の瞬間に初めて匿名サインインする。
            if friendsStore.isSignedIn {
                await friendsStore.refresh()
                if SupabaseConfig.isAccountLinkingEnabled {
                    await friendsStore.refreshBackupStatus()
                }
            }
            handlePendingFriendCode()   // pending な deep link code がある時だけ lazy サインイン
            // --mock-open-* はスクショ / デモ専用の自動オープン。Release では無効化し、
            // 本番でデモ動線が勝手に開かないようにする (debug 引数は Release で無効)。
            #if DEBUG
            let args = ProcessInfo.processInfo.arguments
            // デモ/スクショ専用の自動オープンは signed-in 前提なので、開く前にサインインを通す。
            if args.contains("--mock-open-friend-detail") || args.contains("--mock-open-friend-add") {
                await friendsStore.ensureSignedIn()
            }
            if args.contains("--mock-open-friend-detail") {
                // open the highest-streak friend so screenshots show a rich profile
                let best = FriendSorter.sort(friendsStore.friends, by: .streakDesc).first
                detailFriend = best
            }
            if args.contains("--mock-open-friend-add") {
                isShowingAdd = true
            }
            #endif
        }
        .overlay(alignment: .bottom) {
            // toast を下部に移動。上部は Dynamic Island / Navigation Bar
            // と被るため、下部 safe area の少し上の方が衝突しにくい。
            if let cheerToast {
                Text(cheerToast)
                    .font(Typography.caption)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.bottom, 24)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .accessibilityIdentifier("friend-cheer-toast")
            }
        }
        .animation(.easeOut(duration: 0.25), value: cheerToast)
        .overlay {
            // チア送信の喜び演出: 絵文字が中央で弾けて上へフェード (reduceMotion 時は出さない)。
            if let burst = cheerBurst {
                Text(burst.emoji)
                    .font(.system(size: 96))
                    .id(burst.id)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.55), value: cheerBurst)
        .sheet(isPresented: $isShowingAdd, onDismiss: {
            addInitialCode = nil          // プリフィルを破棄
            tryPresentPendingAdd()        // 保留中の deep link code があれば再開
        }) {
            NavigationStack {
                FriendAddView(initialCode: addInitialCode)
                    .environment(friendsStore)
            }
        }
        // 表示中に新たな QR/ディープリンク (?code=) が来ても消費する (Codex監査#Major1)。
        .onChange(of: router.pendingFriendCode) { _, _ in
            handlePendingFriendCode()
        }
        // 削除確認ダイアログ(sheet でない)が閉じた後にも保留 code を再試行 (Codex監査ループ2)。
        .onChange(of: pendingRemovalFriend == nil) { _, becameNil in
            if becameNil { tryPresentPendingAdd() }
        }
        .sheet(item: $detailFriend, onDismiss: { tryPresentPendingAdd() }) { friend in
            FriendDetailView(friend: friend)
                .environment(friendsStore)
        }
        .confirmationDialog(
            pendingRemovalFriend.map { "\($0.displayName) を友達から外しますか？" } ?? "",
            isPresented: Binding(
                get: { pendingRemovalFriend != nil },
                set: { if !$0 { pendingRemovalFriend = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingRemovalFriend
        ) { friend in
            Button("友達を解除", role: .destructive) {
                Task { await friendsStore.remove(friend) }
                pendingRemovalFriend = nil
            }
            Button("キャンセル", role: .cancel) {
                pendingRemovalFriend = nil
            }
        } message: { _ in
            Text("再度つながるには友達コードで申請が必要です。")
        }
        .sheet(item: $cheerTarget, onDismiss: { tryPresentPendingAdd() }) { friend in
            CheerPickerSheet(friend: friend) { kind in
                cheerTarget = nil
                Task { await sendCheer(kind, to: friend) }
            }
            .presentationDetents([.height(280)])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Connecting / sign-in failure

    /// 能動操作で匿名サインイン中の spinner (壁カードは廃止。Supabase 匿名認証で操作不要)。
    /// 失敗時の再試行は welcome 側に集約 (idle ホームを常に welcome に保つため, Codex)。
    private var friendsConnectingBody: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("準備しています…")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Welcome (未サインイン)

    /// 未サインイン時の歓迎画面。タブを開いただけではここに留まり、**クラウドへは一切書き込まない**
    /// (孤児アカウント/プライバシー対策の lazy 化)。「友達とつながる」= 能動操作の瞬間に初めて
    /// 匿名サインインする (メール/パスワード不要)。壁ではなく opt-in の入口。
    private var friendsWelcomeBody: some View {
        let breed = UserCatPreferences.shared.myCat
        let asset = CatState.waitingMorning.assetName(breed: breed)
        let resolved = UIImage(named: asset) != nil ? asset : CatBreed.fallbackAssetName(for: .waitingMorning)
        return ScrollView {
            VStack(spacing: 18) {
                Image(resolved)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)
                    .padding(.top, 24)
                Text("友達と一緒に続けよう")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text("つながると、おたがいの連続記録を見て応援し合えます。\nメールもパスワードも不要です。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 24)
                // 直前のサインインが失敗していたら、やさしい固定文でインライン表示。
                // 下の「友達とつながる」がそのまま再試行になる (生エラー文言は出さない)。
                if friendsStore.lastError != nil {
                    Text("うまくつながれませんでした。通信状況を確認して、もう一度お試しください。")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primaryDeep)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 24)
                        .accessibilityIdentifier("friends-connect-error")
                }
                PrimaryButton("友達とつながる", systemImage: "person.2.fill") {
                    Task {
                        friendsStore.clearError()
                        await friendsStore.ensureSignedIn()
                        // サインイン成功時、保留中の deep link code があれば追加シートへ。
                        handlePendingFriendCode()
                    }
                }
                .padding(.top, 4)
                .accessibilityIdentifier("friends-connect-button")
                shareAppCard
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .accessibilityIdentifier("friends-welcome")
    }

    /// 「このアプリを友達にシェア」セクション。SwiftUI 標準の `ShareLink` で
    /// LINE / メッセージ / Twitter / メール などの share sheet を呼び出す。
    /// 共有先 URL とメッセージは [[AppSharingConfig]] に集約 (App Store URL
    /// が決まったら 1 箇所差し替えるだけ)。
    private var shareAppCard: some View {
        ShareLink(
            item: AppSharingConfig.shareURL,
            subject: Text(AppSharingConfig.shareSubject),
            message: Text(AppSharingConfig.shareMessage)
        ) {
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primary)
                Text("このアプリを友達にシェア")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("share-app-button")
        .accessibilityLabel("このアプリを友達にシェア")
    }

    // MARK: - Signed in

    private func signedInBody(profile: FriendProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                errorBanner
                profileHeader(profile)

                // 初回のみ: 表示名を決める軽いインライン入力 (スキップ可)。
                if showNamePrompt(for: profile) {
                    namePromptCard
                }

                // 任意: 機種変でも友達を引き継ぐ「バックアップ」促し (消せる/設定でも可)。
                if showBackupCard(for: profile) {
                    backupCard
                }

                // アプリ自体を友達に紹介する導線 (友達コードの共有とは別物)。
                // 友達コード = 既にアプリを入れている人を friend に追加するためのコード。
                // shareAppCard = まだアプリを入れていない人に install 用 URL を投げるため。
                // ユーザー要望でプロフィール直下に固定配置 (招待動線をファーストビューに)。
                shareAppCard

                if !friendsStore.requests.isEmpty {
                    requestsSection
                }

                friendsSection

                Button(role: .destructive) {
                    Task { await friendsStore.signOut() }
                } label: {
                    Label("サインアウト", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(Typography.caption)
                }
                .padding(.top, 20)
            }
            .padding(20)
        }
        .refreshable {
            await friendsStore.refresh()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAdd = true
                } label: {
                    Image(systemName: "person.crop.circle.badge.plus")
                }
                .accessibilityLabel("友達を追加")
                .accessibilityIdentifier("friend-add-button")
            }
        }
        .alert("表示名を変更", isPresented: $isShowingRename) {
            TextField("表示名", text: $renameText)
            Button("変更") {
                let name = renameText
                Task { await friendsStore.updateDisplayName(name) }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("友達に表示される名前です。いつでも変更できます。")
        }
        // 連携の衝突: 既存アカウントに切替(現データ破棄)か中止の二択。マージはしない。
        .confirmationDialog(
            "このアカウントは既に別のデータに紐づいています",
            isPresented: Binding(
                get: { pendingSwitchCreds != nil },
                set: { if !$0 { pendingSwitchCreds = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingSwitchCreds
        ) { creds in
            Button("既存のアカウントに切り替える", role: .destructive) {
                let c = creds
                pendingSwitchCreds = nil
                guard !isLinkingAccount else { return }
                isLinkingAccount = true
                Task {
                    defer { isLinkingAccount = false }
                    let ok = await friendsStore.switchToAppleAccount(idToken: c.idToken, nonce: c.nonce)
                    if ok { showBackupToast("既存のアカウントに切り替えました") }
                }
            }
            Button("中止", role: .cancel) { pendingSwitchCreds = nil }
        } message: { _ in
            Text("切り替えると、いまの端末の友達・コードは失われます。")
        }
        .overlay(alignment: .bottom) {
            if let backupToast {
                Text(backupToast)
                    .font(Typography.caption)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.thinMaterial, in: Capsule())
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.bottom, 24)
                    .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                    .transition(.opacity)
                    .accessibilityIdentifier("friends-backup-toast")
            }
        }
        .animation(.easeOut(duration: 0.25), value: backupToast)
    }

    /// 初回の表示名入力を出すか。自動既定名のままで、まだ閉じていないときだけ。
    private func showNamePrompt(for profile: FriendProfile) -> Bool {
        !didDismissNamePrompt && profile.displayName == FriendsStore.autoDisplayName
    }

    // MARK: - バックアップ(アカウント連携)カード

    /// バックアップ促しを出すか。連携が有効・未バックアップ・トリガー達成・直近未dismiss。
    private func showBackupCard(for profile: FriendProfile) -> Bool {
        guard SupabaseConfig.isAccountLinkingEnabled, !friendsStore.isBackedUp else { return false }
        let trigger = friendsStore.friends.count >= 1 || profile.currentStreak >= 7
        guard trigger else { return false }
        let now = Date().timeIntervalSince1970
        return now - backupPromptDismissedAt > 30 * 24 * 3600   // dismiss 後30日沈黙
    }

    private var backupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("友達を機種変でも引き継ぐ")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("バックアップすると、機種変更や再インストールでも友達とコードを引き継げます。メールやパスワードは不要です。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if isLinkingAccount {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else {
                if SupabaseConfig.appleLinkEnabled {
                    Button {
                        linkWithApple()
                    } label: {
                        Label("Apple でバックアップ", systemImage: "applelogo")
                            .font(Typography.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .accessibilityIdentifier("friends-backup-apple")
                }
                Button("あとで") { backupPromptDismissedAt = Date().timeIntervalSince1970 }
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("friends-backup-card")
    }

    /// Apple 認可 → 連携。衝突なら二択ダイアログ、成功ならトースト。
    private func linkWithApple() {
        guard !isLinkingAccount else { return }   // 連打ガード (同期的に立てる)
        isLinkingAccount = true
        Task {
            defer { isLinkingAccount = false }
            do {
                let cred = try await appleCoordinator.requestIdToken()
                switch await friendsStore.linkApple(idToken: cred.idToken, nonce: cred.nonce) {
                case .linked:
                    // 表示名が既定のままで Apple から名前を得られたら反映。
                    if let name = cred.fullName,
                       friendsStore.profile?.displayName == FriendsStore.autoDisplayName {
                        await friendsStore.updateDisplayName(name)
                    }
                    showBackupToast("バックアップしました")
                case .collision:
                    pendingSwitchCreds = ApplePendingSwitch(idToken: cred.idToken, nonce: cred.nonce)
                case .failed(let message):
                    friendsStore.lastError = message
                }
            } catch AccountLinkError.cancelled {
                // 何もしない
            } catch {
                friendsStore.lastError = AccountLinkError.failed.errorDescription
            }
        }
    }

    private func showBackupToast(_ text: String) {
        backupToast = text
        Task {
            try? await Task.sleep(for: .seconds(2.0))
            if backupToast == text { backupToast = nil }
        }
    }

    /// 初回のみの「表示名を決めてね」インライン入力カード。
    private var namePromptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("表示名を決めましょう")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("友達に表示される名前です。あとからいつでも変更できます。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            TextField("例: ジュン", text: $namePromptText)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("friends-name-prompt-field")
            HStack {
                Button("あとで") {
                    didDismissNamePrompt = true
                }
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                Spacer()
                Button("決定") {
                    let name = namePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task {
                        await friendsStore.updateDisplayName(name)
                        // 更新成功時のみ閉じる。失敗時は既定名のままなので再度促す (Codex)。
                        if friendsStore.profile?.displayName == name {
                            didDismissNamePrompt = true
                        }
                    }
                }
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(Palette.primaryDeep)
                .disabled(namePromptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityIdentifier("friends-name-prompt")
    }

    /// UI test 用 ID。profileHeader 全体を 1 つの accessibility container として
    /// まとめ、shareAppCard との物理的隣接 (= 「直下」要件) を frame 比較で
    /// 検証できるようにする (Codex round3)。
    private static let profileSectionAccessibilityID = "friends-profile-section"

    private func profileHeader(_ profile: FriendProfile) -> some View {
        // 自分のアイコンは UserCatPreferences の breed を反映 (Phase 6.7)。
        let myBreed = UserCatPreferences.shared.myCat
        return VStack(spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(myBreed.tintColor.opacity(0.30))
                        .frame(width: 56, height: 56)
                    Image(myBreed.avatarAssetName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.05)
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(profile.displayName)
                            .font(Typography.title)
                            .foregroundStyle(Palette.textPrimary)
                        Button {
                            renameText = profile.displayName == FriendsStore.autoDisplayName ? "" : profile.displayName
                            isShowingRename = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .accessibilityLabel("表示名を変更")
                        .accessibilityIdentifier("friends-rename-button")
                    }
                    Text("@\(profile.username)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text("🔥 \(profile.currentStreak) 日連続")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.primaryDeep)
                }
                Spacer()
            }

            // 友達コード行は常時表示、QR は折り畳み (デフォルト閉)。
            // 以前は QR まで含めて画面の 60% を占有していたが、これで
            // 友達リストがファーストビューに入る。
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("あなたの友達コード")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                        Text(profile.friendCode)
                            .font(.system(size: 24, weight: .heavy, design: .monospaced))
                            .foregroundStyle(Palette.primaryDeep)
                    }
                    Spacer()
                    ShareLink(item: shareText(for: profile)) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryDeep)
                            .frame(width: 44, height: 44)
                            .background(Palette.chipBackground, in: Circle())
                    }
                    .accessibilityLabel("友達コードを共有")
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isShowingMyQR.toggle() }
                    } label: {
                        Image(systemName: isShowingMyQR ? "qrcode.viewfinder" : "qrcode")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Palette.primaryDeep)
                            .frame(width: 44, height: 44)
                            .background(Palette.chipBackground, in: Circle())
                    }
                    .accessibilityLabel(isShowingMyQR ? "QR コードを隠す" : "QR コードを表示")
                    .accessibilityIdentifier("toggle-my-qr")
                }
                if isShowingMyQR, let qr = qrImage(text: friendInviteURL(profile.friendCode)) {
                    HStack {
                        Spacer()
                        Image(uiImage: qr)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 140, height: 140)
                            .padding(8)
                            .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Spacer()
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(Self.profileSectionAccessibilityID)
    }

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("申請が届いています (\(friendsStore.requests.count))")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            ForEach(friendsStore.requests) { request in
                requestRow(request)
            }
        }
    }

    private func requestRow(_ request: FriendRequest) -> some View {
        HStack(spacing: 12) {
            FriendAvatarView(friend: request.fromProfile, size: 36, showsDecorationBorder: true)
            VStack(alignment: .leading, spacing: 2) {
                Text(request.fromProfile.displayName)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text("@\(request.fromProfile.username) · 🔥 \(request.fromProfile.currentStreak) 日連続")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            Button("承認") {
                Task { await friendsStore.accept(request) }
            }
            .font(Typography.caption)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(Palette.primary, in: Capsule())
            .foregroundStyle(.white)
            Button {
                Task { await friendsStore.decline(request) }
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Palette.textSecondary)
            }
            .accessibilityLabel("拒否")
        }
        .padding(12)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// 友達0人の空状態。テキストだけでなく「待っている猫」で温かく (トンマナ強化)。
    private var friendsEmptyState: some View {
        let breed = UserCatPreferences.shared.myCat
        let asset = CatState.waitingMorning.assetName(breed: breed)
        let resolved = UIImage(named: asset) != nil ? asset : CatBreed.fallbackAssetName(for: .waitingMorning)
        return VStack(spacing: 12) {
            Image(resolved)
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .opacity(0.95)
            Text("まだ友達がいません")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("右上の + から、友達コードや QR でつながろう。\n猫があなたの友達を待っています。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("friends-empty")
    }

    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("友達 (\(friendsStore.friends.count))")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if !friendsStore.friends.isEmpty {
                    // Phase 7.0 公園 / リスト切替
                    Picker("表示", selection: $displayMode) {
                        Image(systemName: "square.grid.2x2").tag(DisplayMode.park)
                        Image(systemName: "list.bullet").tag(DisplayMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 90)
                    .accessibilityIdentifier("friends-display-mode")
                }
                if !friendsStore.friends.isEmpty {
                    // 「ランキング」をテキストつき chip に。アイコンだけだと
                    // 何が起きるか分かりにくいので、視認性を優先。
                    NavigationLink {
                        WeeklyRankingView()
                            .environment(friendsStore)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                            Text("順位を見る")
                        }
                        .font(Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Palette.settingsAccent.opacity(0.18), in: Capsule())
                        .foregroundStyle(Palette.settingsAccent)
                    }
                    .accessibilityLabel("週間ランキング")
                    .accessibilityIdentifier("weekly-ranking-link")
                    sortMenu
                }
            }
            if friendsStore.isLoading && friendsStore.friends.isEmpty {
                // 初回ロード中。空状態(「友達がいません」)のチラつきを避ける。
                HStack {
                    Spacer()
                    ProgressView().tint(Palette.primary)
                    Spacer()
                }
                .padding(.vertical, 28)
                .accessibilityIdentifier("friends-loading")
            } else if friendsStore.friends.isEmpty {
                friendsEmptyState
            } else if displayMode == .park {
                FriendsParkView(friends: sortedFriends) { friend in
                    detailFriend = friend
                    hapticFeedback.tap()
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            } else {
                ForEach(sortedFriends) { friend in
                    friendCard(friend)
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("並び順", selection: $sortOrder) {
                ForEach(FriendSortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOrder.label)
            }
            .font(Typography.caption)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Palette.chipBackground, in: Capsule())
            .foregroundStyle(Palette.textPrimary)
        }
        .accessibilityIdentifier("friend-sort-menu")
    }

    private var sortedFriends: [FriendProfile] {
        FriendSorter.sort(friendsStore.friends, by: sortOrder)
    }

    private func friendCard(_ friend: FriendProfile) -> some View {
        // カードは「装飾 + 名前 + 連続 + 今日達成 + 更新」に絞る。
        Button {
            detailFriend = friend
            hapticFeedback.tap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    FriendAvatarView(friend: friend, size: 56, showsDecorationBorder: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(friend.displayName)
                            .font(Typography.headline)
                            .foregroundStyle(Palette.textPrimary)
                        Text("@\(friend.username)")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("🔥 \(friend.currentStreak)")
                            .font(.system(.title3, design: .rounded, weight: .heavy))
                            .foregroundStyle(Palette.primaryDeep)
                            .monospacedDigit()
                        Text("累計 \(friend.totalAchievedDays)日")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                HStack(spacing: 8) {
                    if friend.todayAchieved {
                        Label("今日達成", systemImage: "checkmark.seal.fill")
                            .font(Typography.caption)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Palette.success.opacity(0.15), in: Capsule())
                            .foregroundStyle(Palette.success)
                        if let cat = friend.todayCategoryName {
                            Text(cat)
                                .font(Typography.caption)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Palette.chipBackground, in: Capsule())
                                .foregroundStyle(Palette.primaryDeep)
                        }
                    } else {
                        Label("今日はまだ未達成", systemImage: "hourglass")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer()
                    Text(relativeUpdated(friend.lastUpdated))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }

                // クイック応援: 主要 emoji を 1 タップで送信できる。
                // 「..」は CheerPickerSheet を開いて 4 種から選ぶ既存導線を残す。
                // 2 タップ必要だった応援を、1 タップで完了するショートカット。
                HStack(spacing: 6) {
                    ForEach([CheerKind.fight, .great, .clap, .fire], id: \.self) { kind in
                        Button {
                            Task { await sendCheer(kind, to: friend) }
                        } label: {
                            Text(kind.emoji)
                                .font(.system(size: 20))
                                .frame(minWidth: 44, minHeight: 44)
                                .background(Palette.primary.opacity(0.10), in: Circle())
                        }
                        .buttonStyle(.plain)
                        // 送信中は無効化して連打多重送信を防ぐ (Store 側でも guard 済み)。
                        .disabled(friendsStore.cheeringCodes.contains(friend.friendCode))
                        .accessibilityLabel("\(friend.displayName) に \(kind.label) を送る")
                        .accessibilityIdentifier("quick-cheer-\(kind.rawValue)-\(friend.friendCode)")
                    }
                    Spacer()
                    Button {
                        cheerTarget = friend
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .heavy))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(Palette.chipBackground, in: Circle())
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(friend.displayName) への応援を選んで送る")
                    .accessibilityIdentifier("open-cheer-sheet-\(friend.friendCode)")
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary.opacity(0.5))
                    .padding(.top, 14).padding(.trailing, 12)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("friend-card-\(friend.friendCode)")
        .accessibilityHint("タップで詳細を表示")
        .contextMenu {
            Button { detailFriend = friend } label: {
                Label("詳細を見る", systemImage: "person.crop.circle.fill")
            }
            Button(role: .destructive) {
                // 即実行ではなく confirmation dialog 経由に変える。
                // 誤タップで「友達解除」が起きると Undo できない。
                pendingRemovalFriend = friend
            } label: {
                Label("友達を解除", systemImage: "person.crop.circle.badge.minus")
            }
        }
    }

    /// QR ディープリンクの pending code を消費して友達追加画面を開く。
    /// サインイン済みなら即プリフィル表示。未サインインなら裏で匿名サインインしてから消費。
    /// プロフィール生成後に再度呼ばれて消費される (onChange 連携)。
    private func handlePendingFriendCode() {
        guard router.pendingFriendCode != nil else { return }
        if friendsStore.isSignedIn {
            tryPresentPendingAdd()
        } else {
            // 壁を出さず裏でサインインし、完了後に追加シートへ (code は保持)。
            Task {
                await friendsStore.ensureSignedIn()
                tryPresentPendingAdd()
            }
        }
    }

    /// **他のシートが開いておらず・サインイン済み**のときだけ追加シートを開く。
    /// present が確実になってから pendingFriendCode を nil 化する (喪失レース回避, Codex監査#Major2)。
    /// 条件を満たさない場合は何もしない (各シートの onDismiss で再試行される)。
    private func tryPresentPendingAdd() {
        guard let code = router.pendingFriendCode, friendsStore.isSignedIn,
              !isShowingAdd,
              detailFriend == nil, cheerTarget == nil, pendingRemovalFriend == nil
        else { return }
        router.pendingFriendCode = nil
        addInitialCode = code
        isShowingAdd = true
    }

    /// エラーバナー (signedIn/signedOut 両方の上部)。赤警告にせず peach 系で世界観維持。
    @ViewBuilder
    private var errorBanner: some View {
        if let error = friendsStore.lastError {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Button("更新") { Task { await friendsStore.reload() } }
                            .accessibilityIdentifier("friends-error-reload")
                        Button("閉じる") { friendsStore.clearError() }
                            .accessibilityIdentifier("friends-error-dismiss")
                    }
                    .font(Typography.caption)
                    .foregroundStyle(Palette.primaryDeep)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .accessibilityIdentifier("friends-error-banner")
        }
    }

    private func sendCheer(_ kind: CheerKind, to friend: FriendProfile) async {
        hapticFeedback.success()
        // 喜び演出: 絵文字が中央で弾ける (reduceMotion 時はスキップ)。
        if !reduceMotion {
            let burst = CheerBurst(emoji: kind.emoji)
            cheerBurst = burst
            Task {
                try? await Task.sleep(for: .milliseconds(650))
                // 連続送信で別 burst に置き換わっていたら消さない (id で同一性を判定)。
                if cheerBurst?.id == burst.id { cheerBurst = nil }
            }
        }
        await friendsStore.cheer(kind, to: friend.friendCode)
        let token = UUID()
        cheerToastToken = token
        cheerToast = "\(kind.emoji) \(friend.displayName) に \(kind.label) を送りました"
        try? await Task.sleep(for: .seconds(2.0))
        // Only clear the toast if no newer cheer has replaced ours. Using a
        // token avoids the substring race (two friends with overlapping
        // displayName like "あき" / "あきら" would otherwise dismiss each
        // other's toasts).
        if cheerToastToken == token {
            cheerToast = nil
            cheerToastToken = nil
        }
    }

    private var todayWeekdayIndex: Int {
        let wd = Calendar.mondayFirst.component(.weekday, from: Date())
        return (wd + 5) % 7
    }

    private func relativeUpdated(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return "更新 \(formatter.localizedString(for: date, relativeTo: Date()))"
    }

    private func avatar(tier: Int, small: Bool = false) -> some View {
        let size: CGFloat = small ? 36 : 56
        return ZStack {
            Circle()
                .fill(tierColor(tier).opacity(0.25))
                .frame(width: size, height: size)
            Text("🐱")
                .font(.system(size: small ? 22 : 32))
        }
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return Palette.textSecondary
        }
    }

    /// QR にエンコードする招待ディープリンク。相手が標準カメラで読むと
    /// `goexercise://friends?code=XXX` で本アプリが開き、追加画面がプリフィルされる。
    private func friendInviteURL(_ code: String) -> String {
        "goexercise://friends?code=\(code)"
    }

    private func qrImage(text: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.correctionLevel = "H"
        guard let output = filter.outputImage else { return nil }
        let transform = CGAffineTransform(scaleX: 8, y: 8)
        let scaled = output.transformed(by: transform)
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cg)
    }

    private func shareText(for profile: FriendProfile) -> String {
        "GO エクササイズで一緒に運動しよう！\n友達コード: \(profile.friendCode)\n@\(profile.username) (🔥 \(profile.currentStreak)日連続)"
    }
}

// MARK: - Cheer picker sheet

struct CheerPickerSheet: View {
    let friend: FriendProfile
    let onSend: (CheerKind) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("\(friend.displayName) に応援を送る")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
                .padding(.top, 24)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(CheerKind.allCases, id: \.self) { kind in
                    Button {
                        onSend(kind)
                    } label: {
                        VStack(spacing: 4) {
                            Text(kind.emoji).font(.system(size: 28))
                            Text(kind.label)
                                .font(Typography.body)
                                .foregroundStyle(Palette.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableScaleButtonStyle())
                    .accessibilityIdentifier("cheer-sheet-\(kind.rawValue)")
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .background(Palette.background)
    }
}

// MARK: - Friend sorting

enum FriendSorter {
    static func sort(_ friends: [FriendProfile], by order: FriendSortOrder) -> [FriendProfile] {
        switch order {
        case .streakDesc:
            return friends.sorted { lhs, rhs in
                if lhs.currentStreak != rhs.currentStreak {
                    return lhs.currentStreak > rhs.currentStreak
                }
                return lhs.totalAchievedDays > rhs.totalAchievedDays
            }
        case .todayFirst:
            return friends.sorted { lhs, rhs in
                if lhs.todayAchieved != rhs.todayAchieved {
                    return lhs.todayAchieved && !rhs.todayAchieved
                }
                return lhs.currentStreak > rhs.currentStreak
            }
        case .recentlyUpdated:
            return friends.sorted { $0.lastUpdated > $1.lastUpdated }
        }
    }
}
