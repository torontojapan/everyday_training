import SwiftUI

/// 保険チケットの状態を表示するカード。
/// (旧: CatDecoration チップとセットだったが、cat progression は
///  キャラアートに bake-in されたため装飾チップを退役し、
///  チケット情報のみのシンプルな reward card として再整備。)
struct RewardCard: View {
    let ticketAvailable: Bool
    var onUseTicket: (() -> Void)? = nil
    var showUseTicketButton: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                colors: [Palette.surface, Palette.primary.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.15), lineWidth: 1)
        )
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
