import ActivityKit
import SwiftUI
import UIKit
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
                             : "1分だけでも運動しよう")
                            .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        Spacer()
                        if !context.state.todayAchieved {
                            Button(intent: QuickRecordIntent()) {
                                Text("運動した！")
                                    .font(.system(.caption, design: .rounded, weight: .heavy))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(red: 1.00, green: 0.55, blue: 0.42))
                            .controlSize(.small)
                        }
                    }
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
                    Text("🔥\(context.state.currentStreak)")
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
            .widgetURL(URL(string: "cerealexercise://home"))
        }
    }
}

/// ロック画面 / 拡張表示用の、ブランドのオレンジ猫画像 (状態別)。
/// アセット欠落時は肉球記号にフォールバックして空白描画を防ぐ (Codex 指摘)。
struct LiveActivityCatImage: View {
    let stateRaw: String
    var size: CGFloat = 34

    var body: some View {
        Group {
            if UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "pawprint.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(red: 1.00, green: 0.55, blue: 0.30))
                    .padding(size * 0.15)
            }
        }
        .frame(width: size, height: size)
    }

    private var assetName: String {
        "cat_orange_\(CatState(rawValue: stateRaw)?.rawValue ?? CatState.waitingMorning.rawValue)"
    }
}

/// Lock Screen の banner 風 layout。アプリの世界観 (オレンジ + 黒) を踏襲。
struct CatLockScreenView: View {
    let state: CatActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.00, green: 0.86, blue: 0.60).opacity(0.85),
                                Color(red: 1.00, green: 0.85, blue: 0.55).opacity(0.25),
                            ],
                            center: .center, startRadius: 2, endRadius: 28
                        )
                    )
                    .frame(width: 50, height: 50)
                LiveActivityCatImage(stateRaw: state.catStateRaw, size: 38)
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
                     : "1分だけでも・残り \(state.hoursLeftToday) 時間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !state.todayAchieved {
                Button(intent: QuickRecordIntent()) {
                    Text("運動した！")
                        .font(.system(.caption, design: .rounded, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.00, green: 0.58, blue: 0.38),
                                    Color(red: 0.99, green: 0.45, blue: 0.42),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            ),
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
}
