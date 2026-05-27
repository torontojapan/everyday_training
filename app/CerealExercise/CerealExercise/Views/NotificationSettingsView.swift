import SwiftUI
import UIKit

struct NotificationSettingsView: View {
    @Environment(\.openURL) private var openURL
    @State private var viewModel = NotificationSettingsViewModel()
    @State private var personality: NotificationPersonality = NotificationPersonalityPreferences.shared.current

    var body: some View {
        Form {
            if viewModel.shouldShowPermissionWarning {
                Section {
                    permissionWarningBanner
                }
                .listRowBackground(Color.clear)
            }

            Section("通知") {
                Toggle("通知ON/OFF", isOn: enabledBinding)
                    .accessibilityIdentifier("notif-toggle")

                Picker("通知回数", selection: countBinding) {
                    Text("OFF").tag(0)
                    Text("1日1回").tag(1)
                    Text("1日2回").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section("通知時間") {
                timePickerRow(title: "通知時間1", selection: firstTimeBinding)

                if viewModel.notificationCount > 1 {
                    timePickerRow(title: "通知時間2", selection: secondTimeBinding)
                }
            }

            Section {
                Picker("性格", selection: personalityBinding) {
                    ForEach(NotificationPersonality.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .accessibilityIdentifier("notif-personality-picker")
                Text(personality.hint)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("通知の性格")
            } footer: {
                Text("静かに待つ: 通知最小限。ひとこと呼ぶ: 朝夕の標準。友達が動いた時だけ: 友達 push 中心 (push 基盤完成後に有効)。")
                    .font(Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.refreshAuthorizationStatus()
        }
    }

    private var permissionWarningBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("通知が許可されていません", systemImage: "exclamationmark.triangle.fill")
                .font(Typography.headline)
                .foregroundStyle(Palette.primaryDeep)

            Text("リマインドを受け取るには、iOSの設定で通知を許可してください。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)

            Button {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            } label: {
                Label("設定アプリを開く", systemImage: "gearshape.fill")
                    .font(Typography.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func timePickerRow(title: String, selection: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            DatePicker(title, selection: selection, displayedComponents: .hourAndMinute)
                .datePickerStyle(.compact)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
        }
    }

    private var personalityBinding: Binding<NotificationPersonality> {
        Binding(
            get: { personality },
            set: { newValue in
                personality = newValue
                NotificationPersonalityPreferences.shared.current = newValue
                // 性格を変えたら即座に reschedule。Codex round1 priority 1。
                Task { await viewModel.rescheduleForCurrentSettings() }
            }
        )
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isEnabled },
            set: { newValue in
                Task { await viewModel.setEnabled(newValue) }
            }
        )
    }

    private var countBinding: Binding<Int> {
        Binding(
            get: { viewModel.notificationCount },
            set: { newValue in
                Task { await viewModel.setNotificationCount(newValue) }
            }
        )
    }

    private var firstTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.firstTime },
            set: { newValue in
                Task { await viewModel.setFirstTime(newValue) }
            }
        )
    }

    private var secondTimeBinding: Binding<Date> {
        Binding(
            get: { viewModel.secondTime },
            set: { newValue in
                Task { await viewModel.setSecondTime(newValue) }
            }
        )
    }
}
