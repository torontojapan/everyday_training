import Foundation
import Observation

@MainActor
@Observable
final class HomeViewModel {
    private let calendar: Calendar
    private let dateProvider: any DateProviding

    var statuses: [DailyStatusEntry] = []
    var progress = WeeklyProgress(achievedCount: 0, totalDays: 7)
    var streak = StreakState(currentStreak: 0, longestStreak: 0, lastAchievedDate: nil)
    var todayStatus: DailyStatus = .todayPending
    var todaySummary = ExerciseTrendSummary.DailySummary(categoryCounts: [:], exerciseCount: 0, totalDurationSeconds: 0)
    var weeklySummary = ExerciseTrendSummary.WeeklySummary(usedCategories: [], totalDurationSeconds: 0, topExerciseNames: [])
    var catMessage = CatMessage(emoji: "🐱", text: "今日も1分だけやってみよ？")
    var catState: CatState = .waitingMorning
    var streakExtendedThisRun = false
    var lifetimeStats = LifetimeStatsCalculator.Stats(achievedDays: 0, usedDays: 1)
    var rescueTicketAvailable = true
    var pendingMilestone: Milestone?
    var firstUseDate: Date = Date()
    /// 「先月のレビュー」ボタンを active / disabled で出し分けるために、
    /// 前月にいずれかの記録があるかどうかを保持する。
    var previousMonthHasRecords = false

    /// 「復帰ファーストホーム」を出すかどうか (Codex UX 提案 #2)。
    /// 判定条件 (3 つすべて true):
    /// - **昨日の status が `.missed`**: 単に streak が 0 ではなく、rest day や
    ///   rescue ticket での救済も効かなかった真の取りこぼし日
    /// - 今日まだ達成していない
    /// - 累計達成日 >= 3 (= 習慣を持っていた経験あり)
    /// 朝起きて未記録でも、昨日達成済みなら通常 UI のまま。
    var isComebackToday: Bool = false
    /// 復活ウィンドウ(nil=対象外)。HomeView がポップ提示判定に使う。
    var reviveWindow: StreakFreezeWindow.Result?
    /// 復活したら到達する連続日数(ポップのコピー「連続◯日」に使用)。
    var potentialReviveStreak: Int = 0
    private let usageTracker = LifetimeUsageTracker()
    private let rescueTicketStore: RescueTicketStore
    private let milestoneDetector: MilestoneDetector
    /// GOプレミアム加入状況。フリーズ付与枚数 (月1 or 月4) の判定に使う。
    /// refresh() で View 側から最新値を渡してもらう。
    private var isPremium = false
    /// 今月の紹介フリーズ加算。refresh() で View から渡される。
    private var referralFreezeBonus = 0

    private var rescueAllowance: Int {
        RescueTicketAllowance.current(isPremium: isPremium, referralBonus: referralFreezeBonus)
    }

    init(dateProvider: any DateProviding = SystemDateProvider(),
         calendar: Calendar = .mondayFirst,
         rescueTicketStore: RescueTicketStore = .shared,
         milestoneDetector: MilestoneDetector? = nil) {
        self.dateProvider = dateProvider
        self.calendar = calendar
        self.rescueTicketStore = rescueTicketStore
        self.milestoneDetector = milestoneDetector ?? MilestoneDetector()
    }

