import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(ReferralStore.self) private var referralStore
    @State private var showPremiumPaywall = false
    @State private var laterInviteCode = ""
    @State private var isSubmittingLater = false
    @State private var laterAccepted = false
    @State private var isShowingWidgetGuide = false
    @State private var cycleEnabled: Bool = CycleTrackingSettings().isEnabled
    @State private var celebrationPrefs = CelebrationPreferences.shared
    @State private var sharingPrefs = FriendSharingPreferences.shared
    @State private var isShowingUserCatPicker = false
    @State private var isShowingDeleteConfirm = false
    @State private var exportShareURL: URL?
    @State private var dataActionMessage: String?
    /// 匿名分析の共有 (既定 ON / opt-out)。UserDefaults "analyticsEnabled" = Analytics.isEnabled と同一キー。
    @AppStorage(Analytics.analyticsEnabledKey) private var analyticsEnabled = true
    private let cycleSettings = CycleTrackingSettings()
    var onClose: (() -> Void)? = nil

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
            // ① プレミアム & 特典
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

                PerkGuideSection()

                // 称号一覧(連続で進化)。目標が見えると続けたくなる導線。既定は閉。
                DisclosureGroup {
                    CatRankGuideView(currentStreak: SharedSnapshotStore().read().currentStreak)
                } label: {
                    Label("称号一覧（連続で進化）", systemImage: "rosette")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("rank-guide-disclosure")

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
            } footer: {
                Text("体重タブの全機能・連続記録フリーズ月4回などを解放します。")
            }

            // ② カスタマイズ
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
            } header: {
                Text("カスタマイズ")
            }

            // ③ 記録 & 共有
            Section {
                Toggle("体調・周期を記録する", isOn: cycleEnabledBinding)
                    .accessibilityIdentifier("cycle-tracking-toggle")
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletRow("月曜〜日曜の同じ週で、達成できなかった日のうち最大 2 日を自動的に「休」と記録します。")
                        bulletRow("3 日目以降の未達成日は × になり、その時点で連続記録がリセットされます。")
                        bulletRow("既に休が割り当てられた日は履歴カレンダーで「休」と表示されます。")
                        bulletRow("運動不可な日が増えそうな週は、連続記録フリーズ (無料は月1回 / GOプレミアムは月4回) で別途救済できます。")
                    }
                    .padding(.top, 4)
                } label: {
                    Label("週 2 日まで休んでも連続記録は続きます", systemImage: "moon.zzz.fill")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                }
                // 友達と共有する情報の設定は友達機能が有効なときだけ出す (v1 では非表示)。
                if AppFeatureFlags.friendsEnabled {
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
                }
            } header: {
                Text("記録 & 共有")
            } footer: {
                Text("ON にすると記録画面に「今日は生理日」スイッチが出て、履歴に ★ で表示されます。")
            }

            // ④ 通知 & ウィジェット
            Section("通知 & ウィジェット") {
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

            // ⑤ データ & プライバシー
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
            } header: {
                Text("データ & プライバシー")
            } footer: {
                Text("書き出しは運動・体重・体調の記録を JSON ファイルにまとめます。削除は記録のみが対象で、購入やサブスクリプションには影響しません。")
            }

            // ⑥ 情報・サポート(折りたたみ既定閉)
            Section {
                DisclosureGroup("情報・サポート") {
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
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
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
        .sheet(isPresented: $isShowingUserCatPicker) {
            // sheet は親の .environment(_:) を取りこぼすことがある (SwiftUI の癖)。
            // UserCatPickerView は storeKit / friendsStore / referralStore を環境から
            // 読むため、ここで明示的に渡し直す (オンボの fullScreenCover と同じ対処)。
            UserCatPickerView()
                .environment(storeKit)
                .environment(friendsStore)
                .environment(referralStore)
        }
        .sheet(isPresented: $showPremiumPaywall) {
            PremiumPaywallSheet(store: storeKit, context: .general)
        }
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

    private func inviteMessage(code: String) -> String {
        "GOエクササイズで一緒に運動しよう!オンボーディングでこの招待コードを入れると、お互いにフリーズがもらえます → \(code)\nhttps://apps.apple.com/jp/app/id6774551663"
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

    private func openSupportForm() {
        openURL(FeedbackComposer.supportFormURL) { accepted in
            if !accepted {
                dataActionMessage = "お問い合わせフォームを開けませんでした。時間をおいて再度お試しください。"
            }
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
