import SwiftUI

/// Phase 7.0 で「猫劇場」に再設計したホーム画面。
/// 旧設計: ヘッダー + 猫 (72pt) + CTA + 週カレ + 達成カード + 累計 + 体重 + レビュー
/// 新設計: 上端 chip + 巨大な猫 + 吹き出し + 「ぽちっと記録」CTA + 週カレ mini
/// → 数字系カード (累計 / 体重 / 月次レビュー) は Stats タブへ全て移動。
struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var viewModel = HomeViewModel()
    @State private var isShowingEntry = false
    @State private var completedRecord: WorkoutRecord?
    @State private var completedStreakExtendedThisRun = false
    @State private var selectedDayEntry: DailyStatusEntry?
    @State private var isShowingStreakShare = false
    @State private var presentedMilestone: Milestone?
    private let calendar = Calendar.mondayFirst

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    // 上部に「今週 + 状態」を集約。一番目立たせたい今週の達成度を
                    // 最上段に置き、連続記録 / 残り時間はその下にぶら下げる。
                    VStack(spacing: 12) {
                        weeklyMini
                        topStatusBar
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // 猫劇場。weeklyMini を上に出した分、猫は相対的に少し下に
                    // 寄って「ステージ感」が出る。maxHeight 占有は変えず Spacer 役。
                    catTheater
                        .frame(maxHeight: .infinity)

                    primaryActionButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                store.fetchRecords()
                viewModel.refresh(records: store.records)
                handleAutoPresentations()
            }
            .fullScreenCover(isPresented: $isShowingEntry, onDismiss: {
                viewModel.refresh(records: store.records)
            }) {
                RecordEntryView { record in
                    viewModel.refresh(records: store.records, streakExtendedThisRun: true)
                    completedStreakExtendedThisRun = viewModel.streakExtendedThisRun
                    completedRecord = record
                    WidgetSnapshotPublisher.publish(from: store, today: Date(), calendar: calendar)
                    Task { @MainActor in
                        await NotificationScheduler(calendar: calendar).rescheduleAfterAchievement(
                            currentStreak: viewModel.streak.currentStreak,
                            weeklyProgressRate: viewModel.progress.rate
                        )
                    }
                    isShowingEntry = false
                }
                .environment(store)
            }
            .navigationDestination(item: $completedRecord) { record in
                RecordCompletionView(
                    record: record,
                    streakExtendedThisRun: completedStreakExtendedThisRun,
                    onRecordAnother: {
                        completedRecord = nil
                        isShowingEntry = true
                    }
                )
                .environment(store)
            }
            .sheet(item: $selectedDayEntry) { entry in
                DayDetailSheet(
                    date: entry.date,
                    records: store.records.filter { calendar.isDate($0.date, inSameDayAs: entry.date) },
                    status: entry.status
                )
            }
            .sheet(isPresented: $isShowingStreakShare) {
                StreakShareSheet(streak: viewModel.streak.currentStreak, isPresented: $isShowingStreakShare)
            }
            .sheet(item: $presentedMilestone) { milestone in
                MilestoneCelebrationSheet(
                    milestone: milestone,
                    isPresented: Binding(get: { presentedMilestone != nil },
                                          set: { if !$0 { presentedMilestone = nil } }),
                    onAcknowledge: {
                        viewModel.acknowledgeMilestone(milestone)
                    }
                )
            }
        }
    }

    // MARK: - Top status bar (連続日数 + 達成状況の chip)

    /// 数字 (連続日数) は残しつつ、達成済みは「達成 ✨」の chip で表現。
    /// 「数字 + 状態」の両方を 1 列で軽く伝える方針。
    private var topStatusBar: some View {
        HStack {
            StreakBadgeView(streak: viewModel.streak.currentStreak) {
                guard viewModel.streak.currentStreak > 0 else { return }
                isShowingStreakShare = true
            }
            Spacer()
            statusChip
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        if viewModel.todayStatus == .todayAchieved {
            Label("今日は達成済み", systemImage: "checkmark.seal.fill")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.success.opacity(0.18), in: Capsule())
                .foregroundStyle(Palette.success)
        } else if viewModel.todayStatus == .rest {
            Label("今日は回復日", systemImage: "moon.zzz.fill")
                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.restDay.opacity(0.30), in: Capsule())
                .foregroundStyle(Palette.textPrimary)
        } else {
            Text(remainingTimeText)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Palette.surface, in: Capsule())
        }
    }

    // MARK: - Cat theater (画面の主役)

    /// 猫を大きく見せて、横に吹き出しメッセージ。Phase 7.0 の核心。
    /// 220 → 280pt に拡大。speech bubble の font も少しアップ。
    private var catTheater: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            BigCatView(state: viewModel.catState, decoration: viewModel.catDecoration)
                .frame(width: 280, height: 280)
            speechBubble
                .padding(.horizontal, 24)
            Spacer(minLength: 4)
        }
        .frame(maxWidth: .infinity)
    }

    /// 吹き出しの上に小さな三角形のしっぽを付けて、猫の口元から
    /// 話しているように見せる (Gemini 改善提案 ③)。
    private var speechBubble: some View {
        VStack(spacing: 0) {
            BubbleTriangle()
                .fill(Palette.surface)
                .frame(width: 18, height: 10)
                .shadow(color: .black.opacity(0.05), radius: 2, y: -1)
            Text(viewModel.catMessage.text)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
        }
        .accessibilityLabel("猫からのメッセージ: \(viewModel.catMessage.text)")
    }

    // MARK: - Weekly mini

    private var weeklyMini: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今週")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("\(viewModel.progress.achievedCount) / \(viewModel.progress.totalDays) 日達成")
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .monospacedDigit()
            }
            WeeklyCalendarView(statuses: viewModel.statuses, today: store.today, calendar: calendar) { entry in
                selectedDayEntry = entry
            }
        }
    }

    // MARK: - Primary CTA

    /// Gemini 改善提案 ②: 未達成時は CTA を微妙にパルスさせて視線を誘導。
    /// 達成済みは静的 (もう急かさない)。
    /// 共通 PrimaryButton より一回り大きい LargePrimaryCTA を使ってホーム主役感を出す。
    @ViewBuilder
    private var primaryActionButton: some View {
        if viewModel.todayStatus == .todayAchieved {
            LargePrimaryCTA(title: "もう一種目する 🔥",
                            systemImage: "plus.circle.fill",
                            identifier: "primary-record-action",
                            pulsing: false) {
                isShowingEntry = true
            }
        } else {
            LargePrimaryCTA(title: "今日の運動を記録する",
                            systemImage: "plus.circle.fill",
                            identifier: "primary-record-action",
                            pulsing: true) {
                isShowingEntry = true
            }
        }
    }

    // MARK: - Background

    /// 時刻に応じて hue が淡く変化する。朝はピーチ、昼はクリーム、
    /// 夕方はオレンジ、夜は深い藍。Palette.background を base に重ねる
    /// LinearGradient で軽く演出 (派手にしすぎない)。
    private var backgroundGradient: some View {
        let hour = calendar.component(.hour, from: Date())
        let top: Color
        let bottom: Color
        switch hour {
        case 5..<11:
            top = Palette.background; bottom = Color(red: 1.00, green: 0.85, blue: 0.78)
        case 11..<16:
            top = Palette.background; bottom = Color(red: 1.00, green: 0.93, blue: 0.80)
        case 16..<21:
            top = Palette.background; bottom = Color(red: 1.00, green: 0.82, blue: 0.65)
        default:
            top = Palette.background; bottom = Color(red: 0.80, green: 0.83, blue: 0.93)
        }
        return LinearGradient(colors: [top, bottom.opacity(0.45)],
                              startPoint: .top, endPoint: .bottom)
    }

    private var remainingTimeText: String {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: store.today) ?? Date()
        let hours = max(0, calendar.dateComponents([.hour], from: Date(), to: endOfDay).hour ?? 0)
        return "今日の締切まで あと\(hours)時間"
    }

    private func handleAutoPresentations() {
        let skipAuto = ProcessInfo.processInfo.arguments.contains("--skip-milestones")
        if !skipAuto, presentedMilestone == nil, let milestone = viewModel.pendingMilestone {
            presentedMilestone = milestone
        }
    }
}