    func refresh(records: [WorkoutRecord],
                  streakExtendedThisRun: Bool = false,
                  weightLoss: MilestoneDetector.WeightLossSnapshot? = nil,
                  isPremium: Bool = false,
                  referralFreezeBonus: Int = 0,
                  anchorDate: Date? = nil) {
        self.isPremium = isPremium
        self.referralFreezeBonus = referralFreezeBonus
        // 呼び出し側が `anchorDate` を指定すれば、内部 dateProvider ではなく
        // その瞬間を全集計の基準日として使う。日跨ぎ atomic 化のため
        // (Codex round5: 別ソース読みによる drift を排除)。
        let now = anchorDate ?? dateProvider.currentDate()
        let today = calendar.startOfDay(for: now)
        // 保険チケット救済日を全集計に反映する。週カレンダー/週次進捗/streak が
        // 履歴タブの月次カレンダー (rescue 反映済み) と一致するようにするため
        // (3 LLM 監査 A-Major: 旧コードは rescue を渡さず内部矛盾していた)。
        let rescued = rescueTicketStore.rescuedDates()
        statuses = WeeklyProgressCalculator.statuses(forWeekContaining: today, records: records, today: today, rescuedDates: rescued, calendar: calendar)
        progress = WeeklyProgressCalculator.progress(from: statuses)
        streak = StreakCalculator.streakState(records: records, today: today, rescuedDates: rescued, calendar: calendar)
        todayStatus = statuses.first { calendar.isDate($0.date, inSameDayAs: today) }?.status ?? .todayPending
        todaySummary = ExerciseTrendSummary.today(records: records, today: today, calendar: calendar)
        if let week = calendar.dateInterval(of: .weekOfYear, for: today) {
            weeklySummary = ExerciseTrendSummary.week(records: records, week: week, calendar: calendar)
        } else {
            weeklySummary = ExerciseTrendSummary.WeeklySummary(usedCategories: [], totalDurationSeconds: 0, topExerciseNames: [])
        }
        self.streakExtendedThisRun = streakExtendedThisRun && streak.currentStreak > 1
        catState = CatStateResolver.resolve(
            todayStatus: todayStatus,
            now: now,
            yesterdayAchieved: yesterdayAchieved(records: records, today: today),
            streakExtendedThisRun: self.streakExtendedThisRun,
            calendar: calendar
        )
        catMessage = CatMessageProvider.message(for: catState, seedDate: today, calendar: calendar)
        let firstUse = usageTracker.firstUseDate(records: records, fallback: today)
        firstUseDate = firstUse
        lifetimeStats = LifetimeStatsCalculator.calculate(
            records: records,
            firstUseDate: firstUse,
            today: today,
            calendar: calendar
        )
        rescueTicketAvailable = rescueTicketStore.hasTicketAvailable(today: today, allowance: rescueAllowance)
        pendingMilestone = milestoneDetector.nextPending(
            records: records,
            firstUseDate: firstUse,
            today: today,
            lifetimeAchieved: lifetimeStats.achievedDays,
            currentStreak: streak.currentStreak,
            weightLoss: weightLoss
        )
        previousMonthHasRecords = Self.hasPreviousMonthRecords(records: records, today: today, calendar: calendar)
        isComebackToday = yesterdayStatus(records: records, today: today) == .missed
            && !todayStatus.countsAsAchieved
            && lifetimeStats.achievedDays >= 3
        // 復活ウィンドウ(4日グレース)。残枠は月次 allowance から算出。
        let reviveRemaining = rescueTicketStore.remainingTickets(today: today, allowance: rescueAllowance)
        let reviveRescued = rescueTicketStore.rescuedDates()
        let window = StreakFreezeWindow.evaluate(
            records: records, today: today, rescuedDates: reviveRescued,
            remainingFreezes: reviveRemaining, calendar: calendar)
        reviveWindow = window.revivable ? window : nil
        if window.revivable {
            let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
            let hypothetical = reviveRescued.union(missed.map { calendar.startOfDay(for: $0) })
            potentialReviveStreak = restoredStreakLength(
                records: records, hypothetical: hypothetical, today: today, missed: missed)
        } else {
            potentialReviveStreak = 0
        }
    }

