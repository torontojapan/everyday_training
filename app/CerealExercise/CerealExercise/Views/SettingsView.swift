import SwiftUI

struct SettingsView: View {
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

            Section("アプリ情報") {
                LabeledContent("アプリ", value: "シリアルエクササイズ")
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
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0"
    }
}
