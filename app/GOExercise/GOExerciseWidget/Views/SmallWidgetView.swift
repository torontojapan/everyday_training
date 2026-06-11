import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WidgetCatView(rawState: snapshot.catState, size: 60)
                Spacer(minLength: 0)
                progressRing
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(headlineText)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(headlineColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(subText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color(red: 0.54, green: 0.47, blue: 0.39))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            // CTA チップは未達成時のみ(達成/回復日は見出しが語るため重複チップを出さない)。
            QuickRecordButtonView(snapshot: snapshot)
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

    /// 見出し(達成済み！/回復日/1分だけでも)と同義の繰り返しはせず、
    /// 次への一言/残り時間を出す(ユーザー指摘の重複解消)。
    private var subText: String {
        if snapshot.todayAchieved { return "また明日も続けよう" }
        if snapshot.isRestDay { return "むりせず整えよう" }
        return "23:59まであと\(snapshot.nightDeadlineHoursLeft)時間"
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
        .accessibilityValue("\(max(snapshot.weeklyTotal, 1))日中\(snapshot.weeklyAchieved)日")
    }

    private var progress: Double {
        guard snapshot.weeklyTotal > 0 else { return 0 }
        return min(1, max(0, Double(snapshot.weeklyAchieved) / Double(snapshot.weeklyTotal)))
    }
}
