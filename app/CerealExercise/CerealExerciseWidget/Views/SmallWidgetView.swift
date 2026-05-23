import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                WidgetCatView(rawState: snapshot.catState)
                Spacer(minLength: 0)
                progressRing
            }

            Text(remainingText)
                .font(.headline)
                .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.14), in: Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var remainingText: String {
        if snapshot.todayAchieved {
            return "達成済み！"
        }
        if snapshot.isRestDay {
            return "回復日"
        }
        return "あと\(snapshot.nightDeadlineHoursLeft)時間"
    }

    private var statusText: String {
        snapshot.todayAchieved ? "今日もえらい！" : "今日の達成まだ"
    }

    private var statusColor: Color {
        snapshot.todayAchieved ? Color(red: 0.32, green: 0.58, blue: 0.34) : Color(red: 0.84, green: 0.33, blue: 0.30)
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.96, green: 0.85, blue: 0.74), lineWidth: 5)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color(red: 1.00, green: 0.62, blue: 0.55),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Text("\(snapshot.weeklyAchieved)/\(max(snapshot.weeklyTotal, 1))")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
                .minimumScaleFactor(0.7)
        }
        .frame(width: 46, height: 46)
        .accessibilityLabel("今週の達成数")
        .accessibilityValue("\(snapshot.weeklyAchieved)日中\(max(snapshot.weeklyTotal, 1))日")
    }

    private var progress: Double {
        guard snapshot.weeklyTotal > 0 else { return 0 }
        return min(1, max(0, Double(snapshot.weeklyAchieved) / Double(snapshot.weeklyTotal)))
    }
}
