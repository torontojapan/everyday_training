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
    /// 土曜固定。今週 Mon/Tue 達成 + Wed/Thu/Fri 空白にすると、週前半 rest 枠 2 日(Wed/Thu)
    /// を使い切って **金曜が本当に .missed** になる(rest で橋渡しされない真の break)。
    private func saturday() -> Date {
        var d = cal.startOfDay(for: Date()); for _ in 0...7 { if cal.component(.weekday, from: d) == 7 { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }; return d
    }
    func test_reviveWindow_published_andApply_restoresStreak() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        // offsets 4..12 = 今週 Tue/Mon + 先週 1 週ぶん。Wed(3)/Thu(2)/Fri(1) が空白 →
        // Wed/Thu が rest、Fri が真の missed。前の連続(Tue 以前)があるので復活可能。
        let records = (4...12).map { rec($0, from: today) }
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertNotNil(vm.reviveWindow, "金曜が真の missed → 復活ウィンドウあり")
        XCTAssertEqual(vm.reviveWindow?.freezesNeeded, 1, "Wed/Thu は rest なので必要なのは金曜の1枚のみ")
        XCTAssertTrue(vm.reviveWindow?.hasEnough == true, "無料枠1で足りる")
        XCTAssertGreaterThan(vm.potentialReviveStreak, 0, "復活で守られる連続日数が0でない(anchor修正の検証)")

        let rank = vm.applyRevive()
        XCTAssertNotNil(rank, "復活成功で称号 CatRank を返す")

        // 金曜にフリーズが適用されたことを確認。
        let friday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
        XCTAssertTrue(store.rescuedDates().contains(friday), "金曜にフリーズ適用済み")

        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertNil(vm.reviveWindow, "復活後は gap が橋渡しされ window 解消")
    }
    func test_noWindow_whenStreakIntact() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (1...12).map { rec($0, from: today) } // 昨日(金)も達成 → 切れていない
        vm.refresh(records: records)
        XCTAssertNil(vm.reviveWindow)
    }
    func test_noWindow_whenAlreadyRescued() {
        let today = saturday()
        let store = RescueTicketStore(defaults: UserDefaults(suiteName: "revive-\(UUID())")!)
        // 金曜を先にフリーズ済み → missed が無くなり復活ウィンドウは出ない。
        let friday = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today))!
        _ = store.useTicket(on: friday, allowance: 1)
        let vm = HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal, rescueTicketStore: store)
        let records = (4...12).map { rec($0, from: today) }
        vm.refresh(records: records, isPremium: false, referralFreezeBonus: 0)
        XCTAssertNil(vm.reviveWindow, "金曜 rescue 済み=achieved → 切れていない")
    }
}