/// CatStateView の大型版 (280pt)。装飾もキャラ全体にスケールするように
/// 元 CatStateView をベースに新規。
/// - 丸枠の clipShape を外して `.scaledToFit` で表示することで、しっぽや
///   バンザイした手など円の外に出る要素が切れなくなる。背景 Circle は装飾
///   (光輪) として残す。
/// - breathing (scale) に加え、float (offset y) と微小 sway (rotation) を
///   合成して有機的な動きに。reduceMotion 設定時は全停止。
struct BigCatView: View {
    let state: CatState
    var decoration: CatDecoration = .none
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var floating = false
    @State private var swaying = false

    var body: some View {
        let breed = UserCatPreferences.shared.myCat
        let primary = state.assetName(breed: breed)
        let resolved = UIImage(named: primary) != nil ? primary : CatBreed.fallbackAssetName(for: state)
        ZStack {
            // 背景の光輪 (装飾)。キャラ画像はこの円の外まで描かれて構わない。
            Circle()
                .fill(LinearGradient(
                    colors: [breed.tintColor.opacity(0.32), breed.tintColor.opacity(0.06)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .scaleEffect(0.88) // 円を画像より一回り内側に置く
            if UIImage(named: resolved) != nil {
                Image(resolved)
                    .resizable()
                    .scaledToFit()
                    // 画像領域を Circle より少しだけ広く取り、しっぽ・手・装飾の
                    // 飛び出しを clip しない。
                    .padding(2)
            } else {
                Text(state.emoji)
                    .font(.system(size: 120))
            }
            CatDecorationOverlay(decoration: decoration)
                .scaleEffect(2.2)
        }
        .scaleEffect(reduceMotion ? 1 : (breathing ? 1.03 : 1))
        .offset(y: reduceMotion ? 0 : (floating ? -8 : 4))
        .rotationEffect(reduceMotion ? .zero : .degrees(swaying ? 2 : -2))
        .accessibilityLabel("猫キャラクター \(state.displayName)")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                breathing = true
            }
            // 周期をずらして合成すると 1 軸より生き物っぽく感じる
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                floating = true
            }
            withAnimation(.easeInOut(duration: 4.1).repeatForever(autoreverses: true)) {
                swaying = true
            }
        }
    }
}

