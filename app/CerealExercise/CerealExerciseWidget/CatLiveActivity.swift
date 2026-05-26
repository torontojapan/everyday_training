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
                        Text("🔥")
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
                    HStack(spacing: 8) {
                        Text(context.state.todayAchieved
                             ? "今日も達成 ✨ お疲れさま"
                             : "今日もちょこっとやろ？")
                            .font(.system(.subheadline, design: .rounded))
                        Spacer()
                        if !context.state.todayAchieved {
                            Button(intent: QuickRecordIntent()) {
                                Text("やった！")
                                    .font(.system(.caption, design: .rounded, weight: .heavy))
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 1.00, green: 0.62, blue: 0.55))
                            .controlSize(.small)
                        }
                    }
                }
            } compactLeading: {
                catCompactIcon(breedRaw: context.state.catBreedRaw)
            } compactTrailing: {
                if context.state.todayAchieved {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("🔥\(context.state.currentStreak)")
                        .font(.caption.weight(.heavy))
                        .monospacedDigit()
                }
            } minimal: {
                Text(context.state.todayAchieved ? "✓" : "🐱")
            }
            .widgetURL(URL(string: "cerealexercise://home"))
        }
    }

    /// Compact leading は文字 ~1 字分しか入らないので猫絵文字でシンプルに。
    private func catCompactIcon(breedRaw: String) -> some View {
        Text("🐱")
            .font(.system(size: 16))
    }
}

/// Lock Screen の banner 風 layout。アプリの世界観 (オレンジ + 黒) を踏襲。
struct CatLockScreenView: View {
    let state: CatActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.00, green: 0.85, blue: 0.55).opacity(0.30))
                    .frame(width: 48, height: 48)
                Text(catEmoji)
                    .font(.system(size: 32))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("🔥")
                    Text("\(state.currentStreak) 日連続")
                        .font(.system(.subheadline, design: .rounded, weight: .heavy))
                        .monospacedDigit()
                }
                Text(state.todayAchieved
                     ? "今日も達成 ✨"
                     : "残り \(state.hoursLeftToday) 時間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !state.todayAchieved {
                Button(intent: QuickRecordIntent()) {
                    Text("やった！")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Color(red: 1.00, green: 0.62, blue: 0.55),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var catEmoji: String {
        switch CatState(rawValue: state.catStateRaw) ?? .waitingMorning {
        case .celebrating: return "😸"
        case .streakExtended: return "😻"
        case .resting: return "😽"
        case .worriedNoon: return "😿"
        case .beggingNight: return "🙀"
        default: return "🐱"
        }
    }
}
