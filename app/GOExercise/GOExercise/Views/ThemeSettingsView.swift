import SwiftUI

struct ThemeSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    themeRow(theme)
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("テーマカラー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func themeRow(_ theme: AppTheme) -> some View {
        let isSelected = themeStore.theme == theme
        return Button {
            themeStore.theme = theme
        } label: {
            HStack(spacing: 14) {
                preview(theme)
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text(theme.hint)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(theme.primaryDeep)
                        .font(.system(size: 22))
                }
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? theme.primary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme-\(theme.rawValue)")
        .accessibilityLabel("\(theme.displayName) \(isSelected ? "選択中" : "未選択")")
    }

    private func preview(_ theme: AppTheme) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(theme.background)
            Rectangle().fill(theme.primary)
            Rectangle().fill(theme.primaryDeep)
            Rectangle().fill(theme.secondary)
            Rectangle().fill(theme.success)
        }
        .frame(width: 80, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.black.opacity(0.08), lineWidth: 1)
        )
    }
}
