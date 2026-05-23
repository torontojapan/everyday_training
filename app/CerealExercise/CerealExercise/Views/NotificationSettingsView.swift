import SwiftUI

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        Form {
            Section("通知") {
                Toggle("通知ON/OFF", isOn: enabledBinding)

                Picker("通知回数", selection: countBinding) {
                    Text("OFF").tag(0)
                    Text("1日1回").tag(1)
                    Text("1日2回").tag(2)
                }
                .pickerStyle(.segmented)
            }

            Section("通知時間") {
                DatePicker("通知時間1", selection: firstTimeBinding, displayedComponents: .hourAndMinute)

                if viewModel.notificationCount > 1 {
                    DatePicker("通知時間2", selection: secondTimeBinding, displayedComponents: .hourAndMinute)
                }
            }

            Section {
                Text("通知トーンは初期設定のまま使用します。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("通知設定")
        .navigationBarTitleDisplayMode(.inline)
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
