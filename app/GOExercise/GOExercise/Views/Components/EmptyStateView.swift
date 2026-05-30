import SwiftUI

struct EmptyStateView: View {
    /// 空状態を表す SF Symbol 名。絵文字よりリッチでテーマ色に馴染む。
    let symbol: String
    let message: String

    init(symbol: String = "pawprint.fill", message: String) {
        self.symbol = symbol
        self.message = message
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Palette.primary)
                .frame(width: 86, height: 86)
                .background(Palette.primary.opacity(0.12), in: Circle())

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
