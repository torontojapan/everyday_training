import SwiftUI

/// 友達 + 自分の今週達成日数で並ぶランキング画面。
/// 上位 3 位はメダル装飾、自分の位置はハイライト。
struct WeeklyRankingView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss

    private var entries: [WeeklyRankingEntry] {
        // 自分が weeklyAchievements を持っていない (Mock 状態) ことを想定し、
        // myProfile に空配列を補ったコピーを渡す。
        var me = friendsStore.profile
        if me?.weeklyAchievements == nil {
            me?.weeklyAchievements = Array(repeating: false, count: 7)
        }
        return WeeklyRankingCalculator.rank(friends: friendsStore.friends, myProfile: me)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerCard

                if entries.isEmpty {
                    EmptyStateView(message: "ランキングを表示するには、友達を追加してください。")
                } else {
                    VStack(spacing: 10) {
                        ForEach(entries) { entry in
                            rankRow(entry)
                        }
                    }
                }

                Text("月曜日にリセットされ、今週の達成日数 (休養日含む) で順位が決まります。")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("週間ランキング")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        // テーマトークン Palette.settingsAccent (金色系) を使用。
        // 以前は Color(red: 0.9, ...) のハードコードだったので、ダーク
        // テーマ等で見え方が浮く可能性があった。
        let trophyColor = Palette.settingsAccent
        return HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(trophyColor)
                .frame(width: 64, height: 64)
                .background(trophyColor.opacity(0.18), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text("今週のがんばり")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Text("友達 + あなたで競い合おう")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rankRow(_ entry: WeeklyRankingEntry) -> some View {
        HStack(spacing: 14) {
            rankBadge(entry.rank)

            ZStack {
                Circle()
                    .fill(tierColor(entry.profile.decorationTier).opacity(0.25))
                    .frame(width: 44, height: 44)
                Text("🐱")
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.profile.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    if entry.isMe {
                        Text("あなた")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Palette.primary, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                Text("🔥 \(entry.profile.currentStreak) 日連続")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.weeklyAchievedCount)")
                    .font(.system(.title2, design: .rounded, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(Palette.primaryDeep)
                Text("/ 7 日")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(entry.isMe ? Palette.primary.opacity(0.10) : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(entry.isMe ? Palette.primary : .clear, lineWidth: 2)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
    }

    private func accessibilityLabel(for entry: WeeklyRankingEntry) -> String {
        let suffix = entry.isMe ? " あなた" : ""
        return "\(entry.rank) 位、\(entry.profile.displayName)、今週 \(entry.weeklyAchievedCount) 日達成\(suffix)"
    }

    private func rankBadge(_ rank: Int) -> some View {
        let (emoji, bg): (String, Color) = {
            switch rank {
            case 1: return ("🥇", Color(red: 1.00, green: 0.84, blue: 0.30).opacity(0.25))
            case 2: return ("🥈", Color(red: 0.75, green: 0.75, blue: 0.78).opacity(0.30))
            case 3: return ("🥉", Color(red: 0.80, green: 0.55, blue: 0.30).opacity(0.30))
            default: return ("\(rank)", Palette.chipBackground)
            }
        }()
        return Text(emoji)
            .font(rank <= 3 ? .system(size: 22) : .system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(rank <= 3 ? .primary : Palette.textPrimary)
            .frame(width: 36, height: 36)
            .background(bg, in: Circle())
            .accessibilityLabel("\(rank) 位")
    }

    private func tierColor(_ tier: Int) -> Color {
        switch tier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return Palette.textSecondary
        }
    }
}
