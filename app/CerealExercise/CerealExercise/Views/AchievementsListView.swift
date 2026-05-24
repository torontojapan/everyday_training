import SwiftUI

struct AchievementsListView: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss
    var onClose: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                summary
                ForEach(achievements) { achievement in
                    row(for: achievement)
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("バッジ")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if let onClose { onClose() } else { dismiss() }
                } label: {
                    Label("戻る", systemImage: "chevron.left")
                        .labelStyle(.titleAndIcon)
                        .font(Typography.body)
                }
                .accessibilityLabel("戻る")
            }
        }
    }

    private var summary: some View {
        let unlocked = achievements.filter(\.isUnlocked).count
        return HStack(spacing: 8) {
            Image(systemName: "rosette")
                .foregroundStyle(Palette.primary)
            Text("\(unlocked) / \(achievements.count) バッジ獲得")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Spacer()
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func row(for achievement: Achievement) -> some View {
        HStack(spacing: 14) {
            Image(systemName: achievement.symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(achievement.isUnlocked ? Palette.primary : Palette.textSecondary.opacity(0.4))
                .frame(width: 44, height: 44)
                .background(achievement.isUnlocked ? Palette.primary.opacity(0.18) : Palette.chipBackground.opacity(0.5),
                            in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(Typography.headline)
                    .foregroundStyle(achievement.isUnlocked ? Palette.textPrimary : Palette.textSecondary)
                Text(achievement.description)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                if let label = achievement.progressLabel {
                    HStack(spacing: 8) {
                        ProgressView(value: achievement.progress)
                            .tint(achievement.isUnlocked ? Palette.success : Palette.primary)
                        Text(label)
                            .font(Typography.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
            }
            Spacer()
            if achievement.isUnlocked {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Palette.success)
            }
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .opacity(achievement.isUnlocked ? 1.0 : 0.85)
    }
}
