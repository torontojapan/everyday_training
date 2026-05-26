import SwiftUI

/// 友達 + 自分の頑張りを順位化する画面。週間/月間のセグメントで切替。
struct WeeklyRankingView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var period: RankingPeriod = .weekly

    private var entries: [WeeklyRankingEntry] {
        var me = friendsStore.profile
        if me?.weeklyAchievements == nil {
            me?.weeklyAchievements = Array(repeating: false, count: 7)
        }
        return WeeklyRankingCalculator.rank(friends: friendsStore.friends,
                                             myProfile: me,
                                             period: period)
    }

    private var myEntry: WeeklyRankingEntry? { entries.first(where: { $0.isMe }) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                periodPicker
                rulesCard
                if let me = myEntry {
                    mySummaryCard(me)
                }

                if entries.isEmpty {
                    EmptyStateView(message: "ランキングを表示するには、友達を追加してください。")
                } else {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            rankRow(entry)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("ランキング")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 週間 / 月間 切替セグメント。
    private var periodPicker: some View {
        Picker("期間", selection: $period) {
            ForEach(RankingPeriod.allCases) { p in
                Text(p.label).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("ranking-period-picker")
    }

    // MARK: - Rules header

    /// 順位ルールを「最初に」見せる。下に置くと、ユーザーは「何で並んで
    /// るんだろう?」と混乱したまま表を読むことになる。
    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(period.rulesTitle, systemImage: "trophy.fill")
                .font(Typography.headline)
                .foregroundStyle(Palette.settingsAccent)
            HStack(alignment: .top, spacing: 8) {
                rankPriorityPill(number: 1, label: "連続日数が長い", color: Palette.primary)
                rankPriorityPill(number: 2, label: "運動時間が長い", color: Palette.settingsAccent)
            }
            Text(period.resetHint)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func rankPriorityPill(number: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(color, in: Circle())
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textPrimary)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(color.opacity(0.10), in: Capsule())
    }

    // MARK: - My summary

    /// 「あなたは今 何位 / 全 N 人中」をでかく見せるサマリーカード。
    /// 順位リストの長文を読まなくても自分の立ち位置が一発で分かる。
    private func mySummaryCard(_ me: WeeklyRankingEntry) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Palette.primary.opacity(0.18))
                    .frame(width: 64, height: 64)
                VStack(spacing: 0) {
                    Text("\(me.rank)")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.primaryDeep)
                        .monospacedDigit()
                    Text("位")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.primaryDeep)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("あなたは \(me.rank) 位 / 全 \(entries.count) 人中")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                HStack(spacing: 12) {
                    Label("\(me.profile.currentStreak) 日連続", systemImage: "flame.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.primaryDeep)
                    Label("\(me.totalMinutes) 分", systemImage: "clock.fill")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Palette.primary.opacity(0.18), Palette.primary.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Palette.primary.opacity(0.4), lineWidth: 1.5)
        )
    }

    // MARK: - Rank list

    private func rankRow(_ entry: WeeklyRankingEntry) -> some View {
        HStack(spacing: 12) {
            rankBadge(entry.rank)
            FriendAvatarView(friend: entry.profile, size: 44)
            VStack(alignment: .leading, spacing: 4) {
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
                // ★ 順位の根拠を毎行に表示。連続日数と運動時間が
                //   一目で比較でき、「なぜこの順位か」が読み取れる。
                HStack(spacing: 10) {
                    Label("\(entry.profile.currentStreak)", systemImage: "flame.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.primaryDeep)
                        .monospacedDigit()
                    Label("\(entry.totalMinutes)分", systemImage: "clock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textSecondary)
                        .monospacedDigit()
                }
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(entry.isMe ? Palette.primary.opacity(0.08) : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(entry.isMe ? Palette.primary : .clear, lineWidth: 2)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: entry))
    }

    private func accessibilityLabel(for entry: WeeklyRankingEntry) -> String {
        let me = entry.isMe ? "あなた、" : ""
        return "\(me)\(entry.rank) 位、\(entry.profile.displayName)、" +
               "連続 \(entry.profile.currentStreak) 日、\(period.label) \(entry.totalMinutes) 分"
    }

    private func rankBadge(_ rank: Int) -> some View {
        let (emoji, label, bg): (String?, String?, Color) = {
            switch rank {
            case 1: return ("🥇", nil, Color(red: 1.00, green: 0.84, blue: 0.30).opacity(0.30))
            case 2: return ("🥈", nil, Color(red: 0.75, green: 0.75, blue: 0.78).opacity(0.32))
            case 3: return ("🥉", nil, Color(red: 0.80, green: 0.55, blue: 0.30).opacity(0.32))
            default: return (nil, "\(rank)", Palette.chipBackground)
            }
        }()
        return ZStack {
            Circle()
                .fill(bg)
                .frame(width: 40, height: 40)
            if let emoji {
                Text(emoji).font(.system(size: 22))
            } else if let label {
                Text(label)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                    .monospacedDigit()
            }
        }
        .accessibilityLabel("\(rank) 位")
    }
}
