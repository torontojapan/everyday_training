import SwiftUI
import WidgetKit

/// 未達成の日に出す記録誘導チップ。
/// ウィジェットからの直接記録は提供しない(ユーザー要望)。チップ自体は装飾で、
/// タップはウィジェット全体の `widgetURL(goexercise://home)` に落ちてホームタブが開く。
struct RecordPromptChipView: View {
    let snapshot: WidgetSnapshot

    var body: some View {
        if snapshot.todayAchieved || snapshot.isRestDay {
            // 達成/回復日は見出しテキストが状態を語るため、同義のステータスチップは
            // 出さない(「今日達成」が画面に何度も並ぶ重複表示のユーザー指摘)。
            EmptyView()
        } else {
            // 未達成: アプリで記録する誘導チップ(タップ = widgetURL → ホームタブ)。
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
            .accessibilityLabel("アプリを開いて今日の運動を記録する")
        }
    }
}
