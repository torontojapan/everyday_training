import SwiftUI
import WidgetKit

/// Phase 7.0 Step 3: ウィジェット内で 1 タップ記録するボタン。
/// iOS 17+ の Button(intent:) で AppIntent をその場で実行できる。
struct QuickRecordButtonView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.todayAchieved {
            // 達成済みは目立たない状態カードに
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("今日達成")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.green.opacity(0.18), in: Capsule())
        } else if snapshot.isRestDay {
            HStack(spacing: 6) {
                Image(systemName: "moon.zzz.fill")
                    .foregroundStyle(.secondary)
                Text("回復日")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color.gray.opacity(0.18), in: Capsule())
        } else {
            // 未達成: タップで AppIntent を実行 → 即時 reload。
            Button(intent: QuickRecordIntent()) {
                Label("1分やった！", systemImage: "plus.circle.fill")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(
                        Color(red: 1.00, green: 0.62, blue: 0.55),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日の運動を 1 タップで記録")
        }
    }
}
