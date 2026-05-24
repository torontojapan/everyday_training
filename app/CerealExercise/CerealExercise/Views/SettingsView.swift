import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingWidgetGuide = false
    var onClose: (() -> Void)? = nil

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

            Section("アプリ情報") {
                LabeledContent("アプリ", value: "GOエクササイズ")
                LabeledContent("バージョン", value: appVersion)
                Text("利用規約・プライバシーポリシーは今後の提出準備で追加します。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
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
