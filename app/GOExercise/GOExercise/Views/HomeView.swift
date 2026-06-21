import SwiftUI

/// Phase 7.0 で「猫劇場」に再設計したホーム画面。
/// 旧設計: ヘッダー + 猫 (72pt) + CTA + 週カレ + 達成カード + 累計 + 体重 + レビュー
/// 新設計: 上端 chip + 巨大な猫 + 吹き出し + 「ぽちっと記録」CTA + 週カレ mini
/// → 数字系カード (累計 / 体重 / 月次レビュー) は Stats タブへ全て移動。
struct HomeView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(ReferralStore.self) private var referralStore
    @Environment(RecordSyncCoordinator.self) private var recordSync
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = HomeViewModel()
    @State private var isShowingEntry = false
    @State private var completedRecord: WorkoutRecord?
    @State private var completedStreakExtendedThisRun = false
    @State private var selectedDayEntry: DailyStatusEntry?
    @State private var isShowingStreakShare = false
    @State private var presentedMilestone: Milestone?
    @State private var pendingRankEvent: RankUpEvent?
    private let rankUpDetector = RankUpDetector()
    @State private var isShowingRevive = false
    @State private var isShowingFreezePaywall = false
    /// revive シートを閉じた「後」に freeze ペイウォールを出すための予約フラグ。
    /// 同一 runloop で2シートを切り替えると SwiftUI が2枚目の提示を取りこぼす(GPT-5.5: handoff race)。
    @State private var pendingFreezePaywall = false
    @State private var reviveShownThisLaunch = false
    @State private var reviveCelebration: CatRank?
    private let reviveDismissStore = ReviveDismissStore()
    /// 猫タップで bounce する用。
    @State private var catBounce = false
    /// 起動時に吹き出しを pop-in させる用。
    @State private var bubbleAppeared = false
    /// 達成の紙吹雪演出を「その日 1 回だけ」にするための日付キー (再訪では出さない)。
    @AppStorage("home.celebratedDay") private var celebratedDay: String = ""
    /// 紙吹雪を出している間だけ true。1 回出したらその日は false に戻す。
    @State private var isCelebrating = false
    private let calendar = Calendar.mondayFirst
    private let hapticFeedback = HapticFeedback()

    var body: some View {
        NavigationStack {
            ZStack {
                // 現在の連続日数で段階的に豪華になる全面背景(旧 累計達成日数ベースを置換)。
                MilestoneBackdrop(streak: viewModel.streak.currentStreak)
                    .ignoresSafeArea()

                // 背景に時刻に応じたパーティクル。常時ふわふわ漂う。
                // 達成済みなら紙吹雪も追加して祝祭感を出す。
                AmbientParticlesView(
                    hour: calendar.component(.hour, from: Date()),
                    isCelebrating: isCelebrating
                )
                .allowsHitTesting(false)
                .ignoresSafeArea()
                // 演出パーティクルは装飾のみ。VoiceOver から完全に外して
                // ユーザー操作を妨げない (Codex UX #3 a11y セーフモード)。
                .accessibilityHidden(true)

                VStack(spacing: 0) {
                    // 上部に「今週 + 状態」を集約。一番目立たせたい今週の達成度を
                    // 最上段に置き、連続記録 / 残り時間はその下にぶら下げる。
                    VStack(spacing: 12) {
                        weeklyMini
                        topStatusBar
                        referralStarsFullRow
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // 猫劇場。weeklyMini を上に出した分、猫は相対的に少し下に
                    // 寄って「ステージ感」が出る。maxHeight 占有は変えず Spacer 役。
                    catTheater
                        .frame(maxHeight: .infinity)

                    comebackWelcomeCard
                        .padding(.horizontal, 20)

                    primaryActionButton
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                }

                if let event = pendingRankEvent {
                    RankCelebrationOverlay(
                        rank: rankForEvent(event),
                        message: messageForEvent(event),
                        onFinished: { pendingRankEvent = nil }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }

                if let rank = reviveCelebration {
                    RankCelebrationOverlay(
                        rank: rank,
                        message: "連続復活!",
                        onFinished: { reviveCelebration = nil }
                    )
                    .transition(.opacity)
                    .zIndex(11)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                refreshHomeState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                // 前面復帰時の再計算。これが無いと、バックグラウンドで日付が変わった翌朝に、
                // ホームが昨日の「達成済み」チップや古い CTA を出したまま固まる
                // (タブ切替で onAppear が走るまで直らない)。
                // WeightView は既に scenePhase を監視しており、ホームに同等が欠けていた(監査 P1)。
                guard newPhase == .active else { return }
                refreshHomeState()
            }
            .onChange(of: completedRecord) { oldValue, newValue in
                // 記録完了画面から**ホームへ戻った**ときだけ達成演出を出す。
                // 「もう一種目する」(completedRecord=nil と同時に isShowingEntry=true で
                // 記録へ戻る)では出さない。
                guard oldValue != nil, newValue == nil, !isShowingEntry else { return }
                fireRecordCelebrations()
            }
            // signIn (App.task) は onAppear と並行で走るため、初回は profile が
            // まだ nil で sync が空振りすることがある。profile が現れた / 変わった
            // タイミングで再同期して友達タブの自分の実績を最新化する (3 LLM 監査 B-Critical)。
            .onChange(of: friendsStore.profile?.friendCode) { _, _ in
                syncMyFriendProfile()
                // アカウント切替/復元/サインアウトで friend_code が変わったら紹介状態も取り直す。
                // これが無いと星/今月フリーズ/⭐10猫解放が前アカウントの値のまま、または
                // 新アカウントの正当な解放が次回起動まで反映されない(口座スコープ漏れ、監査 P2)。
                Task { await referralStore.refresh() }
                // 機種変更/再インストールの復元: まず前アカウント宛の削除キュー/同期時刻を
                // 破棄してから(口座跨ぎ wipe 防止, Codex P1)、新アカウントのバックアップが
                // あれば取り込み、バックアップ設定も自動で ON にする(Duolingo 型)。
                recordSync.resetForIdentityChange()
                Task { await recordSync.restoreAfterSignIn() }
            }
            .fullScreenCover(isPresented: $isShowingEntry, onDismiss: {
                viewModel.refresh(records: store.records, weightLoss: currentWeightSnapshot(), isPremium: storeKit.isPremiumActive, referralFreezeBonus: referralStore.currentAccountFreezeBonus)
                syncMyFriendProfile()
            }) {
                RecordEntryView { record in
                    // 連続日数が「この記録で」伸びたのは今日 1 件目のときだけ。
                    // 2 件目以降(もう一種目)でも true を渡すと完了画面に
                    // 「きのうから +1 のばした!」が再表示される誤りがあった。
                    // store.records はこの時点で新しい記録を含む。
                    let isFirstRecordToday = store.records.filter {
                        calendar.isDate($0.date, inSameDayAs: Date())
                    }.count <= 1
                    viewModel.refresh(records: store.records, streakExtendedThisRun: isFirstRecordToday, weightLoss: currentWeightSnapshot(), isPremium: storeKit.isPremiumActive, referralFreezeBonus: referralStore.currentAccountFreezeBonus)
                    // 記録直後に友達タブの自分の実績も更新する (Codex 指摘: 旧コードは
                    // onAppear/onChange のみで、記録後すぐは stale だった)。
                    syncMyFriendProfile()
                    completedStreakExtendedThisRun = viewModel.streakExtendedThisRun
                    completedRecord = record
                    WidgetSnapshotPublisher.publish(from: store, today: Date(), rescuedDates: RescueTicketStore.shared.rescuedDates(), calendar: calendar)
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
                // スワイプで閉じてもボタン同様に acknowledge する。これが無いと
                // 未確認のまま残り、次の記録ごとに同じ節目シートが再発する(GPT-5.5/Claude 監査)。
                // acknowledge は冪等(Set への記録)なので二重呼びでも安全。
                .onDisappear { viewModel.acknowledgeMilestone(milestone) }
            }
            .sheet(isPresented: Binding(
                get: { referralStore.pendingWelcome != nil },
                set: { if !$0 { referralStore.consumeWelcome() } }
            )) {
                if let pop = referralStore.pendingWelcome {
                    ReferralCelebrationSheet(confirmations: [pop])
                }
            }
            .sheet(isPresented: Binding(
                get: { !referralStore.pendingReferrerPops.isEmpty },
                set: { if !$0 { referralStore.consumeReferrerPops() } }
            )) {
                ReferralCelebrationSheet(confirmations: referralStore.pendingReferrerPops)
            }
            .sheet(isPresented: $isShowingRevive, onDismiss: {
                // revive シートが完全に閉じてからペイウォールを出す(2シート同時切替の取りこぼし回避)。
                if pendingFreezePaywall {
                    pendingFreezePaywall = false
                    isShowingFreezePaywall = true
                }
            }) {
                let w = viewModel.reviveWindow
                StreakRevivePopup(
                    potentialStreak: viewModel.potentialReviveStreak,
                    freezesNeeded: w?.freezesNeeded ?? 0,
                    remaining: viewModel.reviveRemainingFreezes,
                    hasEnough: w?.hasEnough ?? false,
                    onUseFreeze: { handleReviveUse() },
                    onSeePremium: {
                        // ペイウォールを見るだけでは break を handled にしない。
                        // プレミアム購入後に同じ break をまだ復活できるようにする(Codex/Gemini監査)。
                        // 提示は revive の onDismiss 後に予約(同一 runloop の二重 sheet を避ける)。
                        pendingFreezePaywall = true
                        isShowingRevive = false
                    },
                    onDismiss: {
                        markReviveHandled()
                        isShowingRevive = false
                    }
                )
                // スワイプ dismiss だと break が未処理のまま残り次回起動で再提示される(GPT-5.5 P1)。
                // 復活は「使う/プレミアム/今回はしない」の明示ボタンで分岐するため、ジェスチャ dismiss を
                // 封じてボタン経由に強制する(handled 化は成功時のみ等の条件付きなので onDismiss 一括化は不可)。
                .interactiveDismissDisabled()
            }
            .sheet(isPresented: $isShowingFreezePaywall, onDismiss: {
                // フリーズ目的でペイウォールへ来て購入完了した場合、同じ break の復活ポップへ戻す
                // (GPT-5.5 P1: 購入後に復活導線へ戻れない)。プレミアムで allowance が増えるため
                // viewModel を再計算し、reviveShownThisLaunch を解除して再提示判定する。
                if storeKit.isPremiumActive {
                    viewModel.refresh(records: store.records, weightLoss: currentWeightSnapshot(),
                                      isPremium: storeKit.isPremiumActive,
                                      referralFreezeBonus: referralStore.currentAccountFreezeBonus)
                    reviveShownThisLaunch = false
                    maybePresentRevive()
                }
            }) {
                PremiumPaywallSheet(store: storeKit, context: .freeze)
            }
            .alert("⭐10達成!", isPresented: Binding(
                get: { referralStore.pendingBreedUnlock },
                set: { if !$0 { referralStore.consumeBreedUnlock() } }
            )) {
                Button("やったね!", role: .cancel) { referralStore.consumeBreedUnlock() }
            } message: {
                Text("友達を10人紹介しました!設定や猫選びの画面から、好きな猫が無料で選べるようになりました。")
            }
        }
    }

    // MARK: - Top status bar (連続日数 + 達成状況の chip)

    /// 数字 (連続日数) は残しつつ、達成済みは「達成 ✨」の chip で表現。
    /// 「数字 + 状態」の両方を 1 列で軽く伝える方針。

    private var topStatusBar: some View {
        // 左 = 連続チップ。右 = 称号(上)+ 状態(下)を右詰めで2段。
        // fillHeight で連続チップを「右列(称号+状態)と同じ高さ」に揃える。
        // ただし HStack を fixedSize(vertical) で自然高さに固定しないと、
        // maxHeight:.infinity が親の余白を全部食って連続チップが過剰に縦長になる。
        // 紹介スターは下段 `referralStarsFullRow` へ。
        HStack(alignment: .top, spacing: 8) {
            StreakBadgeView(streak: viewModel.streak.currentStreak, fillHeight: true) {
                guard viewModel.streak.currentStreak > 0 else { return }
                isShowingStreakShare = true
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                if CatRank(currentStreak: viewModel.streak.currentStreak).rank > 0 {
                    RankBadge(rank: CatRank(currentStreak: viewModel.streak.currentStreak))
                }
                statusChip
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 3 行目。**紹介スターを全幅 1 行**に置く(称号と分離したので最大10星が
    /// 折り返さず一直線に並ぶ)。星は友達を紹介して 1 個以上付いて初めて表示する
    /// (0 星のゴースト星は出さない)。未サインインでも描画しない。
    @ViewBuilder
    private var referralStarsFullRow: some View {
        if AppFeatureFlags.isReferralActive,
           referralStore.currentAccountStarBadges > 0,
           let code = friendsStore.profile?.friendCode {
            ReferralStarsRow(count: referralStore.currentAccountStarBadges, friendCode: code)
        }
    }

    /// 称号カプセル(RankBadge: footnote + 縦 padding 6)と同じ縦幅に揃える。
    /// これで右列(称号+状態)が低くなり、fillHeight の連続チップも釣られて低くなる。
    @ViewBuilder
    private var statusChip: some View {
        if viewModel.todayStatus == .todayAchieved {
            Label("今日は達成済み", systemImage: "checkmark.seal.fill")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Palette.success.opacity(0.18), in: Capsule())
                .foregroundStyle(Palette.success)
        } else if viewModel.todayStatus == .rest {
            Label("今日は回復日", systemImage: "moon.zzz.fill")
                .font(.system(.footnote, design: .rounded, weight: .heavy))
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Palette.restDay.opacity(0.30), in: Capsule())
                .foregroundStyle(Palette.textPrimary)
        } else {
            Text(remainingTimeText)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(Palette.textSecondary)
                .padding(.horizontal, 11).padding(.vertical, 6)
                .background(Palette.surface, in: Capsule())
        }
    }

    // MARK: - Cat theater (画面の主役)

    /// 猫を大きく見せて、横に吹き出しメッセージ。Phase 7.0 の核心。
    /// 280pt に拡大、breath/float/sway + tap bounce を合成。
    private var catTheater: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 4)
            BigCatView(state: viewModel.catState, useShaker: !viewModel.todayStatus.countsAsAchieved)
                .frame(width: 280, height: 280)
                // タップで bounce + haptic。触れて遊べるキャラ感。
                .scaleEffect(catBounce ? 1.08 : 1.0)
                .onTapGesture {
                    hapticFeedback.tap()
                    withAnimation(.interpolatingSpring(stiffness: 320, damping: 9)) {
                        catBounce = true
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(220))
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                            catBounce = false
                        }
                    }
                }
            speechBubble
                .padding(.horizontal, 24)
                .scaleEffect(bubbleAppeared ? 1.0 : 0.7)
                .opacity(bubbleAppeared ? 1.0 : 0.0)
                .onAppear {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.15)) {
                        bubbleAppeared = true
                    }
                }
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
            LargePrimaryCTA(title: "もう一種目する",
                            systemImage: "plus.circle.fill",
                            identifier: "primary-record-action",
                            pulsing: false) {
                isShowingEntry = true
            }
        } else if viewModel.isComebackToday {
            // Codex UX #2: 復帰日は低圧コピーで踏み込ませる ("never miss twice")。
            LargePrimaryCTA(title: "ただいま記録",
                            systemImage: "house.fill",
                            identifier: "primary-record-action",
                            pulsing: true) {
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

    /// 復帰日用の小さな歓迎カード。CTA の直上に表示。
    /// 「失敗を責める」のではなく「戻ってきてくれた」を強調するコピーに。
    @ViewBuilder
    private var comebackWelcomeCard: some View {
        if viewModel.isComebackToday {
            HStack(spacing: 12) {
                Image(systemName: "door.left.hand.open")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.primaryDeep)
                VStack(alignment: .leading, spacing: 2) {
                    Text("おかえり")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.textPrimary)
                    Text("昨日はおやすみだったね。今日は30秒でも戻れたら100点。")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }
            .padding(14)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Palette.primary.opacity(0.35), lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("comeback-welcome-card")
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
        return "あと\(hours)時間"
    }

    /// 現在の体重スナップショットを `MilestoneDetector` に渡せる形で取り出す。
    /// 1 回読むだけなので毎回 store を作って捨てる (持続必要なし)。
    /// -3kg/-5kg/-10kg の達成判定に使う。
    private func currentWeightSnapshot() -> MilestoneDetector.WeightLossSnapshot {
        let weightStore = WeightStore(context: modelContext)
        let prefs = UserHealthPreferences.shared
        return MilestoneDetector.WeightLossSnapshot(
            startKg: prefs.startKilograms,
            currentKg: weightStore.latestNonFuture?.weightKilograms,
            isLossGoal: prefs.isLossGoal()
        )
    }

    /// 記録完了 → ホーム復帰時にまとめて発火する達成演出。
    /// 節目シート → 称号トースト → 紙吹雪 の順(節目シート提示中は称号トーストを抑止)。
    private func fireRecordCelebrations() {
        handleAutoPresentations()
        evaluateRankCelebration()
        evaluateCelebration()
    }

    private func handleAutoPresentations() {
        // --skip-milestones は UI テスト / スクショ専用。Release では本番の
        // 節目祝祭を必ず出す (debug 引数は Release で無効: QA チェックリスト A)。
        var skipAuto = false
        #if DEBUG
        skipAuto = ProcessInfo.processInfo.arguments.contains("--skip-milestones")
        #endif
        if !skipAuto, presentedMilestone == nil, let milestone = viewModel.pendingMilestone {
            presentedMilestone = milestone
        }
    }

    /// 復活ポップを条件付きで提示(1起動1回・未処理 break のみ)。
    /// onAppear と前面復帰(scenePhase=.active)で共有するホーム状態の再計算。
    /// 達成演出(節目/称号/紙吹雪)は記録完了→ホーム復帰時のみに限定する設計なので
    /// ここでは出さない。復活ポップは演出ではなく救済導線であり、二重ガード
    /// (reviveShownThisLaunch + 永続 isHandled)があるため呼んでも安全。
    private func refreshHomeState() {
        store.fetchRecords()
        viewModel.refresh(records: store.records, weightLoss: currentWeightSnapshot(), isPremium: storeKit.isPremiumActive, referralFreezeBonus: referralStore.currentAccountFreezeBonus)
        maybePresentRevive()
        syncMyFriendProfile()
    }

    private func maybePresentRevive() {
        guard !reviveShownThisLaunch else { return }
        // 大節目シート提示中は二重 .sheet を避ける(evaluateRankCelebration と同じガード)。
        // ここで reviveShownThisLaunch を立てる前に return することで、次回 onAppear で再評価される。
        guard presentedMilestone == nil else { return }
        guard viewModel.reviveWindow != nil else { return }
        // break 識別は refresh 時点の missed 日から導出した安定キーを使う(offset+今の today の
        // 再計算だと日跨ぎで別キーになる, 監査 F2)。
        guard let key = viewModel.reviveBreakKey else { return }
        guard !reviveDismissStore.isHandled(key) else { return }
        reviveShownThisLaunch = true
        isShowingRevive = true
    }

    private func markReviveHandled() {
        if let key = viewModel.reviveBreakKey {
            reviveDismissStore.markHandled(key)
        }
    }

    private func handleReviveUse() {
        // フリーズ適用を先に試し、**全 missed 日の復活に成功した時だけ** handled 化する。
        // 途中失敗(枠切れ/月境界等)で break を消化してしまい復活も損も両取りになるのを防ぐ(Codex/Gemini監査)。
        let restored = viewModel.applyRevive()
        isShowingRevive = false
        if restored != nil {
            markReviveHandled()
        }
        viewModel.refresh(records: store.records, weightLoss: currentWeightSnapshot(),
                          isPremium: storeKit.isPremiumActive, referralFreezeBonus: referralStore.currentAccountFreezeBonus)
        WidgetSnapshotPublisher.publish(from: store, today: Date(), rescuedDates: RescueTicketStore.shared.rescuedDates(), calendar: calendar)
        if let restored {
            reviveCelebration = restored
            CelebrationCenter.shared.fireLight()
        }
    }

    private func rankForEvent(_ event: RankUpEvent) -> CatRank {
        switch event {
        case .rankUp(let to): return CatRank(currentStreak: CatRank.thresholds[max(0, to - 1)])
        case .weekly(let streak): return CatRank(currentStreak: streak)
        }
    }

    private func messageForEvent(_ event: RankUpEvent) -> String {
        switch event {
        case .rankUp: return "称号アップ!"
        case .weekly(let streak): return "\(streak)日連続!"
        }
    }

    /// 起動/記録後に小節目を評価。detector の状態はここで必ず消化し(再発火防止)、
    /// 大節目シート提示中は overlay を抑止する(二重演出防止)。
    private func evaluateRankCelebration() {
        let events = rankUpDetector.evaluate(currentStreak: viewModel.streak.currentStreak)
        guard presentedMilestone == nil else { return } // 大節目優先(状態は消化済み)
        if let up = events.first(where: { if case .rankUp = $0 { return true } else { return false } }) {
            withAnimation { pendingRankEvent = up }
            CelebrationCenter.shared.fireLight()
        } else if let wk = events.first {
            withAnimation { pendingRankEvent = wk }
            CelebrationCenter.shared.fireLight()
        }
    }

    /// 達成の紙吹雪を「その日まだ出していなければ」1 回だけ出す。
    /// ホームに戻る度に紙吹雪が再生される問題を解消する。
    private func evaluateCelebration() {
        let key = celebrationDayKey(for: store.today)
        guard viewModel.todayStatus == .todayAchieved, celebratedDay != key else { return }
        celebratedDay = key
        isCelebrating = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            isCelebrating = false
        }
    }

    private func celebrationDayKey(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    /// 自分の友達プロフィールを実データ (ホームの集計) で更新する。
    /// これが無いと FriendsView の自分カードや週間ランキングが signIn 時の
    /// 初期値 (0 日連続) のまま固定され、ホームの実績と食い違う (3 LLM 監査 B-Critical)。
    /// 種目詳細の内容比較用シグネチャ。id(UUID) は毎回変わるため除外し、
    /// 名前・分・回数・セットで比較する (内容変化も検知する: Codexレビュー)。
    private static func detailSignature(_ details: [SharedExerciseDetail]?) -> [String]? {
        details?.map { "\($0.name)|\($0.durationMinutes ?? -1)|\($0.reps ?? -1)|\($0.sets ?? -1)" }
    }

    private func syncMyFriendProfile() {
        // 友達機能が無効 (v1) の間は同期不要。本番で friends profile を作らない。
        guard AppFeatureFlags.friendsEnabled else { return }
        // 友達紹介の確定は profile 差分の有無に依存させない(GPT-5.5 監査: 既に初記録済みで
        // profile も最新のユーザーが後から招待コードを入力すると、下の「差分なし」early-return で
        // confirm に到達せず星/フリーズが付かなかった)。confirmFirstRecordIfNeeded は内部で
        // isSignedIn/hasReferrer を見るので profile 不在でも安全。
        if AppFeatureFlags.isReferralActive {
            let hasFirstRecord = viewModel.lifetimeStats.achievedDays >= 1
            Task { await referralStore.confirmFirstRecordIfNeeded(hasFirstRecord: hasFirstRecord) }
        }
        guard let current = friendsStore.profile else { return }
        let streak = viewModel.streak.currentStreak
        let achieved = viewModel.lifetimeStats.achievedDays
        let todayDone = viewModel.todayStatus.countsAsAchieved
        let weeklyStatuses = viewModel.statuses.map { $0.status }
        let weekly = weeklyStatuses.map { $0.countsAsAchieved }
        let minutes = viewModel.weeklySummary.totalDurationSeconds / 60
        let tier = CatRank(currentStreak: streak).rank
        let breed = UserCatPreferences.shared.myCat
        // 今日の活動 (カテゴリ/種目名/詳細=opt-in) と月次集計を記録から組み立てる。
        let activity = FriendSharedActivity.build(
            records: store.records, today: Date(), calendar: .mondayFirst,
            includeDetail: FriendSharingPreferences.shared.includeExerciseDetail)
        // 実データに変化が無ければ publish しない (lastUpdated は比較に含めない。
        // 含めると毎回必ず差分扱いになり無駄な書き込みが発生する: Codex 指摘)。
        // 種目詳細は id (UUID) が毎回変わるため detailSignature (名前/分/回数/セット) で比較。
        if current.currentStreak == streak,
           current.totalAchievedDays == achieved,
           current.todayAchieved == todayDone,
           current.weeklyAchievements == weekly,
           current.weeklyStatuses == weeklyStatuses,
           current.weeklyTotalMinutes == minutes,
           current.decorationTier == tier,
           current.myCatBreed == breed,
           current.todayCategoryName == activity.todayCategoryName,
           current.todayExerciseNames == activity.todayExerciseNames,
           Self.detailSignature(current.todayExerciseDetails) == Self.detailSignature(activity.todayExerciseDetails),
           current.monthlyTotalMinutes == activity.monthlyTotalMinutes,
           current.monthlyAchievedDays == activity.monthlyAchievedDays {
            return
        }
        var updated = current
        updated.currentStreak = streak
        updated.totalAchievedDays = achieved
        updated.todayAchieved = todayDone
        updated.weeklyAchievements = weekly
        updated.weeklyStatuses = weeklyStatuses
        updated.weeklyTotalMinutes = minutes
        updated.decorationTier = tier
        updated.myCatBreed = breed
        updated.todayCategoryName = activity.todayCategoryName
        updated.todayExerciseNames = activity.todayExerciseNames
        updated.todayExerciseDetails = activity.todayExerciseDetails
        updated.monthlyTotalMinutes = activity.monthlyTotalMinutes
        updated.monthlyAchievedDays = activity.monthlyAchievedDays
        updated.lastUpdated = Date()
        Task { await friendsStore.publishMyProfile(updated) }
    }
}

/// CatStateView の大型版 (280pt)。Phase 7.1 で装飾 overlay を撤去
/// (新キャラアートにヘッドバンド等が描き込み済みのため二重描画 → 顔の
/// 上に色のシミを残していた)。
/// - 丸枠の clipShape を外して `.scaledToFit` で表示することで、しっぽや
///   バンザイした手など円の外に出る要素が切れなくなる。背景 Circle は装飾
///   (光輪) として残す。
/// - breathing (scale) に加え、float (offset y) と微小 sway (rotation) を
///   合成して有機的な動きに。reduceMotion 設定時は全停止。
struct BigCatView: View {
    let state: CatState
    var useShaker: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var floating = false
    @State private var swaying = false

    var body: some View {
        let breed = UserCatPreferences.shared.myPet
        let resolved: String = useShaker
            ? breed.resolvedShakerAssetName { UIImage(named: $0) != nil }
            : (UIImage(named: breed.assetName(for: state)) != nil
               ? breed.assetName(for: state)
               : breed.fallbackAssetName(for: state))
        ZStack {
            // 達成背景は画面全体の MilestoneBackdrop に移行(猫裏の四角い画像カードは廃止)。
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
                    .catSilhouetteContrast() // 明/暗テーマ背景に溶けないよう輪郭を立てる
            } else {
                Text(state.emoji)
                    .font(.system(size: 120))
            }
        }
        .scaleEffect(reduceMotion ? 1 : (breathing ? 1.03 : 1))
        .offset(y: reduceMotion ? 0 : (floating ? -8 : 4))
        .rotationEffect(reduceMotion ? .zero : .degrees(swaying ? 2 : -2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("今日の猫: \(state.displayName)")
        .accessibilityHint("二本指でダブルタップすると反応します")
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
        case .weightLoss(let kg): return "weightLoss-\(kg)"
        }
    }
}
