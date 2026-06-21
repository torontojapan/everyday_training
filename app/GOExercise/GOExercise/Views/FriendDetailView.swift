import SwiftUI

/// 個別の友達の状態をじっくり確認できる詳細シート。
/// 装飾ランク / 今日のメニュー / 週カレンダー / 累計 / cheer を一画面に集約。
struct FriendDetailView: View {
    let friend: FriendProfile
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var sentCheerText: String?
    @State private var sentCheerToken: UUID?
    @State private var cheerInFlight = false
    /// 応援の一言コメント入力(プリセットタップで反映 / 自由入力可・30字制限)。
    @State private var cheerText = ""
    @State private var pendingRemoval = false
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
            // 中央表示の標準アラート (popover の矢印/配置崩れを避ける。iPhone/iPad 共通で安定)。
            .alert(
                "\(friend.displayName) を友達から外しますか？",
                isPresented: $pendingRemoval
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
        let breed = FriendAvatarResolver.resolve(for: friend)
        return VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [breed.tintColor.opacity(0.50), breed.tintColor.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 132, height: 132)
                Image(breed.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.05)
                    .frame(width: 132, height: 132)
                    .clipShape(Circle())
            }
            .accessibilityHidden(true)

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

            if friend.rank.rank > 0 {
                RankBadge(rank: friend.rank, species: friend.myPet?.species ?? .cat)
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
        // 本人のホーム週ストリップ ([[WeeklyCalendarView]]) と同じ状態別表示にする。
        // countsAsAchieved で潰した Bool では休養 (休)・フリーズ (○)・実運動 (◎) を
        // 区別できず「全部緑✓」に見えていたため、日ごとの状態配列で描画する。
        let statuses = friend.weeklyStatusesOrEmpty
        let achievedCount = statuses.filter { $0.countsAsAchieved }.count
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
            FriendWeekStripView(statuses: statuses, today: today)
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
            statTile(systemImage: "pawprint.fill",
                     value: "\(friend.currentStreak)",
                     label: "連続日数",
                     accent: Palette.primaryDeep)
            statTile(systemImage: "trophy.fill",
                     value: "\(friend.totalAchievedDays)",
                     label: "累計達成日",
                     accent: tierColor)
            if let since = friend.connectedSince {
                let days = max(1, calendar.dateComponents([.day], from: since, to: Date()).day ?? 0)
                statTile(systemImage: "person.2.fill",
                         value: "\(days)",
                         label: "つながって",
                         accent: Palette.secondary)
            }
        }
    }

    private func statTile(systemImage: String, value: String, label: String, accent: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(accent)
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

    /// 応援コメントの最大文字数(トースト/カード表示に収まる長さ。DB 側は 60 字で最終ガード)。
    private static let cheerLimit = 30

    private var trimmedCheerText: String {
        cheerText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var cheerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("応援を送る")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)

            // コメント入力欄 + 送信ボタン。下のプリセットをタップすると入力欄に反映され、
            // そのまま送るか、自由に書き換えてから送れる(ユーザー要望)。
            HStack(spacing: 8) {
                TextField("応援メッセージ(\(Self.cheerLimit)字まで)", text: $cheerText)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .onSubmit { Task { await sendCheerMessage() } }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Palette.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .onChange(of: cheerText) { _, newValue in
                        if newValue.count > Self.cheerLimit {
                            cheerText = String(newValue.prefix(Self.cheerLimit))
                        }
                    }
                    .accessibilityIdentifier("cheer-message-field")
                Button {
                    Task { await sendCheerMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(trimmedCheerText.isEmpty || cheerInFlight
                                         ? Palette.textSecondary.opacity(0.4)
                                         : Palette.primary)
                }
                .buttonStyle(.plain)
                .disabled(trimmedCheerText.isEmpty || cheerInFlight)
                .accessibilityLabel("応援を送信")
                .accessibilityIdentifier("cheer-send-button")
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(CheerKind.allCases, id: \.self) { kind in
                    cheerButton(kind)
                }
            }

            if let sentCheerText {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Palette.success)
                    Text("「\(sentCheerText)」を送りました")
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
        .animation(.easeOut(duration: 0.25), value: sentCheerText)
    }

    /// プリセット: タップでコメント欄に反映する(送信はしない。送信は右の↑ボタン)。
    private func cheerButton(_ kind: CheerKind) -> some View {
        Button {
            cheerText = kind.label
        } label: {
            HStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.primaryDeep)
                Text(kind.label)
                    .font(Typography.body)
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(
                cheerText == kind.label ? Palette.primary.opacity(0.18) : Palette.chipBackground,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(cheerInFlight)
        .accessibilityIdentifier("cheer-\(kind.rawValue)")
        .accessibilityLabel("\(kind.label) をコメント欄に入れる")
    }

    /// 入力欄の内容を送信する。プリセットのラベルと一致すればその kind、
    /// 自由文なら kind = custom(アイコンはハート)として送る。
    private func sendCheerMessage() async {
        let text = trimmedCheerText
        guard !text.isEmpty, !cheerInFlight else { return }
        // プリセットのラベルと一致すればその kind、自由文は fight を器にする
        // (表示は常に message が優先されるので kind は互換用のフォールバックに過ぎない)。
        let kind = CheerKind.allCases.first { $0.label == text } ?? .fight
        cheerInFlight = true
        hapticFeedback.success()
        await friendsStore.cheer(kind, to: friend.friendCode, message: text)
        let token = UUID()
        sentCheerToken = token
        sentCheerText = text
        cheerText = ""
        cheerInFlight = false
        try? await Task.sleep(for: .seconds(2.4))
        // Token-based dismissal so rapid sends don't dismiss the latest toast early.
        if sentCheerToken == token {
            sentCheerText = nil
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

    /// 累計達成日タイルのアクセント色。称号 (CatRank) のメタル系統に揃える
    /// (旧 decorationTier 0..4 スイッチは rank が 0..11 になり 5 以上が灰色落ち
    ///  していたため、rank.metalKind 由来に統一)。
    private var tierColor: Color {
        guard let metal = friend.rank.metalKind else { return Palette.textSecondary }
        return MetalStyle.isRainbow(metal) ? Color(red: 1.0, green: 0.80, blue: 0.42) : MetalStyle.baseColor(metal)
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
    /// 7 要素 (月→日) の日ごとの状態。本人のホーム週ストリップと同じ正本。
    let statuses: [DailyStatus]
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
        let status = statuses.indices.contains(idx) ? statuses[idx] : .future
        let isToday = idx == today
        return VStack(spacing: 6) {
            Text(labels[idx])
                .font(Typography.caption)
                .foregroundStyle(isToday ? Palette.primaryDeep : Palette.textSecondary)
            // ホーム ([[WeeklyCalendarView]]) と同一の記号 (◎/○/休/×/-/・) + 状態別配色。
            Text(status.symbol)
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
                .frame(width: 34, height: 34)
                .background(background(status: status, isToday: isToday), in: Circle())
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(labels[idx])曜日 \(accessibilityValue(for: status))\(isToday ? " 今日" : "")")
    }

    /// ホーム週ストリップ ([[WeeklyCalendarView]].background) と同一の配色ルール。
    /// 今日はオレンジ強調 / 運動=赤 / 休養・フリーズ=緑系 / 未達=青 / 未来=薄。
    private func background(status: DailyStatus, isToday: Bool) -> Color {
        if isToday { return Palette.primary.opacity(0.95) }
        switch status {
        case .achieved, .todayAchieved: return Color(red: 0.93, green: 0.33, blue: 0.30).opacity(0.65)
        case .rest: return Color(red: 0.36, green: 0.65, blue: 0.40).opacity(0.60)
        case .rescued: return Color(red: 0.36, green: 0.65, blue: 0.40).opacity(0.35)
        case .missed: return Color(red: 0.38, green: 0.55, blue: 0.90).opacity(0.32)
        case .future, .todayPending: return Palette.secondary.opacity(0.45)
        }
    }

    private func accessibilityValue(for status: DailyStatus) -> String {
        switch status {
        case .achieved, .todayAchieved: return "達成済み"
        case .rescued: return "保険チケットで継続"
        case .rest: return "休養日"
        case .missed: return "未達成"
        case .future: return "未来"
        case .todayPending: return "未達成"
        }
    }
}
