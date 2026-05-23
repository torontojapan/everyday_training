import Foundation
import UserNotifications
import XCTest
@testable import CerealExercise

@MainActor
final class NotificationSchedulerTests: XCTestCase {
    func testScheduleDailyAddsDefaultMorningAndEveningRequests() async {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(center: center)

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 3, weeklyProgressRate: 0.5)

        XCTAssertEqual(center.added.map(\.identifier), ["notif.morning", "notif.evening"])
        XCTAssertEqual(center.removedIdentifiers, ["notif.morning", "notif.evening"])
    }

    func testScheduleDailyUsesConfiguredTimes() async {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(
            center: center,
            settings: NotificationSettings(
                isEnabled: true,
                morning: NotificationTime(hour: 7, minute: 15),
                evening: NotificationTime(hour: 21, minute: 45)
            )
        )

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 0, weeklyProgressRate: 0.2)

        XCTAssertEqual(center.added.map(\.hour), [7, 21])
        XCTAssertEqual(center.added.map(\.minute), [15, 45])
    }

    func testScheduleDailyCancelsWithoutAddingWhenDisabled() async {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(center: center, settings: NotificationSettings(isEnabled: false))

        await scheduler.scheduleDaily(todayAchieved: false, currentStreak: 0, weeklyProgressRate: 0.1)

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, ["notif.morning", "notif.evening"])
    }

    func testScheduleDailyCancelsWithoutAddingWhenTodayAchieved() async {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(center: center)

        await scheduler.scheduleDaily(todayAchieved: true, currentStreak: 4, weeklyProgressRate: 0.8)

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, ["notif.morning", "notif.evening"])
    }

    func testCancelTodayRemovesBothDailyNotificationIdentifiers() {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(center: center)

        scheduler.cancelToday()

        XCTAssertEqual(center.removedIdentifiers, ["notif.morning", "notif.evening"])
    }

    func testRescheduleAfterAchievementCancelsToday() async {
        let center = NotificationSchedulingCenterSpy()
        let scheduler = NotificationScheduler(center: center)

        await scheduler.rescheduleAfterAchievement(currentStreak: 7, weeklyProgressRate: 1)

        XCTAssertTrue(center.added.isEmpty)
        XCTAssertEqual(center.removedIdentifiers, ["notif.morning", "notif.evening"])
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
}
