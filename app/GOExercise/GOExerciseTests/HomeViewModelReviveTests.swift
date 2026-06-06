import XCTest
@testable import GOExercise

@MainActor
final class HomeViewModelReviveTests: XCTestCase {
    private let cal: Calendar = .mondayFirst
    private func rec(_ daysAgo: Int, from today: Date) -> WorkoutRecord {
        WorkoutRecord(date: cal.date(byAdding: .day, value: -daysAgo, to: today)!, category: .strength,
                      exercises: [ExerciseItem(id: UUID(), name: "スクワット", durationSeconds: 120, reps: nil, sets: nil, memo: nil)],
                      memo: nil, calendar: cal)
    }
    private func saturday() -> Date {
        var d = cal.startOfDay(for: Date()); for _ in 0...7 { if cal.component(.weekday, from: d) == 7 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }; return d
    }
    func test_reviveWindow_published_andApply_restoresStreak() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (2...9).map { rec($0, from: today) }
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertNotNil(vm.reviveWindow)
        XCTAssertEqual(vm.reviveWindow?.freezesNeeded, 1)
        XCTAssertTrue(vm.reviveWindow?.hasEnough == true)
        let rank = vm.applyRevive()
        XCTAssertNotNil(rank)
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertGreaterThan(vm.streak.currentStreak, 0)
        XCTAssertNil(vm.reviveWindow, "復活後は window 解消")
    }
    func test_noWindow_whenStreakIntact() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (1...9).map { rec($0, from: today) }
        vm.refresh(records: records)
        XCTAssertNil(vm.reviveWindow)
    }
}
