import SwiftUI

/// Duolingo 風リーグ。自分のリーグ + 友達 (＋自分) を月間達成日数で並べる。
/// 月末になると上位は昇格、下位は降格。
struct LeagueView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var leagueStore = LeagueStore.shared
    @State private var celebratingOutcome: LeagueOutcome?

    private var entries: [MonthlyRankingEntry] {
        MonthlyRankingCalculator.rank(friends: friendsStore.friends, myProfile: friendsStore.profile)
    }

    private var daysUntilMonthEnd: Int {
        let calendar = Calendar.mondayFirst
        let today = Date()
        guard let monthRange = calendar.range(of: .day, in: .month, for: today) else { return 0 }
        let day = calendar.component(.day, from: today)
        return max(0, monthRange.count - day)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                leagueHeroCard

                Text("\(daysUntilMonthEnd) 日後にリーグ判定")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)

                if entries.isEmpty {
                    EmptyStateView(message: "リーグに参加するには、友達を追加してください。")
                } else {
                    rankList
                }

                rulesCard
            }
            .padding(20)
        }
        .background(Palette.background)
        .navigationTitle("リーグ")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .center) {
            if let outcome = celebratingOutcome {
                LeaguePromotionToast(outcome: outcome) {
                    celebratingOutcome = nil
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: celebratingOutcome)
    }

    // MARK: - Hero

    private var leagueHeroCard: some View {
        let league = leagueStore.currentLeague
        return HStack(spacing: 16) {
            Text(league.emoji)
                .font(.system(size: 56))
                .frame(width: 88, height: 88)
                .background(league.color.opacity(0.22), in: Circle())
                .overlay(Circle().strokeBorder(league.color, lineWidth: 2))
            VStack(alignment: .leading, spacing: 6) {
                Text("\(league.displayName) リーグ")
                    .font(Typography.title)
                    .foregroundStyle(Palette.textPrimary)
                Text(progressTier)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
        }
        .padding(18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(league.color.opacity(0.4), lineWidth: 2)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(league.displayName) リーグ")
    }

    private var progressTier: String {
        let league = leagueStore.currentLeague
        switch league {
        case .bronze: return "上位 2 名で シルバー昇格"
        case .silver: return "上位 2 名で ゴールド昇格、下位 1 名で ブロンズ降格"
        case .gold: return "上位 2 名で プラチナ昇格、下位 1 名で シルバー降格"
        case .platinum: return "上位 2 名で ダイヤモンド昇格、下位 1 名で ゴールド降格"
        case .diamond: return "最上位 ✨ 維持を目指そう"
        }
    }

    // MARK: - Rank list

    private var rankList: some View {
        VStack(spacing: 10) {
            ForEach(entries) { entry in
                rankRow(entry)
            }
        }
    }

    private func rankRow(_ entry: MonthlyRankingEntry) -> some View {
        let zone = promotionZone(for: entry.rank, cohort: entries.count)
        return HStack(spacing: 12) {
            rankBadge(entry.rank, zone: zone)
            ZStack {
                Circle()
                    .fill(Palette.chipBackground.opacity(0.7))
                    .frame(width: 40, height: 40)
                Text("🐱")
                    .font(.system(size: 20))
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
                Text("🔥 \(entry.profile.currentStreak)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(entry.monthlyAchievedDays)")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.primaryDeep)
                Text("日 / 月")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(entry.isMe ? Palette.primary.opacity(0.10) : Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(entry.isMe ? Palette.primary : .clear, lineWidth: 2)
                )
        )
    }

    private enum Zone { case promote, demote, neutral }

    private func promotionZone(for rank: Int, cohort: Int) -> Zone {
        if rank <= League.promotionCount { return .promote }
        if cohort >= 2, rank > cohort - League.relegationCount { return .demote }
        return .neutral
    }

    private func rankBadge(_ rank: Int, zone: Zone) -> some View {
        let bg: Color = {
            switch zone {
            case .promote: return Color.green.opacity(0.20)
            case .demote:  return Color.red.opacity(0.15)
            case .neutral: return Palette.chipBackground
            }
        }()
        let fg: Color = {
            switch zone {
            case .promote: return .green
            case .demote:  return .red
            case .neutral: return Palette.textPrimary
            }
        }()
        return Text("\(rank)")
            .font(.system(.body, design: .rounded, weight: .heavy))
            .frame(width: 32, height: 32)
            .background(bg, in: Circle())
            .foregroundStyle(fg)
    }

    private var rulesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("リーグのしくみ", systemImage: "info.circle.fill")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            bullet("月内の達成日数で順位が決まります。")
            bullet("上位 \(League.promotionCount) 名は翌月に 1 段昇格。")
            bullet("下位 \(League.relegationCount) 名は翌月に 1 段降格 (ブロンズはそれ以下に下がりません)。")
            bullet("ダイヤモンドの上はありません。維持を目指しましょう ✨")
        }
        .padding(14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundStyle(Palette.textSecondary)
            Text(text)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Promotion toast

struct LeaguePromotionToast: View {
    let outcome: LeagueOutcome
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text(emoji)
                .font(.system(size: 72))
            Text(headline)
                .font(Typography.title)
                .foregroundStyle(.white)
            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.9))
            Button("OK") { onDismiss() }
                .font(Typography.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 28).padding(.vertical, 10)
                .background(.white.opacity(0.2), in: Capsule())
        }
        .padding(28)
        .background(
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .padding(40)
    }

    private var emoji: String {
        switch outcome {
        case .promoted(_, let to): return to.emoji
        case .demoted(_, let to):  return to.emoji
        case .held(let at):        return at.emoji
        }
    }

    private var headline: String {
        switch outcome {
        case .promoted(_, let to): return "\(to.displayName) に昇格 ✨"
        case .demoted(_, let to):  return "\(to.displayName) に降格"
        case .held(let at):        return "\(at.displayName) 維持 👍"
        }
    }

    private var subtitle: String {
        switch outcome {
        case .promoted: return "今月もよくがんばりました！"
        case .demoted:  return "来月、また上を目指そう！"
        case .held:     return "順位をキープできました。"
        }
    }

    private var gradientColors: [Color] {
        switch outcome {
        case .promoted(_, let to): return [to.color.opacity(0.95), to.color.opacity(0.7)]
        case .demoted(_, let to):  return [to.color.opacity(0.9), .gray.opacity(0.7)]
        case .held(let at):        return [at.color.opacity(0.9), at.color.opacity(0.6)]
        }
    }
}