    /// 昨日の DailyStatus (rest day **+ rescue ticket** 自動補完を込みで評価)。
    /// 復帰モード判定で「真に missed か」を確定するため。
    /// Codex round1 priority 1: rescuedDates を渡さないと、ticket で救済済の
    /// 日も .missed 扱いになり comeback 表示が誤発火していた。
    private func yesterdayStatus(records: [WorkoutRecord], today: Date) -> DailyStatus {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return .future
        }
        let restDays = RestDayResolver.restDaySet(for: yesterday, records: records, today: today, calendar: calendar)
        let rescued = rescueTicketStore.rescuedDates()
        return AchievementEvaluator.dailyStatus(
            for: yesterday,
            records: records,
            restDays: restDays,
            rescuedDates: rescued,
            today: today,
            calendar: calendar
        )
    }

    private static func hasPreviousMonthRecords(records: [WorkoutRecord], today: Date, calendar: Calendar) -> Bool {
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: today),
              let interval = calendar.dateInterval(of: .month, for: previousMonth) else {
            return false
        }
        return records.contains { interval.contains($0.date) }
    }

    func acknowledgeMilestone(_ milestone: Milestone) {
        milestoneDetector.acknowledge(milestone)
        pendingMilestone = nil
    }

    func useRescueTicketToday() -> Bool {
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        let used = rescueTicketStore.useTicket(on: today, allowance: rescueAllowance)
        rescueTicketAvailable = rescueTicketStore.hasTicketAvailable(today: today, allowance: rescueAllowance)
        return used
    }

    /// 「昨日達成済みか」を rescue ticket 補完込みで判定。
    /// `yesterdayStatus` と同じパスを使って isComebackToday と catState の
    /// 判断が一致するようにする (Codex round2 priority 1)。
    private func yesterdayAchieved(records: [WorkoutRecord], today: Date) -> Bool {
        yesterdayStatus(records: records, today: today).countsAsAchieved
    }

    var reviveRemainingFreezes: Int {
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        return rescueTicketStore.remainingTickets(today: today, allowance: rescueAllowance)
    }

    /// 復活ウィンドウの missed 日すべてにフリーズを適用し、連続を復活させる。
    /// - Returns: 復活後の `CatRank`(復活演出用)。適用不可(枠不足/window無)なら nil。
    @discardableResult
    func applyRevive() -> CatRank? {
        guard let window = reviveWindow, window.hasEnough else { return nil }
        let today = calendar.startOfDay(for: dateProvider.currentDate())
        let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
        var applied = 0
        for day in missed {
            if rescueTicketStore.useTicket(on: day, allowance: rescueAllowance) { applied += 1 }
        }
        guard applied == missed.count else { return nil }
        return CatRank(currentStreak: potentialReviveStreak)
    }

    /// 復活で「守られる連続日数」。`StreakCalculator.currentStreak` は今日を起点にすると
    /// 今日が todayPending の場合 0 を返す(=未達成の今朝は連続0扱い)ため使えない。
    /// 代わりに **最新 missed 日(橋渡し後に過去日として achieved 扱いになる)** を起点に
    /// 後方へ achieved/rescued を数える(rest は連続を切らず加算もしない)。`today` は実際の
    /// 今日を渡し、起点を過去日にすることで rescuedDates が効くようにする。
    private func restoredStreakLength(records: [WorkoutRecord], hypothetical: Set<Date>, today: Date, missed: [Date]) -> Int {
        guard let start = missed.map({ calendar.startOfDay(for: $0) }).max() else { return 0 }
        var count = 0
        var cursor = start
        while true {
            let restDays = RestDayResolver.restDaySet(for: cursor, records: records, today: today, calendar: calendar)
            let status = AchievementEvaluator.dailyStatus(
                for: cursor, records: records, restDays: restDays,
                rescuedDates: hypothetical, today: today, calendar: calendar)
            switch status {
            case .achieved, .todayAchieved:
                count += 1
            case .rest:
                break // skip — 連続は切らないが加算もしない
            default:
                return count // .missed / .todayPending / .future で停止
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { return count }
            cursor = prev
        }
    }
}
