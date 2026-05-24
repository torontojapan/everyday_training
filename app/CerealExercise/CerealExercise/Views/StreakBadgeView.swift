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
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Palette.secondary.opacity(0.8), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint(streak > 0 ? "タップで連続記録を共有" : "連続記録はまだありません")
    }
}
