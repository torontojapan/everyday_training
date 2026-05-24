import SwiftUI

struct LifetimeStatsCard: View {
    let achievedDays: Int
    let usedDays: Int

    private var ratePercent: Int {
        guard usedDays > 0 else { return 0 }
        return Int((Double(achievedDays) / Double(usedDays) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.checkmark")
                    .foregroundStyle(Palette.primaryDeep)
                Text("これまでの記録")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
            }

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(achievedDays)")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.primary)
                Text("/")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Text("\(usedDays) 日")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textSecondary)
                Spacer()
                Text("\(ratePercent)%")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.primary, in: Capsule())
            }

            Text("アプリ利用開始からの累計運動日数です。連続記録が途切れてもここはずっと積み上がります。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("これまでの累計 \(achievedDays) 日達成 / \(usedDays) 日利用、達成率 \(ratePercent)%")
    }
}
