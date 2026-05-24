import SwiftUI

/// Combines the rescue ticket status and the cat decoration tier into a single
/// visually richer card that replaces two text-heavy rows.
struct RewardCard: View {
    let decoration: CatDecoration
    let ticketAvailable: Bool
    var onUseTicket: (() -> Void)? = nil
    var showUseTicketButton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                decorationBadge
                VStack(alignment: .leading, spacing: 4) {
                    Text("ごほうび")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text("装飾: \(decoration.displayName)")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(decoration.unlockHint)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            Divider().opacity(0.5)

            HStack(spacing: 12) {
                ticketIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text("保険チケット")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Text(ticketAvailable ? "今月 1枚 残り" : "今月 0枚 (使用済み)")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("忙しい日を 1日だけ救えます")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if ticketAvailable, showUseTicketButton {
                    Button("今日に使う") {
                        onUseTicket?()
                    }
                    .font(Typography.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Palette.primary, in: Capsule())
                    .foregroundStyle(.white)
                    .accessibilityIdentifier("rescue-use-button")
                }
            }
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Palette.surface, decoration.accentColor.opacity(0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(decoration.accentColor.opacity(0.25), lineWidth: 1)
        )
    }

    private var decorationBadge: some View {
        ZStack {
            Circle()
                .fill(decoration.accentColor.opacity(0.25))
                .frame(width: 56, height: 56)
            if decoration.symbolName.isEmpty {
                Text("🐱").font(.system(size: 26))
            } else {
                Image(systemName: decoration.symbolName)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(decoration.accentColor)
            }
        }
    }

    private var ticketIcon: some View {
        Image(systemName: ticketAvailable ? "ticket.fill" : "ticket")
            .font(.system(size: 28))
            .foregroundStyle(ticketAvailable ? Palette.primary : Palette.textSecondary.opacity(0.5))
            .frame(width: 44, height: 44)
            .background(
                Circle().fill(ticketAvailable ? Palette.primary.opacity(0.15) : Palette.chipBackground.opacity(0.5))
            )
    }
}
