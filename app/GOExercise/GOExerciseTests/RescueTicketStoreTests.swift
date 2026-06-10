import Foundation
import Testing
@testable import GOExercise

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
    func newStore_hasFullMonthlyAllowance() {
        let (store, _) = makeStore()
        let today = Date()
        #expect(store.hasTicketAvailable(today: today, allowance: 1) == true)
        #expect(store.remainingTickets(today: today, allowance: 1) == 1)
    }

    @Test
    func useTicket_consumesMonthlyAllowance() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        #expect(store.useTicket(on: today, allowance: 1) == true)
        #expect(store.remainingTickets(today: today, allowance: 1) == 0)
        #expect(store.hasTicketAvailable(today: today, allowance: 1) == false)
    }

    @Test
    func useTicket_returnsFalse_whenMonthlyExhausted() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        _ = store.useTicket(on: today, allowance: 1)
        // 月次 1 枠を使い切ったので別日も使えない
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!
        #expect(store.useTicket(on: tomorrow, allowance: 1) == false)
    }

    /// Premium の月4枠なら同一月の別日に4回まで使える。
    /// 月をまたがないよう、月初に寄せた固定日 (3/10〜3/14) で検証する。
    @Test
    func premiumAllowance_allowsFourUsesPerMonth() {
        let (store, _) = makeStore()
        func march(_ day: Int) -> Date {
            var comps = DateComponents(); comps.year = 2026; comps.month = 3; comps.day = day
            return cal.date(from: comps)!
        }
        for day in 10...13 {
            #expect(store.useTicket(on: march(day), allowance: 4) == true)
        }
        #expect(store.remainingTickets(today: march(10), allowance: 4) == 0)
        // 5 回目 (同月の別日) は枠切れで false
        #expect(store.useTicket(on: march(14), allowance: 4) == false)
    }

    /// 同日二回 useTicket は 2 回目 no-op で false (Set.insert 冪等)。
    @Test
    func useTicket_sameDay_secondCallReturnsFalse() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        #expect(store.useTicket(on: today, allowance: 4) == true)
        #expect(store.useTicket(on: today, allowance: 4) == false)
        // 1 枠だけ消費 (同日二重消費しない)
        #expect(store.remainingTickets(today: today, allowance: 4) == 3)
    }

    @Test
    func monthRollover_resetsMonthlyAllowance() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        _ = store.useTicket(on: today, allowance: 1)
        #expect(store.remainingTickets(today: today, allowance: 1) == 0)
        let nextMonth = cal.date(byAdding: .month, value: 1, to: today)!
        #expect(store.remainingTickets(today: nextMonth, allowance: 1) == 1)
        #expect(store.hasTicketAvailable(today: nextMonth, allowance: 1) == true)
    }

    /// 年跨ぎ (12 月 → 翌 1 月) でも月次枠が正しくリセットされる。
    @Test
    func yearBoundary_decToJan_resetsMonthlyAllowance() {
        let (store, _) = makeStore()
        var comps = DateComponents()
        comps.year = 2025; comps.month = 12; comps.day = 20
        let dec = cal.date(from: comps)!
        _ = store.useTicket(on: dec, allowance: 1)
        #expect(store.remainingTickets(today: dec, allowance: 1) == 0)
        comps.year = 2026; comps.month = 1; comps.day = 5
        let jan = cal.date(from: comps)!
        #expect(store.remainingTickets(today: jan, allowance: 1) == 1)
        #expect(store.useTicket(on: jan, allowance: 1) == true)
        #expect(store.usedCount(inMonthOf: dec) == 1)
        #expect(store.usedCount(inMonthOf: jan) == 1)
    }

    @Test
    func clear_removesAllUsage() {
        let (store, _) = makeStore()
        let today = cal.startOfDay(for: Date())
        _ = store.useTicket(on: today, allowance: 1)
        store.clear()
        #expect(store.remainingTickets(today: today, allowance: 1) == 1)
        #expect(store.rescuedDates().isEmpty)
    }

    @Test
    func allowance_isFourForPremium_oneForFree() {
        #expect(RescueTicketAllowance.current(isPremium: true) == 4)
        #expect(RescueTicketAllowance.current(isPremium: false) == 1)
    }

    // MARK: - 永続化(監査 F5: y-m-d 文字列・TZ 非依存)

    private func gregorian(tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone(identifier: tz)!
        return c
    }
    private func ymd(_ c: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date {
        c.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test
    func usage_persistsAcrossReinit() {
        let suite = "test.rescue.persist.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let today = cal.startOfDay(for: Date())
        let s1 = RescueTicketStore(defaults: defaults, calendar: cal)
        _ = s1.useTicket(on: today, allowance: 1)
        let s2 = RescueTicketStore(defaults: defaults, calendar: cal)
        #expect(s2.rescuedDates().contains(today))
        #expect(s2.remainingTickets(today: today, allowance: 1) == 0)
    }

    @Test
    func persistence_survivesTimezoneChange_asCalendarDay() {
        let suite = "test.rescue.tz.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let jst = gregorian(tz: "Asia/Tokyo")
        let utc = gregorian(tz: "UTC")
        // JST で 2026-03-10 を救済
        let sJST = RescueTicketStore(defaults: defaults, calendar: jst)
        #expect(sJST.useTicket(on: ymd(jst, 2026, 3, 10), allowance: 4) == true)
        // 端末 TZ が UTC に変わった想定で同じ defaults を再読込 → 暦日 3/10 は救済済みのまま
        let sUTC = RescueTicketStore(defaults: defaults, calendar: utc)
        #expect(sUTC.rescuedDates().contains(utc.startOfDay(for: ymd(utc, 2026, 3, 10))) == true)
        #expect(sUTC.usedCount(inMonthOf: ymd(utc, 2026, 3, 1)) == 1)
    }

    @Test
    func legacyEpochFormat_isReadAndMigratedToStrings() {
        let suite = "test.rescue.legacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let day = cal.startOfDay(for: Date())
        // 旧形式(epoch 秒の配列)を直接投入
        defaults.set([day.timeIntervalSince1970], forKey: RescueTicketStore.usedDatesKey)
        let store = RescueTicketStore(defaults: defaults, calendar: cal)
        #expect(store.rescuedDates().contains(day))
        // 初回 init で y-m-d 文字列配列へ移行保存されている
        #expect(defaults.array(forKey: RescueTicketStore.usedDatesKey) is [String])
    }
}
