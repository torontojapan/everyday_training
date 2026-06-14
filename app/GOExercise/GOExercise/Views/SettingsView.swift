import SwiftUI
import UIKit

/// 設定ルート。「アカウントとバックアップ」を最上位に置き(機種変更時の命綱)、
/// 詳細設定・データ操作・情報は下層ページへ逃がして 1 画面に収める。
struct SettingsView: View {
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(ReferralStore.self) private var referralStore
    @Environment(RecordSyncCoordinator.self) private var recordSync
    /// 連携済み状態の表示文言(プロバイダ名があれば添える)。
    private var linkedStatusText: String {
        switch friendsStore.backupStatus.providerName {
        case "apple": return "Apple アカウントでバックアップ中"
        case "google": return "Google アカウントでバックアップ中"
        default: return "アカウントでバックアップ中"
        }
    }
    @State private var showPremiumPaywall = false
    @State private var isConfirmingDelete = false
    @State private var deleteErrorMessage: String?
    @State private var laterInviteCode = ""
    @State private var isSubmittingLater = false
    @State private var laterAccepted = false
    @State private var isShowingWidgetGuide = false
    var onClose: (() -> Void)? = nil

    var body: some View {
        List {
            // ① アカウントとバックアップ(最上位。機種変更/再インストールの命綱)
            Section {
                Toggle(isOn: Binding(
                    get: { recordSync.isEnabled },
                    set: { on in
                        if on { Task { await recordSync.enableBackup() } } else { recordSync.disableBackup() }
                    }
                )) {
                    Label("記録をクラウドにバックアップ", systemImage: "icloud.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("record-backup-toggle")
                if recordSync.isEnabled {
                    HStack {
                        Label("今すぐバックアップ", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        if recordSync.isSyncing { ProgressView() }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { Task { await recordSync.syncNow() } }
                    if let err = recordSync.lastError {
                        Text(err).font(Typography.caption).foregroundStyle(.red)
                    }
                }

                // 機種変更で確実に復元するための「鍵」= Apple/Google サインイン。
                if SupabaseConfig.isAccountLinkingEnabled {
                    if friendsStore.backupStatus.isBackedUp {
                        Label(linkedStatusText, systemImage: "checkmark.seal.fill")
                            .font(Typography.body)
                            .foregroundStyle(Palette.success)
                        // サインアウトは廃止: 友達は常時オンの標準機能で、認証は backup/restore
                        // のための「鍵」に過ぎない。匿名のサインアウトは全データ消去(忘れる)になり
                        // 干渉する footgun だったため除去。アカウント切替は新端末でのサインイン
                        // (= 復元) が担い、真っさらにしたい場合は下の「アカウントを削除」を使う。
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple / Google でサインインすると、機種変更や再インストールでも確実に復元できます(メール・パスワード不要)。")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textSecondary)
                            AccountBackupSignIn()
                        }
                    }
                    // アカウント削除 (審査 Guideline 5.1.1(v))。アカウント作成(連携)を提供する
                    // 場合に必須のアプリ内削除導線。サインイン済み(匿名含む)のとき常時到達可能にする。
                    if friendsStore.profile != nil {
                        Button(role: .destructive) {
                            isConfirmingDelete = true
                        } label: {
                            Label("アカウントを削除", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .disabled(friendsStore.isDeletingAccount)
                        .accessibilityIdentifier("settings-delete-account")
                        // 削除失敗(通信障害等)のフィードバック。旧 FriendsView の errorBanner が
                        // 担っていた表示を移設先でも担保し、「失敗→再試行」契約を保つ。
                        if let deleteErrorMessage {
                            Text(deleteErrorMessage)
                                .font(Typography.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                Text("アカウントとバックアップ")
            } footer: {
                Text("運動・体重・体調の記録をあなたのアカウントに保存し、機種変更(iPhone↔Android)や再インストールで復元できます。友達には共有されません。")
            }

            // ② プレミアム & 特典
            Section {
                // 友達/SNS にアプリを共有する導線。
                // ユーザーが「アプリを薦めたい」と思った瞬間に迷わない場所。
                ShareLink(
                    item: AppSharingConfig.shareURL,
                    subject: Text(AppSharingConfig.shareSubject),
                    message: Text(AppSharingConfig.shareMessage)
                ) {
                    Label("アプリを友達にシェア", systemImage: "square.and.arrow.up")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("settings-share-app")

                if storeKit.isPremiumActive {
                    Label {
                        Text("GOプレミアム 加入中")
                            .foregroundStyle(Palette.textPrimary)
                    } icon: {
                        Image(systemName: "crown.fill").foregroundStyle(Palette.primary)
                    }
                    .accessibilityIdentifier("premium-active-row")
                } else {
                    Button {
                        showPremiumPaywall = true
                    } label: {
                        HStack {
                            Label("GOプレミアムにアップグレード", systemImage: "crown.fill")
                                .foregroundStyle(Palette.textPrimary)
                            Spacer()
                            if storeKit.isEligibleForIntroOffer {
                                Text("14日間無料")
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.primary)
                            }
                        }
                    }
                    .accessibilityIdentifier("premium-upsell-row")
                }

                // 特典の内訳と称号の進化段はまとめて下層ページへ(ルートを短く保つ)。
                NavigationLink {
                    PerksAndTitlesPage()
                } label: {
                    Label("プレミアム特典・称号一覧", systemImage: "rosette")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("perks-titles-link")

                if AppFeatureFlags.isReferralActive {
                    // 共有(招待する)= friend_code + 文面を共有シートへ。
                    if let code = friendsStore.profile?.friendCode {
                        ShareLink(item: inviteMessage(code: code)) {
                            Label("友達を招待する", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("referral-invite-share")
                    }
                    // 星バッジ(累計紹介)。
                    HStack {
                        Label("紹介した友達", systemImage: "star.fill")
                        Spacer()
                        Text("\(referralStore.currentAccountStarBadges) 人")
                            .foregroundStyle(Palette.textSecondary)
                    }
                    // 後から入力(登録7日以内 & 紹介者未登録のときだけ)。
                    if referralStore.canEnterCodeLater {
                        if laterAccepted {
                            Label("招待コードを適用しました!", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(Palette.primaryDeep)
                        } else {
                            InviteCodeField(code: $laterInviteCode, isSubmitting: isSubmittingLater) {
                                submitLaterInvite()
                            }
                            if let err = referralStore.lastError {
                                Text(err).font(Typography.caption).foregroundStyle(.red)
                            }
                        }
                    }
                }
            } header: {
                Text("プレミアム & 特典")
            }

            // ③ アプリ設定(詳細は下層ページへ)
            Section("アプリ設定") {
                NavigationLink {
                    CustomizationSettingsPage()
                } label: {
                    Label("カスタマイズ", systemImage: "paintpalette.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("customization-link")
                NavigationLink {
                    RecordSharingSettingsPage()
                } label: {
                    Label("記録と共有", systemImage: "heart.text.square.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("record-sharing-link")
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("通知設定", systemImage: "bell.badge.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                Button {
                    isShowingWidgetGuide = true
                } label: {
                    Label("ウィジェットの追加方法を見る", systemImage: "rectangle.stack.badge.plus")
                        .foregroundStyle(Palette.primaryDeep)
                }
                .accessibilityIdentifier("widget-guide-button")
            }

            // ④ データ & 情報(破壊的操作・規約類は下層ページへ)
            Section {
                NavigationLink {
                    DataPrivacySettingsPage()
                } label: {
                    Label("データ & プライバシー", systemImage: "lock.shield.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("data-privacy-link")
                NavigationLink {
                    InfoSupportSettingsPage()
                } label: {
                    Label("情報・サポート", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("info-support-link")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .task {
            // 「アカウントとバックアップ」の連携済み表示を最新化(Apple/Google サインイン状態)。
            if SupabaseConfig.isAccountLinkingEnabled {
                await friendsStore.refreshBackupStatus()
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(onClose != nil)
        .toolbar {
            // Phase 7.0: Tab 直下の root では「ホームへ戻る」が空振りするため、
            // deep link 経由 (onClose 渡された場合) でのみ toolbar item を出す。
            if let onClose {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Label("ホーム", systemImage: "chevron.left")
                            .labelStyle(.titleAndIcon)
                            .font(Typography.body)
                    }
                    .accessibilityLabel("ホームへ戻る")
                }
            }
        }
        .sheet(isPresented: $isShowingWidgetGuide) {
            WidgetSetupGuideSheet(isPresented: $isShowingWidgetGuide)
        }
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumPaywallSheet(store: storeKit, context: .general)
        }
        // アカウント削除 (審査 5.1.1(v))。連携済みも含め本人データを完全消去する。
        .alert(
            "アカウントを削除しますか？",
            isPresented: $isConfirmingDelete
        ) {
            Button("アカウントを削除", role: .destructive) {
                // 成功すると profile==nil になり、この行は「サインイン」表示へ戻る。
                // 失敗時は deleteAccount() が false を返す → 下に再試行を促すエラーを表示する
                // (deleteAccount は冪等なので再実行で完了できる)。
                Task {
                    deleteErrorMessage = nil
                    let ok = await friendsStore.deleteAccount()
                    if !ok {
                        deleteErrorMessage = friendsStore.lastError
                            ?? "アカウントの削除に失敗しました。通信状況を確認してもう一度お試しください。"
                    }
                }
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("友達・コード・応援などすべてのデータが完全に削除され、元に戻せません。バックアップ済みでも復元できなくなります。")
        }
    }

    private func inviteMessage(code: String) -> String {
        "GOエクササイズで一緒に運動しよう!オンボーディングでこの招待コードを入れると、お互いに保険チケットがもらえます → \(code)\nhttps://apps.apple.com/jp/app/id6774551663"
    }

    private func submitLaterInvite() {
        isSubmittingLater = true
        referralStore.lastError = nil
        Task {
            await friendsStore.ensureSignedIn()
            let ok = await referralStore.submitCode(laterInviteCode)
            isSubmittingLater = false
            if ok { laterAccepted = true }
            // 確定(confirmed)は新規の初運動記録が条件。ここでは pending を作るだけにし、
            // 実際の確定は Home の syncMyFriendProfile フックが
            // achievedDays>=1 を満たした時点で行う(幽霊インストール確定を防ぐ)。
        }
    }
}

// MARK: - 下層: プレミアム特典・称号一覧

private struct PerksAndTitlesPage: View {
    var body: some View {
        List {
            Section("プレミアム特典") {
                PerkGuideSection()
            }
            Section("称号一覧（連続で進化）") {
                CatRankGuideView(currentStreak: SharedSnapshotStore().read().currentStreak)
                    .accessibilityIdentifier("rank-guide-disclosure")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("特典・称号")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 下層: カスタマイズ(テーマ・キャラ・振動)

private struct CustomizationSettingsPage: View {
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(ReferralStore.self) private var referralStore
    @State private var celebrationPrefs = CelebrationPreferences.shared
    @State private var isShowingUserCatPicker = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    Label("テーマカラー", systemImage: "paintpalette.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("theme-link")
                Button {
                    isShowingUserCatPicker = true
                } label: {
                    HStack {
                        Label("自分のキャラを変更", systemImage: "cat.fill")
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Text(UserCatPreferences.shared.myCat.displayName)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .accessibilityIdentifier("user-cat-link")
                Toggle(isOn: Binding(
                    get: { celebrationPrefs.hapticEnabled },
                    set: { celebrationPrefs.hapticEnabled = $0 }
                )) {
                    Label("達成時の振動", systemImage: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("haptic-toggle")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("カスタマイズ")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isShowingUserCatPicker) {
            // sheet は親の .environment(_:) を取りこぼすことがある (SwiftUI の癖)。
            // UserCatPickerView は storeKit / friendsStore / referralStore を環境から
            // 読むため、ここで明示的に渡し直す (オンボの fullScreenCover と同じ対処)。
            UserCatPickerView()
                .environment(storeKit)
                .environment(friendsStore)
                .environment(referralStore)
        }
    }
}

// MARK: - 下層: 記録と共有(周期・休養ルール・友達への共有範囲)

private struct RecordSharingSettingsPage: View {
    @State private var cycleEnabled: Bool = CycleTrackingSettings().isEnabled
    @State private var sharingPrefs = FriendSharingPreferences.shared
    private let cycleSettings = CycleTrackingSettings()

    private var cycleEnabledBinding: Binding<Bool> {
        Binding(
            get: { cycleEnabled },
            set: { newValue in
                cycleEnabled = newValue
                cycleSettings.isEnabled = newValue
            }
        )
    }

    var body: some View {
        List {
            Section {
                Toggle("体調・周期を記録する", isOn: cycleEnabledBinding)
                    .accessibilityIdentifier("cycle-tracking-toggle")
            } footer: {
                Text("ON にすると記録画面に「今日は生理日」スイッチが出て、履歴に ★ で表示されます。")
            }

            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletRow("月曜〜日曜の同じ週で、達成できなかった日のうち最大 2 日を自動的に「休」と記録します。")
                        bulletRow("3 日目以降の未達成日は × になり、その時点で連続記録がリセットされます。")
                        bulletRow("既に休が割り当てられた日は履歴カレンダーで「休」と表示されます。")
                        bulletRow("運動不可な日が増えそうな週は、保険チケット (無料は月1回 / GOプレミアムは月4回) で別途救済できます。")
                    }
                    .padding(.top, 4)
                } label: {
                    Label("週 2 日まで休んでも連続記録は続きます", systemImage: "moon.zzz.fill")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                }
            }

            // 友達と共有する情報の設定は友達機能が有効なときだけ出す (v1 では非表示)。
            if AppFeatureFlags.friendsEnabled {
                Section {
                    Toggle(isOn: Binding(
                        get: { sharingPrefs.includeExerciseDetail },
                        set: { sharingPrefs.includeExerciseDetail = $0 }
                    )) {
                        Label("回数・時間・セット数も共有", systemImage: "person.2.badge.gearshape.fill")
                            .foregroundStyle(Palette.textPrimary)
                    }
                    .accessibilityIdentifier("sharing-detail-toggle")
                    Label("体重・体調は共有されません", systemImage: "lock.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.success)
                } header: {
                    Text("友達への共有")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("記録と共有")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 下層: データ & プライバシー(書き出し・全削除・分析)

private struct DataPrivacySettingsPage: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingDeleteConfirm = false
    @State private var exportShareURL: URL?
    @State private var dataActionMessage: String?
    /// 匿名分析の共有 (既定 ON / opt-out)。UserDefaults "analyticsEnabled" = Analytics.isEnabled と同一キー。
    @AppStorage(Analytics.analyticsEnabledKey) private var analyticsEnabled = true

    var body: some View {
        List {
            Section {
                Button {
                    exportData()
                } label: {
                    Label("データを書き出す", systemImage: "square.and.arrow.up.on.square")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("data-export-button")
                Button(role: .destructive) {
                    isShowingDeleteConfirm = true
                } label: {
                    Label("すべての記録を削除", systemImage: "trash.fill")
                        .foregroundStyle(.red)
                }
                .accessibilityIdentifier("data-delete-button")
            } footer: {
                Text("書き出しは運動・体重・体調の記録を JSON ファイルにまとめます。削除は記録のみが対象で、購入やサブスクリプションには影響しません。")
            }

            Section {
                Toggle(isOn: $analyticsEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("利用状況の分析を共有")
                            .foregroundStyle(Palette.textPrimary)
                        Text("アプリ改善のための匿名データ(個人を特定しません)。OFF にすると一切送信しません。")
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .accessibilityIdentifier("analytics-opt-out-toggle")
                .onChange(of: analyticsEnabled) { _, newValue in
                    // OFF で SDK 実体を即 Noop に戻す(セッション中の残留送信を止める)。ON で再有効化。
                    Analytics.setEnabled(newValue)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("データ & プライバシー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { exportShareURL != nil },
            set: { newValue in
                // 共有シートを閉じたら、個人データを含む一時ファイルを削除する
                // (Codex 指摘: 放置すると temp に機微データが溜まる)。
                if !newValue, let url = exportShareURL {
                    try? FileManager.default.removeItem(at: url)
                    exportShareURL = nil
                }
            }
        )) {
            if let url = exportShareURL {
                ShareSheet(items: [url])
            }
        }
        .alert(
            "すべての記録を削除しますか？",
            isPresented: $isShowingDeleteConfirm
        ) {
            Button("削除する", role: .destructive) { deleteAllData() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("運動・体重・体調の記録がすべて削除され、元に戻せません。先に「データを書き出す」でバックアップできます。")
        }
        .alert(
            "完了",
            isPresented: Binding(
                get: { dataActionMessage != nil },
                set: { if !$0 { dataActionMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataActionMessage ?? "")
        }
    }

    private func exportData() {
        // 前回の一時ファイルが残っていれば置き換え前に削除する。
        if let previous = exportShareURL {
            try? FileManager.default.removeItem(at: previous)
        }
        do {
            let url = try DataManagementService(context: modelContext).writeExportFile()
            Analytics.track(.dataExported)
            exportShareURL = url
        } catch {
            dataActionMessage = "データの書き出しに失敗しました。"
        }
    }

    private func deleteAllData() {
        do {
            let count = try DataManagementService(context: modelContext).deleteAllRecords()
            // 保険チケットの「使用履歴」も消す (購入済み残数は paid entitlement なので
            // 残す)。これが無いと削除後も古い救済日が連続記録判定に残る (Codex 指摘)。
            RescueTicketStore.shared.clear()
            NotificationCenter.default.post(name: .goDataDidReset, object: nil)
            // App Group のウィジェットスナップショットと Live Activity も即リフレッシュ。
            // これが無いと全削除後もウィジェット/ロック画面が古い連続日数・週進捗を
            // 表示し続ける (3 LLM 監査 / Codex 指摘。QA チェックリスト N: 各ストア即リフレッシュ)。
            WidgetSnapshotPublisher.publish(from: WorkoutStore(context: modelContext))
            CatLiveActivityController.shared.stopAll()
            Analytics.track(.dataDeleted)
            dataActionMessage = "\(count) 件の記録を削除しました。"
        } catch {
            dataActionMessage = "削除に失敗しました。"
        }
    }
}

// MARK: - 下層: 情報・サポート

private struct InfoSupportSettingsPage: View {
    @Environment(\.openURL) private var openURL
    @State private var dataActionMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    openSupportForm()
                } label: {
                    Label("ご意見・ご要望を送る", systemImage: "bubble.left.and.bubble.right.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("feedback-button")
                Button {
                    openSupportForm()
                } label: {
                    Label("不具合を報告する", systemImage: "ladybug.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("bug-report-button")
            }
            Section {
                LabeledContent("アプリ", value: "GO エクササイズ")
                LabeledContent("バージョン", value: appVersion)
                Button {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                } label: {
                    Label("サブスクリプションを管理", systemImage: "creditcard.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("manage-subscription-link")
                Link(destination: URL(string: "https://torontojapan.github.io/everyday_training/privacy")!) {
                    Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("privacy-policy-link")
                Link(destination: URL(string: "https://torontojapan.github.io/everyday_training/terms")!) {
                    Label("利用規約", systemImage: "doc.text.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("terms-link")
                Link(destination: URL(string: "https://torontojapan.github.io/everyday_training/support")!) {
                    Label("サポート", systemImage: "questionmark.circle.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("support-link")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("情報・サポート")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "お知らせ",
            isPresented: Binding(
                get: { dataActionMessage != nil },
                set: { if !$0 { dataActionMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(dataActionMessage ?? "")
        }
    }

    private func openSupportForm() {
        openURL(FeedbackComposer.supportFormURL) { accepted in
            if !accepted {
                dataActionMessage = "お問い合わせフォームを開けませんでした。時間をおいて再度お試しください。"
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
}

/// 書き出したデータファイルを共有するための UIActivityViewController ラッパー。
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct WidgetSetupGuideSheet: View {
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Spacer().frame(height: 56)

                    Text("ウィジェットを追加する")
                        .font(Typography.title)
                        .foregroundStyle(Palette.textPrimary)

                    stepRow(number: 1, title: "ホーム画面の空いている場所を長押し", detail: "アイコンが小刻みに揺れたら編集モードです。")
                    stepRow(number: 2, title: "左上の「+」をタップ", detail: "ウィジェット ギャラリーが開きます。")
                    stepRow(number: 3, title: "検索欄に「GO」と入力", detail: "GO エクササイズのウィジェットが見つかります。")
                    stepRow(number: 4, title: "Small または Medium を選択", detail: "下にスワイプしてサイズを選んでください。")
                    stepRow(number: 5, title: "「ウィジェットを追加」をタップ", detail: "ホーム画面に貼り付けます。位置はあとから自由に動かせます。")

                    Text("ウィジェットに表示される内容")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.top, 12)

                    bullet("今日の残り時間（深夜0時まで）")
                    bullet("週間達成率と進捗リング")
                    bullet("猫キャラのひとことメッセージ")
                    bullet("タップでアプリを即起動")

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }

            HStack {
                Spacer()
                Button {
                    isPresented = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Palette.textPrimary.opacity(0.75), in: Circle())
                }
                .accessibilityLabel("閉じる")
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
        }
    }

    private func stepRow(number: Int, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Palette.primary, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Palette.success)
            Text(text)
                .font(Typography.body)
                .foregroundStyle(Palette.textPrimary)
        }
    }
}
