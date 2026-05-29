import XCTest
@testable import GOExercise

final class WidgetSnapshotFactoryTests: XCTestCase {
    private let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        var components = DateComponents()
        components.year = y; components.month = m; components.day = d
        components.hour = h; components.minute = min
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: components) ?? Date()
    }

    func testMakeCarriesAllFieldsThrough() {
        let now = date(2026, 5, 24, 10, 0)
        let snapshot = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: true,
            isRestDay: false,
            currentStreak: 12,
            weeklyAchieved: 5,
            weeklyTotal: 7,
            catState: .celebrating,
            message: "今日も達成！",
            calendar: calendar
        )

        XCTAssertEqual(snapshot.generatedAt, now)
        XCTAssertEqual(snapshot.todayAchieved, true)
        XCTAssertEqual(snapshot.isRestDay, false)
        XCTAssertEqual(snapshot.currentStreak, 12)
        XCTAssertEqual(snapshot.weeklyAchieved, 5)
        XCTAssertEqual(snapshot.weeklyTotal, 7)
        XCTAssertEqual(snapshot.catState, CatState.celebrating.rawValue)
        XCTAssertEqual(snapshot.message, "今日も達成！")
    }

    func testNightDeadlineHoursLeftAtTenAMIs13() {
        let now = date(2026, 5, 24, 10, 0)
        let snapshot = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: false,
            isRestDay: false,
            currentStreak: 0,
            weeklyAchieved: 0,
            weeklyTotal: 7,
            catState: .waitingMorning,
            message: "",
            calendar: calendar
        )
        // 23:59 - 10:00 → 13h 59m → component(.hour) = 13
        XCTAssertEqual(snapshot.nightDeadlineHoursLeft, 13)
    }

    func testNightDeadlineHoursLeftIsZeroAfter2300() {
        let now = date(2026, 5, 24, 23, 30)
        let snapshot = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: false,
            isRestDay: false,
            currentStreak: 0,
            weeklyAchieved: 0,
            weeklyTotal: 7,
            catState: .beggingNight,
            message: "",
            calendar: calendar
        )
        // 23:59 - 23:30 = 29 minutes → component(.hour) = 0
        XCTAssertEqual(snapshot.nightDeadlineHoursLeft, 0)
    }

    func testCodableRoundTripPreservesData() throws {
        let now = date(2026, 5, 24, 10, 0)
        let original = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: true,
            isRestDay: false,
            currentStreak: 30,
            weeklyAchieved: 7,
            weeklyTotal: 7,
            catState: .streakExtended,
            message: "30日連続!",
            calendar: calendar
        )
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: encoded)
        XCTAssertEqual(decoded, original)
    }

    func testFallbackSnapshotIsSafeDefault() {
        let fallback = SharedSnapshotStore.fallbackSnapshot(
            now: date(2026, 5, 24, 10, 0),
            calendar: calendar
        )
        XCTAssertEqual(fallback.currentStreak, 0)
        XCTAssertEqual(fallback.weeklyAchieved, 0)
        XCTAssertEqual(fallback.weeklyTotal, 7)
        XCTAssertFalse(fallback.todayAchieved)
        XCTAssertFalse(fallback.isRestDay)
        XCTAssertEqual(fallback.catState, CatState.waitingMorning.rawValue)
        XCTAssertFalse(fallback.message.isEmpty)
    }

    func testCatStateRawValueRoundTrip() {
        for state in [CatState.waitingMorning, .worriedNoon, .beggingNight,
                      .celebrating, .streakExtended, .resting, .encouraging] {
            let snapshot = WidgetSnapshot.make(
                generatedAt: Date(),
                todayAchieved: false,
                isRestDay: false,
                currentStreak: 0,
                weeklyAchieved: 0,
                weeklyTotal: 7,
                catState: state,
                message: "x",
                calendar: calendar
            )
            XCTAssertEqual(CatState(rawValue: snapshot.catState), state, "round-trip for \(state)")
        }
    }
}
