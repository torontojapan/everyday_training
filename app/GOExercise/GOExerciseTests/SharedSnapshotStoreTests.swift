import Foundation
import XCTest
@testable import GOExercise

final class SharedSnapshotStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "test.shared.snapshot.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testWriteThenReadRoundTripsSnapshot() {
        let store = SharedSnapshotStore(defaults: defaults)
        let snapshot = makeSnapshot(todayAchieved: true, currentStreak: 5)

        XCTAssertTrue(store.write(snapshot))

        XCTAssertEqual(store.read(), snapshot)
    }

    func testReadReturnsFallbackWhenDataIsMissing() {
        let store = SharedSnapshotStore(defaults: defaults)

        let snapshot = store.read()

        XCTAssertFalse(snapshot.todayAchieved)
        XCTAssertEqual(snapshot.weeklyTotal, 7)
        XCTAssertEqual(snapshot.catState, CatState.waitingMorning.rawValue)
    }

    func testReadReturnsFallbackWhenDataIsCorrupt() {
        defaults.set(Data([0, 1, 2]), forKey: SharedSnapshotStore.snapshotKey)
        let store = SharedSnapshotStore(defaults: defaults)

        let snapshot = store.read()

        XCTAssertEqual(snapshot.message, "今日の運動、まだ待ってるよ")
    }

    func testEncodedSnapshotKeepsCatStateRawValue() throws {
        let snapshot = makeSnapshot(catState: .beggingNight)

        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)

        XCTAssertEqual(decoded.catState, "beggingNight")
    }

    func testNightDeadlineHoursLeftIsClampedBySnapshotFactory() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 20, hour: 23, minute: 30))!

        let snapshot = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: false,
            isRestDay: false,
            currentStreak: 2,
            weeklyAchieved: 3,
            weeklyTotal: 7,
            catState: .beggingNight,
            message: "あと少しで今日の記録が残せるよ",
            calendar: calendar
        )

        XCTAssertEqual(snapshot.nightDeadlineHoursLeft, 0)
    }

    private var calendar: Calendar {
        Calendar.mondayFirst
    }

    private func makeSnapshot(
        todayAchieved: Bool = false,
        currentStreak: Int = 1,
        catState: CatState = .waitingMorning
    ) -> WidgetSnapshot {
        WidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_777_000_000),
            todayAchieved: todayAchieved,
            isRestDay: false,
            currentStreak: currentStreak,
            weeklyAchieved: 4,
            weeklyTotal: 7,
            catState: catState.rawValue,
            message: "今日の運動、まだ待ってるよ",
            nightDeadlineHoursLeft: 5
        )
    }
}
