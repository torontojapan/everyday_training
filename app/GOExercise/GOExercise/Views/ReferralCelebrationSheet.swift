import SwiftUI

/// 友達紹介の確定ポップ。新規(される側=ウェルカム)と紹介者(する側=参加通知)を
/// 同一レイアウトで出し分ける。複数の紹介者ポップは1枚にまとめて列挙する。
struct ReferralCelebrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let confirmations: [ReferralConfirmation]

    private var isWelcome: Bool { confirmations.first?.role == .referee }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Palette.primaryDeep.opacity(0.45),
                                                  Palette.primaryDeep.opacity(0.12)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 132, height: 132)
                Image(systemName: isWelcome ? "sparkles" : "star.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Palette.primaryDeep)
            }
            Text(isWelcome ? "友達とつながりました!" : "友達が参加しました!")
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                // タイトル幅に収まらず「…」省略されるのを防ぐ。2行まで折返し+わずかに縮小し、
                // 端末幅や Dynamic Type の拡大でも全文表示する。
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                if isWelcome {
                    Text("\(confirmations.first?.friendDisplayName ?? "ともだち") さんの招待で参加")
                        .font(Typography.body).foregroundStyle(Palette.textSecondary)
                    rewardRow(icon: "snowflake", text: "ウェルカム・保険チケット +1(今月)")
                } else {
                    ForEach(confirmations) { c in
                        Text("\(c.friendDisplayName) さんが参加!")
                            .font(Typography.body).foregroundStyle(Palette.textSecondary)
                    }
                    rewardRow(icon: "snowflake", text: "保険チケット +1(今月・上限5)")
                    rewardRow(icon: "star.fill", text: "星バッジ +\(confirmations.count)")
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Button {
                dismiss()
            } label: {
                Text("やったね!")
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Palette.primaryDeep, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            .accessibilityIdentifier("referral-celebration-dismiss")
        }
        .padding(.top, 24)
        .background(Palette.background)
        .presentationDetents([.medium])
    }

    private func rewardRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Palette.primaryDeep)
            Text(text).font(Typography.body).foregroundStyle(Palette.textPrimary)
        }
    }
}
