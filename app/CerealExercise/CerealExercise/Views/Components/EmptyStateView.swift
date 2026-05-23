import SwiftUI

struct EmptyStateView: View {
    let emoji: String
    let message: String

    init(emoji: String = "🐱", message: String) {
        self.emoji = emoji
        self.message = message
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 52))
                .frame(width: 86, height: 86)
                .background(Palette.surface, in: Circle())

            Text(message)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Palette.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
