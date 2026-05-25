import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingWidgetGuide = false
    @State private var cycleEnabled: Bool = CycleTrackingSettings().isEnabled
    @State private var celebrationPrefs = CelebrationPreferences.shared
    @State private var sharingPrefs = FriendSharingPreferences.shared
    private let rescueTicketStore = RescueTicketStore()
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
            Section("通知") {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("通知設定", systemImage: "bell.badge.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
            }

            Section("外観") {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    Label("テーマカラー", systemImage: "paintpalette.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("theme-link")
            }

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
                Text("友達と共有する情報")
            } footer: {
                Text("OFF (デフォルト): 種目名のみ共有。ON: 回数・時間・セット数も友達の詳細画面に表示されます。")
            }

            Section {
                Toggle(isOn: Binding(
                    get: { celebrationPrefs.hapticEnabled },
                    set: { celebrationPrefs.hapticEnabled = $0 }
                )) {
                    Label("達成時の振動", systemImage: "iphone.radiowaves.left.and.right")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("haptic-toggle")
            } header: {
                Text("演出 (振動)")
            } footer: {
                Text("振動は CoreHaptics 対応機種でのみ動作します。")
            }

            Section {
                Toggle("体調・周期を記録する", isOn: cycleEnabledBinding)
                    .accessibilityIdentifier("cycle-tracking-toggle")
            } header: {
                Text("体調・周期")
            } footer: {
                Text("ONにすると、運動記録画面に体調メモの項目が出現し、履歴カレンダーに ★ マークで表示されます。")
            }

            Section("体重管理") {
                NavigationLink {
                    WeightView()
                } label: {
                    Label("体重を記録・グラフで見る", systemImage: "scalemass.fill")
                        .foregroundStyle(Palette.textPrimary)
                }
                .accessibilityIdentifier("weight-link")
            }

            Section("保険チケット") {
                rescueTicketRow
                NavigationLink {
                    RescueTicketUseView()
                } label: {
                    Label("使う日を選んで適用", systemImage: "calendar.badge.checkmark")
                        .foregroundStyle(Palette.primaryDeep)
                }
                .accessibilityIdentifier("rescue-use-link")
            }

            Section("ホーム画面ウィジェット") {
                widgetPromotionRow
                Button {
                    isShowingWidgetGuide = true
                } label: {
                    Label("追加方法を見る", systemImage: "info.circle.fill")
                        .foregroundStyle(Palette.primaryDeep)
                }
                .accessibilityIdentifier("widget-guide-button")
            }

            Section {
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletRow("月曜〜日曜の同じ週で、達成できなかった日のうち最大 2 日を自動的に「休」と記録します。")
                        bulletRow("3 日目以降の未達成日は × になり、その時点で連続記録がリセットされます。")
                        bulletRow("既に休が割り当てられた日は履歴カレンダーで「休」と表示されます。")
                        bulletRow("運動不可な日が増えそうな週は、保険チケット (月 1 枚、体調・周期 ON で 2 枚) で別途救済できます。")
                    }
                    .padding(.top, 4)
                } label: {
                    Label("週 2 日まで休んでも連続記録は続きます", systemImage: "moon.zzz.fill")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textPrimary)
                }
            } header: {
                Text("自動休養日")
            }

            Section("アプリ情報") {
                LabeledContent("アプリ", value: "GOエクササイズ")
                LabeledContent("バージョン", value: appVersion)
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
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                } label: {
                    Label("ホーム", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.body)
                }
                .accessibilityLabel("ホームへ戻る")
            }
        }
        .sheet(isPresented: $isShowingWidgetGuide) {
            WidgetSetupGuideSheet(isPresented: $isShowingWidgetGuide)
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

    private var rescueTicketRow: some View {
        let allowance = RescueTicketAllowance.current(cycleSettings: cycleSettings)
        let remaining = rescueTicketStore.remainingTickets(today: Date(), allowance: allowance)
        let available = remaining > 0
        return HStack(spacing: 12) {
            Image(systemName: available ? "ticket.fill" : "ticket")
                .font(.system(size: 22))
                .foregroundStyle(available ? Palette.primary : Palette.textSecondary.opacity(0.5))
            VStack(alignment: .leading, spacing: 4) {
                Text("今月 \(remaining) / \(allowance)枚 残り")
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Text(allowance > 1 ? "忙しい日に連続記録を守れます (体調・周期 ON で +1 枚)" : "忙しい日に1日だけ連続記録を守れます")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var widgetPromotionRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("ウィジェットでもっと続けやすく", systemImage: "rectangle.stack.badge.plus")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("ホーム画面に置くと、今日の残り時間 / 週間達成率 / 猫からのひとことが一目で見えます。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
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
                    stepRow(number: 3, title: "検索欄に「GO」と入力", detail: "GOエクササイズのウィジェットが見つかります。")
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
