import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 肉球マーク + 今週の達成度(X/7) + 月〜日の達成ストリップ(キャラ廃止)。
            WidgetWeekStrip(
                statuses: snapshot.weeklyStatuses,
                weeklyAchieved: snapshot.weeklyAchieved,
                weeklyTotal: snapshot.weeklyTotal,
                compact: true
            )

            Text(headlineText)
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .foregroundStyle(headlineColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            // CTA チップは未達成時のみ(達成/回復日は見出しが語るため重複チップを出さない)。
            RecordPromptChipView(snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 未達成時は「1分だけでも」を主役にして行動を促す (ユーザー要望)。
    private var headlineText: String {
        if snapshot.todayAchieved { return "達成済み！" }
        if snapshot.isRestDay { return "回復日" }
        return "1分だけでも"
    }

    private var headlineColor: Color {
        if snapshot.todayAchieved { return Color(red: 0.20, green: 0.55, blue: 0.28) }
        return Color(red: 0.95, green: 0.42, blue: 0.30)
    }
}
