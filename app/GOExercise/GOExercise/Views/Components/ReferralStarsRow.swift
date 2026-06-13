import SwiftUI

/// ホーム上部の紹介スター行。`referralStore.summary.starBadges` を
/// `ReferralStarsDisplay` で出し分け、タップで招待を共有する。
struct ReferralStarsRow: View {
    let count: Int
    let friendCode: String

    /// 金の星は「ご褒美」感を出すため、テーマ依存の Palette.primary ではなく
    /// 常に暖色のゴールド (.orange) を使う。
    private let starGold = Color.orange

    private var inviteText: String {
        "GOエクササイズで一緒に運動しよう!オンボーディングでこの招待コードを入れると、お互いに保険チケットがもらえます → \(friendCode)\nhttps://apps.apple.com/jp/app/id6774551663"
    }

    var body: some View {
        ShareLink(item: inviteText) {
            // 星(上)とキャプション(下)を縦積み。横に並べるとキャプションが
            // 横幅を奪い最大10星が折り返すため、星は単独行で全幅を使う。
            VStack(alignment: .leading, spacing: 3) {
                content
                if case let .progress(filled, total) = ReferralStarsDisplay.style(count: count), filled < total {
                    Text("あと\(total - filled)人で猫が解放")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("紹介スター \(count)。タップで友達を招待")
        .accessibilityIdentifier("home-referral-stars")
    }

    @ViewBuilder
    private var content: some View {
        switch ReferralStarsDisplay.style(count: count) {
        case .ghost:
            star(filled: false)
        case let .progress(filled, total):
            FlowStars(filledCount: filled, totalCount: total, gold: starGold)
        case .complete:
            FlowStars(filledCount: 10, totalCount: 10, gold: starGold)
        case let .collapsed(n):
            HStack(spacing: 4) {
                star(filled: true)
                Text("\(n)").font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
            }
        }
    }

    private func star(filled: Bool) -> some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(filled ? starGold : Palette.textSecondary.opacity(0.3))
    }
}

/// 星を横に並べ、幅に入らなければ折り返す(金 filled + 枠 total-filled)。
private struct FlowStars: View {
    let filledCount: Int
    let totalCount: Int
    let gold: Color
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 22), spacing: 4)], alignment: .leading, spacing: 4) {
            ForEach(0..<max(totalCount, filledCount), id: \.self) { i in
                Image(systemName: i < filledCount ? "star.fill" : "star")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(i < filledCount ? gold : Palette.textSecondary.opacity(0.3))
            }
        }
    }
}
