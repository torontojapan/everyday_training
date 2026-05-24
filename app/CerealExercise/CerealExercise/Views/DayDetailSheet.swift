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
            Text(emoji)
                .font(.system(size: 56))
            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private var emoji: String {
        switch status {
        case .rest: return "😴"
        case .future: return "🗓️"
        case .missed, .todayPending: return "🐱"
        case .achieved, .todayAchieved: return "🎉"
        }
    }

    private var message: String {
        switch status {
        case .rest: return "この日は回復日。\n無理しないのも大事だよ"
        case .future: return "これからの日だね"
        case .missed: return "この日は記録がないよ"
        case .todayPending: return "今日はまだ記録がないよ"
        case .achieved, .todayAchieved: return "記録がここに表示されます"
        }
    }
}
