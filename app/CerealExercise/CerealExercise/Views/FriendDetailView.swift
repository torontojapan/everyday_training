import SwiftUI

/// 個別の友達の状態をじっくり確認できる詳細シート。
/// 装飾ランク / 今日のメニュー / 週カレンダー / 累計 / cheer を一画面に集約。
struct FriendDetailView: View {
    let friend: FriendProfile
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var sentCheer: CheerKind?
    @State private var sentCheerToken: UUID?
    @State private var cheerInFlight = false
    @State private var pendingRemoval = false
    @State private var isShowingAvatarPicker = false
    @State private var avatarPickerVersion = 0   // 選択後に View をリフレッシュ
    private let hapticFeedback: any HapticFeedbackProviding = HapticFeedback()
    private let calendar = Calendar.mondayFirst

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    heroHeader
                    todayCard
                    weeklySection
                    statsCard
                    cheerSection
                    Spacer(minLength: 24)
                    removeButton
                }
                .padding(20)
            }
            .background(Palette.background.ignoresSafeArea())
            .navigationTitle(friend.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .accessibilityIdentifier("friend-detail-close")
                }
            }
            .sheet(isPresented: $isShowingAvatarPicker, onDismiss: { avatarPickerVersion += 1 }) {
                BuddyCatPickerSheet(friendCode: friend.friendCode,
                                    friendDisplayName: friend.displayName)
            }
            .confirmationDialog(
                "\(friend.displayName) を友達から外しますか？",
                isPresented: $pendingRemoval,
                titleVisibility: .visible
            ) {
                Button("友達を解除", role: .destructive) {
                    Task {
                        await friendsStore.remove(friend)
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("再度つながるには友達コードで申請が必要です。")
            }
        }
    }

    // MARK: - Hero

    private var heroHeader: some View {
        let cat = FriendAvatarResolver.resolve(for: friend.friendCode)
        return VStack(spacing: 12) {
            Button {
                isShowingAvatarPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(LinearGradient(
                            colors: [cat.tintColor.opacity(0.50), cat.tintColor.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 132, height: 132)
                    Image(cat.assetName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.05)
                        .frame(width: 132, height: 132)
                        .clipShape(Circle())
                    CatDecorationOverlay(decoration: friend.decoration)
                }
                .overlay(alignment: .bottomTrailing) {
                    // 「タップで変更できる」アフォーダンス用の小さな鉛筆バッジ
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Palette.primaryDeep)
                        .background(Circle().fill(Palette.surface))
                        .offset(x: -2, y: -2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("アバターを変更 (現在: \(cat.displayName))")
            .accessibilityIdentifier("change-buddy-avatar")
            .id(avatarPickerVersion)

            Text(friend.displayName)
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)

            HStack(spacing: 8) {
                Text("@\(friend.username)")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
                Text("·")
                    .foregroundStyle(Palette.textSecondary)
                Text(friend.friendCode)
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
            }

            if friend.decoration != .none {
                HStack(spacing: 6) {
                    Text(friend.decoration.emoji)
                    Text(friend.decoration.displayName)
                }
                .font(Typography.caption)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(tierColor.opacity(0.18), in: Capsule())
                .foregroundStyle(tierColor)
            }

            Text(lastUpdatedText)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Today

    private var todayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("今日の運動")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                if friend.todayAchieved {
                    Label("達成", systemImage: "checkmark.seal.fill")
                        .font(Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.success.opacity(0.18), in: Capsule())
                        .foregroundStyle(Palette.success)
                } else {
                    Label("未達成", systemImage: "hourglass")
                        .font(Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.chipBackground, in: Capsule())
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            if friend.todayAchieved {
                if let cat = friend.todayCategoryName {
                    HStack(spacing: 8) {
                        Text(cat)
                            .font(Typography.caption)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Palette.chipBackground, in: Capsule())
                            .foregroundStyle(Palette.primaryDeep)
                        Spacer()
                    }
                }
                if let details = friend.todayExerciseDetails, !details.isEmpty {
                    // 友達が「回数・時間・セット数も共有」を ON にしている場合
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(details) { detail in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Palette.primary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(detail.name)
                                        .font(Typography.body)
                                        .foregroundStyle(Palette.textPrimary)
                                    if !detail.summary.isEmpty {
                                        Text(detail.summary)
                                            .font(Typography.caption)
                                            .foregroundStyle(Palette.textSecondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }
                } else if !friend.todayExerciseNames.isEmpty {
                    // 種目名のみ共有 (デフォルト)
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(friend.todayExerciseNames, id: \.self) { name in
                            HStack(spacing: 8) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(Palette.primary)
                                Text(name)
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.textPrimary)
                            }
                        }
                    }
                } else {
                    Text("詳細は共有されていません")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            } else {
                Text("今日はまだ運動の記録がありません")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(todayAccessibilitySummary)
    }

    private var todayAccessibilitySummary: String {
        if friend.todayAchieved {
            let cat = friend.todayCategoryName ?? ""
            let names = friend.todayExerciseNames.joined(separator: "、")
            return "今日の運動: 達成。\(cat) \(names)".trimmingCharacters(in: .whitespaces)
        } else {
            return "今日の運動: まだ達成していません"
        }
    }

    // MARK: - Weekly

    private var weeklySection: some View {
        let weekly = friend.weeklyAchievementsOrEmpty
        let achievedCount = weekly.filter { $0 }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今週の達成")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(achievedCount) / 7 日")
                    .font(Typography.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            FriendWeekStripView(weekly: weekly, today: today)
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今週 \(achievedCount) 日達成")
    }

    private var today: Int {
        // Mon=0..Sun=6
        let wd = calendar.component(.weekday, from: Date())
        return (wd + 5) % 7
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 12) {
            statTile(emoji: "🔥",
                     value: "\(friend.currentStreak)",
                     label: "連続日数",
                     accent: Palette.primaryDeep)
            statTile(emoji: "🏆",
                     value: "\(friend.totalAchievedDays)",
                     label: "累計達成日",
                     accent: tierColor)
            if let since = friend.connectedSince {
                let days = max(1, calendar.dateComponents([.day], from: since, to: Date()).day ?? 0)
                statTile(emoji: "🤝",
                         value: "\(days)",
                         label: "つながって",
                         accent: Palette.secondary)
            }
        }
    }

    private func statTile(emoji: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Text(emoji)
                .font(.system(size: 26))
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .foregroundStyle(accent)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }

    // MARK: - Cheer

    private var cheerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("応援を送る")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CheerKind.allCases, id: \.self) { kind in
                    cheerButton(kind)
                }
            }

            if let sentCheer {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                    Text("\(sentCheer.emoji) \(sentCheer.label) を送りました")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                }
                .padding(10)
                .background(Palette.success.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("friend-detail-cheer-toast")
            }
        }
        .padding(16)
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .animation(.easeOut(duration: 0.25), value: sentCheer)
    }

    private func cheerButton(_ kind: CheerKind) -> some View {
        Button {
            Task { await send(kind) }
        } label: {
            HStack(spacing: 6) {
                Text(kind.emoji)
                    .font(.system(size: 22))
                Text(kind.label)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(cheerInFlight)
        .accessibilityIdentifier("cheer-\(kind.rawValue)")
        .accessibilityLabel("\(kind.label) を送る")
    }

    private func send(_ kind: CheerKind) async {
        cheerInFlight = true
        hapticFeedback.success()
        await friendsStore.cheer(kind, to: friend.friendCode)
        let token = UUID()
        sentCheerToken = token
        sentCheer = kind
        cheerInFlight = false
        try? await Task.sleep(for: .seconds(2.4))
        // Token-based dismissal so rapid taps of the same kind don't
        // dismiss the latest toast early.
        if sentCheerToken == token {
            sentCheer = nil
            sentCheerToken = nil
        }
    }

    // MARK: - Remove

    private var removeButton: some View {
        Button(role: .destructive) {
            pendingRemoval = true
        } label: {
            Label("友達を解除", systemImage: "person.crop.circle.badge.minus")
                .font(Typography.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .accessibilityIdentifier("friend-detail-remove")
    }

    // MARK: - Helpers

    private var tierColor: Color {
        switch friend.decorationTier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return Palette.textSecondary
        }
    }

    private var lastUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return "最終更新 \(formatter.localizedString(for: friend.lastUpdated, relativeTo: Date()))"
    }
}

// MARK: - Weekly strip

struct FriendWeekStripView: View {
    let weekly: [Bool]
    let today: Int   // Mon=0..Sun=6
    private let labels = ["月", "火", "水", "木", "金", "土", "日"]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { idx in
                cell(idx: idx)
            }
        }
    }

    private func cell(idx: Int) -> some View {
        let achieved = weekly.indices.contains(idx) ? weekly[idx] : false
        let isToday = idx == today
        return VStack(spacing: 6) {
            Text(labels[idx])
                .font(Typography.caption)
                .foregroundStyle(isToday ? Palette.primaryDeep : Palette.textSecondary)
            ZStack {
                Circle()
                    .fill(background(achieved: achieved, isToday: isToday))
                    .frame(width: 34, height: 34)
                if achieved {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(.white)
                } else if isToday {
                    Circle()
                        .strokeBorder(Palette.primary, lineWidth: 2)
                        .frame(width: 34, height: 34)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(labels[idx])曜日 \(achieved ? "達成" : "未達成")\(isToday ? " 今日" : "")")
    }

    private func background(achieved: Bool, isToday: Bool) -> Color {
        if achieved { return Palette.success.opacity(0.75) }
        if isToday { return Palette.primary.opacity(0.15) }
        return Palette.chipBackground.opacity(0.6)
    }
}
