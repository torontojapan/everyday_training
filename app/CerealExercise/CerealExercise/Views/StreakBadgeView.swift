import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                Text("🔥")
                Text("\(streak)日連続")
                    .font(Typography.headline)
                if streak > 0 {
                    // タップでシェアできることを視覚的に明示。
                    // 静的に見える chip にアフォーダンスを足す。
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.secondary.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityHint(streak > 0 ? "タップで連続記録を共有" : "連続記録はまだありません")
        .disabled(streak <= 0)
    }
}