/// 吹き出しのしっぽ三角形。先端 (top) を猫に向けるため上を尖らせる。
private struct BubbleTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// ホーム主役の大型 CTA。共通 PrimaryButton より font/padding/icon を一段大きく作り、
/// `pulsing: true` で未達成時のゆっくり脈動を有効化する。reduceMotion で停止。
private struct LargePrimaryCTA: View {
    let title: String
    let systemImage: String
    let identifier: String
    var pulsing: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    private let hapticFeedback = HapticFeedback()

    var body: some View {
        Button {
            hapticFeedback.tap()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .heavy))
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .foregroundStyle(.white)
            .background(Palette.primary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(PressableScaleButtonStyle())
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
        .scaleEffect(pulsing && !reduceMotion && pulse ? 1.04 : 1)
        .shadow(
            color: Palette.primary.opacity(pulsing && !reduceMotion && pulse ? 0.45 : 0.20),
            radius: pulsing && !reduceMotion && pulse ? 14 : 6,
            y: 4
        )
        .onAppear {
            guard pulsing, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

extension Milestone: Identifiable {
    public var id: String {
        switch self {
        case .anniversary(let years): return "anniv-\(years)"
        case .lifetimeDays(let d): return "lifetime-\(d)"
        case .currentStreak(let d): return "streak-\(d)"
        }
    }
}
