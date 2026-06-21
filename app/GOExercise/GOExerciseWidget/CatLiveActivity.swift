import ActivityKit
import SwiftUI
import WidgetKit

/// 朝〜夜の間、ロック画面 + Dynamic Island に猫が常駐する Live Activity。
/// 「アプリを開かなくてもいつもそばにいる」体験を作る。
struct CatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CatActivityAttributes.self) { context in
            // Lock Screen / Banner 表示
            CatLockScreenView(state: context.state)
                .activityBackgroundTint(Color(red: 1.00, green: 0.97, blue: 0.93))
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "pawprint.fill")
                            .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.30))
                        Text("\(context.state.currentStreak)")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .monospacedDigit()
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.todayAchieved {
                        Label("達成済", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("あと\(context.state.hoursLeftToday)時間")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    // 肉球 + 今週の達成度(X/7)+ 月〜日ストリップ。
                    WidgetWeekStrip(
                        statuses: context.state.weeklyStatusesRaw.compactMap { DailyStatus(rawValue: $0) },
                        weeklyAchieved: context.state.weeklyAchieved,
                        weeklyTotal: context.state.weeklyTotal,
                        compact: true
                    )
                }
            } compactLeading: {
                // 極小スロットは画像より記号が綺麗・確実なので肉球マークで統一。
                Image(systemName: "pawprint.fill")
                    .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.30))
            } compactTrailing: {
                if context.state.todayAchieved {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    // compactLeading に肉球があるので trailing は数字のみ(🔥は出さない)。
                    Text("\(context.state.currentStreak)")
                        .font(.caption.weight(.heavy))
                        .monospacedDigit()
                }
            } minimal: {
                if context.state.todayAchieved {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.30))
                }
            }
            .widgetURL(URL(string: "goexercise://home"))
        }
    }
}

/// Lock Screen の banner。キャラ廃止 → 肉球マーク + 今週の達成度(X/7)+ 月〜日ストリップ。
struct CatLockScreenView: View {
    let state: CatActivityAttributes.ContentState

    private var weekStatuses: [DailyStatus] {
        state.weeklyStatusesRaw.compactMap { DailyStatus(rawValue: $0) }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                if state.currentStreak > 0 {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.42, blue: 0.30))
                    Text("\(state.currentStreak) 日連続")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color(red: 0.20, green: 0.13, blue: 0.08))
                }
                Spacer()
                if state.todayAchieved {
                    Label("今日も達成", systemImage: "checkmark.seal.fill")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.green)
                } else {
                    // タップでホームを開いて記録(Live Activity からの直接記録は提供しない)。
                    Link(destination: URL(string: "goexercise://home")!) {
                        Text("運動を記録")
                            .font(.system(.caption, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.00, green: 0.58, blue: 0.38),
                                             Color(red: 0.99, green: 0.45, blue: 0.42)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: Capsule()
                            )
                    }
                }
            }
            WidgetWeekStrip(
                statuses: weekStatuses,
                weeklyAchieved: state.weeklyAchieved,
                weeklyTotal: state.weeklyTotal,
                compact: true
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
