import SwiftUI

/// 連続が途切れた直後(4日グレース)に出す復活ポップ。穏やかなトーン。
struct StreakRevivePopup: View {
    let potentialStreak: Int     // 復活後に戻る連続日数
    let freezesNeeded: Int
    let remaining: Int
    let hasEnough: Bool
    let onUseFreeze: () -> Void   // 残枠十分: フリーズ適用
    let onSeePremium: () -> Void  // 残枠不足: paywall
    let onDismiss: () -> Void     // 今回はしない

    var body: some View {
        VStack(spacing: 18) {
            Capsule().fill(Color.secondary.opacity(0.3)).frame(width: 36, height: 5).padding(.top, 8)
            Image(systemName: "snowflake")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Color(red: 0.40, green: 0.70, blue: 0.95))
                .accessibilityHidden(true)
            Text("連続\(potentialStreak)日を守れます")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
            Text(hasEnough
                 ? "フリーズを使うと、お休みした日が埋まって連続記録が続きます(残り\(remaining)回)。"
                 : "連続を守るにはフリーズが\(freezesNeeded)回必要です(残り\(remaining)回)。GOプレミアムなら毎月4回使えます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if hasEnough {
                Button(action: onUseFreeze) {
                    Text("フリーズを使う(\(freezesNeeded)回)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: onSeePremium) {
                    Text("GOプレミアムでフリーズを増やす")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("今回はしない", action: onDismiss)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}
