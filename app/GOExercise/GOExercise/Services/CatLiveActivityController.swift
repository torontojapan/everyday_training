import ActivityKit
import Foundation
import OSLog

private let liveActivityLogger = Logger(subsystem: "com.goexercise.app", category: "LiveActivity")

/// Phase 7.0 Step 4: Live Activity を 1 つだけ常駐させるコントローラ。
///
/// 注意: Live Activity の寿命はシステムにより最長 8h (active) + 4h (ended/dismiss
/// 待ち) に制限される。「1 日中いる」体験は完全には作れないため、アプリを
/// 開くたび / scenePhase active のたびに start し直す方針で、なるべく
/// ユーザーの目につく時間帯にロック画面に居続けられるようにする。
@MainActor
final class CatLiveActivityController {
    static let shared = CatLiveActivityController()

    private init() {}

    /// 直近に書いた ContentState。冗長な update を抑止するためのキャッシュ。
    private var lastState: CatActivityAttributes.ContentState?

    /// 既存 activity があれば update、無ければ start。同時に 1 つだけ動かす。
    /// 同じ state なら何もしない (Update Budget 浪費防止)。
    func ensureRunning(state: CatActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            liveActivityLogger.info("Live Activity disabled by user")
            return
        }
        if lastState == state, Activity<CatActivityAttributes>.activities.contains(where: { _ in true }) {
            return
        }

        // 日付をまたいだ古い activity は明示的に end してから再 start する。
        // staleDate を渡しても自動 dismiss はされないため。
        endExpiredActivities()

        let stale = Self.endOfDay()
        if Activity<CatActivityAttributes>.activities.first != nil {
            let captured = state
            Task { @MainActor in
                guard let existing = Activity<CatActivityAttributes>.activities.first else { return }
                await existing.update(.init(state: captured, staleDate: stale))
                liveActivityLogger.info("Updated existing Live Activity")
            }
            lastState = state
            return
        }

        do {
            let attributes = CatActivityAttributes(startedAt: Date())
            let content = ActivityContent(state: state, staleDate: stale)
            let activity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            liveActivityLogger.info("Started new Live Activity \(activity.id, privacy: .public)")
            lastState = state
        } catch {
            liveActivityLogger.error("Failed to start Live Activity: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// 全 activity を停止する (主に signout / debug 用)。
    func stopAll() {
        Task { @MainActor in
            for activity in Activity<CatActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        lastState = nil
    }

    /// startedAt が当日でない activity を end する。0:00 跨ぎ後のクリーンアップ用。
    private func endExpiredActivities() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let staleIds = Activity<CatActivityAttributes>.activities
            .filter { !cal.isDate($0.attributes.startedAt, inSameDayAs: today) }
            .map(\.id)
        guard !staleIds.isEmpty else { return }
        Task { @MainActor in
            for activity in Activity<CatActivityAttributes>.activities where staleIds.contains(activity.id) {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// 当日 23:59:59 を返す。staleDate (= 表示が old 扱いになる境界) として使う。
    private static func endOfDay(now: Date = Date()) -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? now
    }

    /// 現在の WorkoutStore 状態から ContentState を組み立てるヘルパー。
    static func makeState(
        records: [WorkoutRecord],
        today: Date,
        catBreed: CatBreed,
        rescuedDates: Set<Date> = [],
        calendar: Calendar = .mondayFirst
    ) -> CatActivityAttributes.ContentState {
        let restDays = RestDayResolver.restDaySet(for: today, records: records, today: today, calendar: calendar)
        // 保険チケット救済日も達成扱いにするため rescuedDates を渡す。これが無いと
        // Live Activity の連続日数 / 当日達成判定がアプリ本体と食い違う (3 LLM 監査)。
        let status = AchievementEvaluator.dailyStatus(
            for: today,
            records: records,
            restDays: restDays,
            rescuedDates: rescuedDates,
            today: today,
            calendar: calendar
        )
        let streak = StreakCalculator.currentStreak(records: records, today: today, rescuedDates: rescuedDates, calendar: calendar)
        // 今週ストリップ(月→日の7日)。ロック画面の肉球+グラフ表示に使う。
        let weekStatuses = WeeklyProgressCalculator.statuses(
            forWeekContaining: today, records: records, today: today,
            rescuedDates: rescuedDates, calendar: calendar
        )
        let weekProgress = WeeklyProgressCalculator.progress(from: weekStatuses)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: today) ?? Date()
        let hoursLeft = max(0, calendar.dateComponents([.hour], from: Date(), to: endOfDay).hour ?? 0)
        let catState = CatStateResolver.resolve(
            todayStatus: status,
            now: Date(),
            yesterdayAchieved: true,
            streakExtendedThisRun: false,
            calendar: calendar
        )
        return .init(
            todayAchieved: status.countsAsAchieved,
            currentStreak: streak,
            hoursLeftToday: hoursLeft,
            catStateRaw: catState.rawValue,
            catBreedRaw: catBreed.rawValue,
            weeklyAchieved: weekProgress.achievedCount,
            weeklyTotal: weekProgress.totalDays,
            weeklyStatusesRaw: weekStatuses.map { $0.status.rawValue }
        )
    }
}
