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
    /// 「今月のハイライト」ボタンの active / disabled 判定。今月にいずれかの
    /// 記録があるかどうか。
    var currentMonthHasRecords = false

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
    /// 復活対象の missed 日(**refresh 時点の絶対日付**, startOfDay)。applyRevive はこれを使い、
    /// ポップ表示中に日付が変わっても offset 再変換でズレた日にフリーズを当てない(監査 F2)。
    private(set) var reviveMissedDates: [Date] = []
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

    /// 対象日の「その月」の allowance。紹介フリーズ加算は今月分の集計なので、月初の4日グレースで
    /// 前月の missed 日を復活するときは加算を載せない(GPT-5.5 監査: 復活ポップ経路でも現在月ボーナスを
    /// 前月へ流用できた件。RescueTicketUseView.allowance(for:) と対称)。
    private func allowance(for date: Date) -> Int {
        let inCurrentMonth = calendar.isDate(date, equalTo: dateProvider.currentDate(), toGranularity: .month)
        let bonus = inCurrentMonth ? referralFreezeBonus : 0
        return RescueTicketAllowance.current(isPremium: isPremium, referralBonus: bonus)
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
        // 履歴カレンダーと同じ表示ルール: 最初の記録(/救済日)より前の日は「休/×」でなく
        // 中立の「-」(.future 流用)。今日のセルは対象外(todayPending が CTA/猫状態の正本のため)。
        // progress は achieved 数のみ数えるので影響しない(表示層のみの振替)。
        let firstActivityDay = (records.map { calendar.startOfDay(for: $0.date) }
            + rescued.map { calendar.startOfDay(for: $0) }).min()
        statuses = statuses.map { entry in
            let day = calendar.startOfDay(for: entry.date)
            guard !calendar.isDate(day, inSameDayAs: today), day < today else { return entry }
            let beforeStart = firstActivityDay.map { day < $0 } ?? true
            guard beforeStart else { return entry }
            return DailyStatusEntry(date: entry.date, status: .future, recordIds: entry.recordIds)
        }
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
        currentMonthHasRecords = Self.hasCurrentMonthRecords(records: records, today: today, calendar: calendar)
        isComebackToday = yesterdayStatus(records: records, today: today) == .missed
            && !todayStatus.countsAsAchieved
            && lifetimeStats.achievedDays >= 3
        // 復活ウィンドウ(4日グレース)。残枠は月次 allowance から算出。
        let reviveRemaining = rescueTicketStore.remainingTickets(today: today, allowance: rescueAllowance)
        let reviveRescued = rescueTicketStore.rescuedDates()
        let window = StreakFreezeWindow.evaluate(
            records: records, today: today, rescuedDates: reviveRescued,
            remainingFreezes: reviveRemaining, calendar: calendar)
        if window.revivable {
            let missed = StreakFreezeWindow.missedDates(forOffsets: window.missedOffsets, today: today, calendar: calendar)
            // hasEnough は「各 missed 日をその日の月の allowance で順に消費できるか」を厳密判定する。
            // remainingTickets(today) は今日の月だけを見るため、月境界の missed 日で過大/過小評価する(Codex/Gemini監査)。
            let monthAwareEnough = canReviveAll(missed: missed, rescued: reviveRescued)
            reviveWindow = StreakFreezeWindow.Result(
                revivable: true, missedOffsets: window.missedOffsets,
                freezesNeeded: window.freezesNeeded, hasEnough: monthAwareEnough)
            reviveMissedDates = missed.map { calendar.startOfDay(for: $0) }
            let hypothetical = reviveRescued.union(reviveMissedDates)
            potentialReviveStreak = restoredStreakLength(
                records: records, hypothetical: hypothetical, today: today, missed: missed)
        } else {
            reviveWindow = nil
            reviveMissedDates = []
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
        // DateInterval.contains は終端(=今月1日 0:00)を含むため、今月1日付の record が
        // 先月扱いになる off-by-one を避け、半開区間 [start, end) で判定する(監査 P2)。
        return records.contains { interval.start <= $0.date && $0.date < interval.end }
    }

    private static func hasCurrentMonthRecords(records: [WorkoutRecord], today: Date, calendar: Calendar) -> Bool {
        guard let interval = calendar.dateInterval(of: .month, for: today) else { return false }
        // 半開区間 [start, end) で今月の record 有無を判定(翌月1日 0:00 を含めない)。
        return records.contains { interval.start <= $0.date && $0.date < interval.end }
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
        // refresh 時点の絶対 missed 日を使う。offset を今の today で再変換すると、ポップ表示中に
        // 日付が変わったとき別の日へフリーズを当ててしまう(監査 F2)。
        let missed = reviveMissedDates
        guard !missed.isEmpty else { return nil }
        var applied = 0
        for day in missed {
            if rescueTicketStore.useTicket(on: day, allowance: allowance(for: day)) { applied += 1 }
        }
        guard applied == missed.count else { return nil }
        return CatRank(currentStreak: potentialReviveStreak)
    }

    /// 復活対象 break の識別キー(refresh 時点の missed 日から導出)。HomeView の
    /// 提示済み判定/handled 記録を、offset+その時の today 再計算ではなくこの安定キーで揃える(F2)。
    var reviveBreakKey: String? {
        ReviveDismissStore.breakKey(missedDates: reviveMissedDates, calendar: calendar)
    }

    /// missed 日すべてを **各日の月の allowance** で順に(累積で)消費できるか。
    /// `useTicket(on:)` が missed 日の月で課金するため、今日の月だけの remainingTickets では
    /// 月境界で誤判定する。実際の消費をシミュレートして hasEnough を厳密化する(Codex/Gemini監査)。
    private func canReviveAll(missed: [Date], rescued: Set<Date>) -> Bool {
        var sim = rescued
        for raw in missed {
            let day = calendar.startOfDay(for: raw)
            if sim.contains(day) { return false } // 既に救済済み(通常あり得ない)
            let usedInMonth = sim.filter { calendar.isDate($0, equalTo: day, toGranularity: .month) }.count
            // 各 missed 日は「その日の月」の allowance で課金する(applyRevive の useTicket と対称)。
            if usedInMonth >= allowance(for: day) { return false }
            sim.insert(day)
        }
        return true
    }

    /// 復活で「守られる連続日数」。`StreakCalculator.currentStreak` は今日を起点にすると
    /// 今日が todayPending の場合 0 を返す(=未達成の今朝は連続0扱い)ため使えない。
    /// 代わりに **最新 missed 日(橋渡し後に過去日として achieved 扱いになる)** を起点に
    /// 後方へ achieved/rescued を数える(rest は連続を切らず加算もしない)。`today` は実際の
    /// 今日を渡し、起点を過去日にすることで rescuedDates が効くようにする。
    private func restoredStreakLength(records: [WorkoutRecord], hypothetical: Set<Date>, today: Date, missed: [Date]) -> Int {
        let todayStart = calendar.startOfDay(for: today)
        // 今日が既に達成済みなら **今日起点**(今日 + 橋渡しした gap + 手前を全部数える)。
        // 今日未達成(todayPending)なら最新 missed 日起点(今日を起点にすると 0 を返すため)。
        // Codex/Gemini監査: 旧実装は常に最新 missed 起点で、今日達成済みのとき今日分を取りこぼしていた。
        let todayStatus = AchievementEvaluator.dailyStatus(
            for: todayStart, records: records,
            restDays: RestDayResolver.restDaySet(for: todayStart, records: records, today: todayStart, calendar: calendar),
            rescuedDates: hypothetical, today: todayStart, calendar: calendar)
        let start: Date
        if todayStatus == .todayAchieved {
            start = todayStart
        } else if let latestMissed = missed.map({ calendar.startOfDay(for: $0) }).max() {
            start = latestMissed
        } else {
            return 0
        }
        var count = 0
        var cursor = start
        while true {
            let restDays = RestDayResolver.restDaySet(for: cursor, records: records, today: today, calendar: calendar)
            let status = AchievementEvaluator.dailyStatus(
                for: cursor, records: records, restDays: restDays,
                rescuedDates: hypothetical, today: today, calendar: calendar)
            switch status {
            case .achieved, .todayAchieved, .rescued:
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
