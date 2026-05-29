import Foundation
import UserNotifications
import XCTest
@testable import GOExercise

@MainActor
final class NotificationSchedulerTests: XCTestCase {
    private let cal: Calendar = .mondayFirst

    /// 2026-05-01 06:00。朝(8:30)/夕(20:00) いずれも「今日」のこの時刻より後なので
    /// today 分もスケジュールされる (one-shot で過去時刻はスキップされるため固定する)。
    private func fixedNow() -> Date {
        cal.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 6, minute: 0))!
    }

    private func makeScheduler(settings: NotificationSettings = NotificationSettings(),
                               spy: NotificationSchedulingCenterSpy) -> NotificationScheduler {
        NotificationPersonalityPreferences.shared.current = .voice
        return NotificationScheduler(
            center: spy,
            settings: settings,
            dateProvider: FixedDateProvider(date: fixedNow()),
            calendar: cal
        )
    }

    private func dayString(addingDays days: Int) -> String {
        let d = cal.date(byAdding: .day, value: days, to: fixedNow())!
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func testScheduleDailyAddsRollingWindowForMorningAndEvening() async {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(spy: spy)

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 3, weeklyProgressRate: 0.5)

        // 今日 + 翌日以降 rollingDays 日 = (rollingDays+1) 日分 × (朝 + 夕)。
        // (fixedNow=06:00 なので今日の朝/夕とも未来 → 今日分も含まれる)
        XCTAssertEqual(spy.added.count, (NotificationScheduler.rollingDays + 1) * 2)
        // 今日分も将来分 (day+7) も含まれる。
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: 0))"))
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.evening.\(dayString(addingDays: 0))"))
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: NotificationScheduler.rollingDays))"))
        // rebuild なので全消去が先に走る。
        XCTAssertTrue(spy.removedAll)
    }

    /// B-Major-2 回帰テスト: 今日達成しても **翌日以降の通知は残る**。
    /// (旧 repeats:true + cancelToday は将来分も消していた)
    func testTodayAchievedSkipsTodayButKeepsFutureDays() async {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(spy: spy)

        await scheduler.scheduleDaily(todayAchieved: true, currentStreak: 5, weeklyProgressRate: 0.9)

        // 今日分は無い。
        XCTAssertFalse(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: 0))"))
        XCTAssertFalse(spy.addedIdentifiers.contains("notif.evening.\(dayString(addingDays: 0))"))
        // 翌日以降は残り、今日をスキップしても将来 rollingDays 日分のカバレッジを保つ。
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: 1))"))
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.evening.\(dayString(addingDays: NotificationScheduler.rollingDays))"))
        // 将来 7 日分 × 2 = 14 件 (off-by-one 修正で今日スキップ分を 1 日延長)。
        XCTAssertEqual(spy.added.count, NotificationScheduler.rollingDays * 2)
    }

    func testScheduleDailyUsesConfiguredTimes() async {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(
            settings: NotificationSettings(
                isEnabled: true,
                morning: NotificationTime(hour: 7, minute: 15),
                evening: NotificationTime(hour: 21, minute: 45)
            ),
            spy: spy
        )

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 0, weeklyProgressRate: 0.2)

        // 最初の 2 件 (今日の朝・夕) の時刻が設定どおり。
        XCTAssertEqual(spy.added.first(where: { $0.identifier.contains("morning") })?.hour, 7)
        XCTAssertEqual(spy.added.first(where: { $0.identifier.contains("morning") })?.minute, 15)
        XCTAssertEqual(spy.added.first(where: { $0.identifier.contains("evening") })?.hour, 21)
        XCTAssertEqual(spy.added.first(where: { $0.identifier.contains("evening") })?.minute, 45)
    }

    func testScheduleDailyClearsWithoutAddingWhenDisabled() async {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(settings: NotificationSettings(isEnabled: false), spy: spy)

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 0, weeklyProgressRate: 0.1)

        XCTAssertTrue(spy.added.isEmpty)
        XCTAssertTrue(spy.removedAll, "無効時も保留分は全消去される")
    }

    func testCancelTodayRemovesOnlyTodaysIdentifiers() {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(spy: spy)

        scheduler.cancelToday()

        XCTAssertEqual(spy.removedIdentifiers, [
            "notif.morning.\(dayString(addingDays: 0))",
            "notif.evening.\(dayString(addingDays: 0))"
        ])
    }

    func testRescheduleAfterAchievementKeepsFutureDays() async {
        let spy = NotificationSchedulingCenterSpy()
        let scheduler = makeScheduler(spy: spy)

        await scheduler.rescheduleAfterAchievement(currentStreak: 7, weeklyProgressRate: 1)

        // 今日分は出さず、翌日以降は残す。
        XCTAssertFalse(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: 0))"))
        XCTAssertTrue(spy.addedIdentifiers.contains("notif.morning.\(dayString(addingDays: 1))"))
    }
}

private final class NotificationSchedulingCenterSpy: NotificationScheduling, @unchecked Sendable {
    struct AddedRequest {
        let identifier: String
        let hour: Int?
        let minute: Int?
    }

    private(set) var added: [AddedRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var removedAll = false

    var addedIdentifiers: [String] { added.map(\.identifier) }

    func add(_ request: UNNotificationRequest) async throws {
        let trigger = request.trigger as? UNCalendarNotificationTrigger
        added.append(
            AddedRequest(
                identifier: request.identifier,
                hour: trigger?.dateComponents.hour,
                minute: trigger?.dateComponents.minute
            )
        )
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPendingNotificationRequests() {
        removedAll = true
    }
}
