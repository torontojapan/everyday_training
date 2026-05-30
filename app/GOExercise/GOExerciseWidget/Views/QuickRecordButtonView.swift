import SwiftUI
import WidgetKit

/// Phase 7.0 Step 3: ウィジェット内で 1 タップ記録するボタン。
/// iOS 17+ の Button(intent:) で AppIntent をその場で実行できる。
struct QuickRecordButtonView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.todayAchieved {
            // 達成済みは目立たない状態カードに
            statusChip(icon: "checkmark.seal.fill", text: "今日達成",
                       tint: .green, background: .green.opacity(0.18))
        } else if snapshot.isRestDay {
            statusChip(icon: "moon.zzz.fill", text: "回復日",
                       tint: .secondary, background: Color.gray.opacity(0.18))
        } else {
            // 未達成: タップで AppIntent を実行 → 即時 reload。
            // 運動「前」に過去形だと不自然なため、中立的な「運動を記録」に。
            Button(intent: QuickRecordIntent()) {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("運動を記録")
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14).padding(.vertical, 8)
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
                .shadow(color: Color(red: 0.99, green: 0.45, blue: 0.42).opacity(0.35),
                        radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日の運動を記録する")
        }
    }

    private func statusChip(icon: String, text: String, tint: Color, background: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(background, in: Capsule())
    }
}
