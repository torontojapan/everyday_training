import Foundation
import Testing
@testable import CerealExercise

@MainActor
struct RescueTicketStoreTests {
    /// テスト用に isolated な UserDefaults suite を作る (system defaults 汚染回避)。
    private func makeStore() -> (store: RescueTicketStore, defaults: UserDefaults) {
        let suiteName = "test.rescue.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (RescueTicketStore(defaults: defaults), defaults)
    }

    private let cal: Calendar = .mondayFirst

    @Test
    func newStore_hasFullMonthlyAllowance_andZeroPurchased() {
        let (store, _) = makeStore()
        let today = Date()
        #expect(store.hasTicketAvailable(today: today, allowance: 1) == true)
        #expect(store.remainingTickets(today: today, allowance: 1) == 1)
        #expect(store.purchasedRemaining == 0)
    }

    @Test
    func useTicket_consumesMonthlyAllowance_first() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        store.addPurchasedTicket(count: 1)
        #expect(store.useTicket(on: today, allowance: 1) == true)
        // 月次配布枠が先に消費されたので purchased は残る
        #expect(store.purchasedRemaining == 1)
        #expect(store.remainingTickets(today: today, allowance: 1) == 0)
    }

    @Test
    func useTicket_consumesPurchased_whenMonthlyExhausted() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        store.addPurchasedTicket(count: 1)
        // 1 回目: 月次から
        #expect(store.useTicket(on: today, allowance: 1) == true)
        // 別日でもう 1 回 → 月次は今月使い切ったので purchased から
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        #expect(store.useTicket(on: tomorrow, allowance: 1) == true)
        #expect(store.purchasedRemaining == 0)
    }

    @Test
    func useTicket_returnsFalse_whenAllExhausted() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        _ = store.useTicket(on: today, allowance: 1)
        // 月次 0, 購入 0 → 別日も使えない
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        #expect(store.useTicket(on: tomorrow, allowance: 1) == false)
    }

    /// LLM A 致命的指摘の regression テスト: 同日に二回 useTicket を呼ぶと
    /// Set.insert が冪等なので 2 回目は no-op、戻り値は false を期待。
    @Test
    func useTicket_sameDay_secondCallReturnsFalse() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        store.addPurchasedTicket(count: 5)
        #expect(store.useTicket(on: today, allowance: 1) == true)
        // 同日 2 回目: false で no-op (purchased も減らない)
        #expect(store.useTicket(on: today, allowance: 1) == false)
        #expect(store.purchasedRemaining == 5)
    }

    @Test
    func addPurchasedTicket_increments() {
        let (store, _) = makeStore()
        store.addPurchasedTicket()
        store.addPurchasedTicket()
        store.addPurchasedTicket(count: 3)
        #expect(store.purchasedRemaining == 5)
    }

    @Test
    func monthRollover_resetsMonthlyAllowance() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        _ = store.useTicket(on: today, allowance: 1)
        #expect(store.remainingTickets(today: today, allowance: 1) == 0)
        // 翌月 1 日 (今日に +1 month) の usedCount は 0 のまま
        let nextMonth = cal.date(byAdding: .month, value: 1, to: today)!
        #expect(store.remainingTickets(today: nextMonth, allowance: 1) == 1)
        #expect(store.hasTicketAvailable(today: nextMonth, allowance: 1) == true)
    }

    /// 年跨ぎ (12 月 → 翌 1 月) でも月次枠が正しくリセットされる (Codex 指摘の coverage gap)。
    @Test
    func yearBoundary_decToJan_resetsMonthlyAllowance() {
        let (store, _) = makeStore()
        var comps = DateComponents()
        comps.year = 2025; comps.month = 12; comps.day = 20
        let dec = cal.date(from: comps)!
        _ = store.useTicket(on: dec, allowance: 1)
        #expect(store.remainingTickets(today: dec, allowance: 1) == 0)
        // 翌 1 月 (年が変わる) は別月扱いで枠が戻る
        comps.year = 2026; comps.month = 1; comps.day = 5
        let jan = cal.date(from: comps)!
        #expect(store.remainingTickets(today: jan, allowance: 1) == 1)
        #expect(store.useTicket(on: jan, allowance: 1) == true)
        // 12 月分の使用は残っている (別月なので独立)
        #expect(store.usedCount(inMonthOf: dec) == 1)
        #expect(store.usedCount(inMonthOf: jan) == 1)
    }

    @Test
    func totalRemaining_sumsMonthlyAndPurchased() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        store.addPurchasedTicket(count: 3)
        #expect(store.totalRemaining(today: today, allowance: 2) == 5)
        _ = store.useTicket(on: today, allowance: 2)
        #expect(store.totalRemaining(today: today, allowance: 2) == 4)
    }
}
