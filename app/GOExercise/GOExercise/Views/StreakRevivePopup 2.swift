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
                 ? "保険チケットを使うと、お休みした日が埋まって連続記録が続きます(残り\(remaining)回)。"
                 : "連続を守るには保険チケットが\(freezesNeeded)回必要です(残り\(remaining)回)。GOプレミアムなら毎月4回使えます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            if hasEnough {
                Button(action: onUseFreeze) {
                    Text("保険チケットを使う(\(freezesNeeded)回)")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.40, green: 0.70, blue: 0.95)) // フリーズ=氷のテーマに合わせた寒色
            } else {
                Button(action: onSeePremium) {
                    Text("プレミアムを見てみる") // 3LLM採点: コミット感を下げた穏やかな文言(節度)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.40, green: 0.70, blue: 0.95))
            }
            // 「やめる」も正当な選択として読めるよう、淡すぎない色+十分なタップ域にする。
            Button(action: onDismiss) {
                Text("今回はしない")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 24)
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}
