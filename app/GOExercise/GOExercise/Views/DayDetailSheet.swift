import SwiftUI

struct DayDetailSheet: View {
    let date: Date
    let records: [WorkoutRecord]
    let status: DailyStatus
    @Environment(\.dismiss) private var dismiss
    private let calendar = Calendar.mondayFirst

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.background.ignoresSafeArea()
                if records.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(records) { record in
                                HistoryRowView(record: record)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var title: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: date)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(iconColor)
                .frame(width: 92, height: 92)
                .background(iconColor.opacity(0.12), in: Circle())
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var iconName: String {
        switch status {
        case .rest: return "moon.zzz.fill"
        case .future: return "calendar"
        case .missed, .todayPending: return "pawprint.fill"
        case .achieved, .todayAchieved: return "checkmark.seal.fill"
        case .rescued: return "snowflake"
        }
    }

    private var iconColor: Color {
        switch status {
        case .rest, .future: return Palette.textSecondary
        case .missed, .todayPending: return Palette.primary
        case .achieved, .todayAchieved, .rescued: return Palette.primary
        }
    }

    private var message: String {
        switch status {
        case .rest: return "この日は回復日。\n無理しないのも大事だよ"
        case .future: return "これからの日だね"
        case .missed: return "この日は記録がないよ"
        case .todayPending: return "今日はまだ記録がないよ"
        case .achieved, .todayAchieved: return "記録がここに表示されます"
        case .rescued: return "この日は保険チケットで連続記録を継続したよ"
        }
    }
}
