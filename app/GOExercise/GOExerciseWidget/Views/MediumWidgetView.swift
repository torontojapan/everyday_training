import SwiftUI
import WidgetKit

struct MediumWidgetView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(spacing: 6) {
                WidgetCatView(rawState: snapshot.catState, size: 74)
                Text(catState.displayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.54, green: 0.47, blue: 0.39))
            }
            .frame(width: 84)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 5) {
                    Text("🔥\(snapshot.currentStreak)")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.30))
                    Text("今週 \(snapshot.weeklyAchieved)/\(snapshot.weeklyTotal)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(red: 0.30, green: 0.25, blue: 0.20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Text(headlineMessage)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(headlineColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack {
                    Text(remainingText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(red: 0.54, green: 0.47, blue: 0.39))
                    Spacer()
                    // Phase 7.0 Step 3: 1-tap 記録ボタン (Medium ウィジェット内)
                    QuickRecordButtonView(snapshot: snapshot)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// 未達成時は行動喚起「1分だけでも運動しよう」を前面に (ユーザー要望)。
    /// 達成・回復日は状態に合わせたメッセージを出す。
    private var headlineMessage: String {
        if snapshot.todayAchieved { return "今日も達成！えらい ✨" }
        if snapshot.isRestDay { return "今日はむりせず整えよう" }
        return "1分だけでも運動しよう"
    }

    private var headlineColor: Color {
        if snapshot.todayAchieved { return Color(red: 0.20, green: 0.55, blue: 0.28) }
        return Color(red: 0.95, green: 0.42, blue: 0.30)
    }

    private var catState: CatState {
        CatState(rawValue: snapshot.catState) ?? .waitingMorning
    }

    private var remainingText: String {
        if snapshot.todayAchieved {
            return "今日は達成済み"
        }
        if snapshot.isRestDay {
            return "今日は整える日"
        }
        return "23:59まであと\(snapshot.nightDeadlineHoursLeft)時間"
    }
}
