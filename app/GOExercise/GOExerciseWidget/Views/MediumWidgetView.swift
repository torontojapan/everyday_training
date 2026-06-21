import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 肉球マーク + 今週の達成度(X/7) + 月〜日の達成ストリップ(キャラ廃止)。
            WidgetWeekStrip(
                statuses: snapshot.weeklyStatuses,
                weeklyAchieved: snapshot.weeklyAchieved,
                weeklyTotal: snapshot.weeklyTotal,
                compact: false
            )

            HStack(spacing: 10) {
                if snapshot.currentStreak > 0 {
                    Label("\(snapshot.currentStreak)日連続", systemImage: "flame.fill")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.30))
                        .lineLimit(1)
                }
                Text(headlineMessage)
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                // CTA チップは未達成時のみ(達成/回復日は見出しが語るため重複させない)。
                RecordPromptChipView(snapshot: snapshot)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 未達成時は行動喚起「1分だけでも運動しよう」を前面に (ユーザー要望)。
    /// 達成・回復日は状態に合わせたメッセージを出す。
    private var headlineMessage: String {
        if snapshot.todayAchieved { return "今日も達成！えらい" }
        if snapshot.isRestDay { return "今日はむりせず整えよう" }
        return "1分だけでも運動しよう"
    }

    private var headlineColor: Color {
        if snapshot.todayAchieved { return Color(red: 0.20, green: 0.55, blue: 0.28) }
        return Color(red: 0.95, green: 0.42, blue: 0.30)
    }
}
