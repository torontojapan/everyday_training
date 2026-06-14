import SwiftUI

struct StreakBadgeView: View {
    let streak: Int
    /// true のとき縦に伸びて隣の列(称号+状態の2行)と高さを揃える。
    var fillHeight: Bool = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 10) {
                // ブランド一貫性のため Live Activity / 称号バッジと同じ肉球マークに統一(旧 🔥)。
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
                Text("\(streak)日連続")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                if streak > 0 {
                    // タップでシェアできることを視覚的に明示。
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(Palette.textSecondary)
                        .accessibilityHidden(true)
                }
            }
            .foregroundStyle(Palette.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxHeight: fillHeight ? .infinity : nil)
            .background(Palette.secondary.opacity(0.8), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityHint(streak > 0 ? "タップで連続記録を共有" : "連続記録はまだありません")
        .disabled(streak <= 0)
    }
}
