import Foundation
import Testing
@testable import GOExercise

/// Codex UX 提案 #2「復帰ファースト」の `isComebackToday` 判定ロジックを検証。
/// 条件: 昨日未達成 + 今日未達成 + 累計達成 >= 3 のとき true。
@MainActor
struct HomeViewModelComebackTests {
    private let cal: Calendar = .mondayFirst

    /// 指定日 (startOfDay) に運動記録を作る helper。
    private func record(on date: Date) -> WorkoutRecord {
        WorkoutRecord(
            date: date,
            category: .strength,
            exercises: [ExerciseItem(id: UUID(), name: "スクワット",
                                      durationSeconds: 120,
                                      reps: nil, sets: nil, memo: nil)],
            memo: nil,
            calendar: cal
        )
    }

    private func makeViewModel(today: Date) -> HomeViewModel {
        HomeViewModel(dateProvider: FixedDateProvider(date: today), calendar: cal)
    }

    /// 過去 7..14 日前に習慣有 → その後 1 週間以上完全に空白 → 今日も未達。
    /// `today` を **土曜** に固定: rest day 自動補完 (週前半 2 日まで) の影響で
    /// 火/水以降が必ず `.missed` 判定になる。よって金曜=yesterday も `.missed`。
    @Test
    func isComebackToday_true_whenYesterdayMissed_andHadHabit() {
        let today = nextSaturday(after: Date())
        let vm = makeViewModel(today: today)
        // 直近 7..14 日前に毎日記録 (8 日連続) → その後完全空白
        let records = (7...14).map { offset in
            record(on: cal.date(byAdding: .day, value: -offset, to: today)!)
        }
        vm.refresh(records: records)
        #expect(vm.streak.currentStreak == 0, "streak 切れ前提")
        #expect(vm.isComebackToday == true,
                "土曜・昨日 missed・今日未達・習慣あり → 復帰モード")
    }

    /// rescue ticket で救済された昨日は missed 扱いせず、復帰モードも出さない。
    /// Codex round1 priority 1: rescuedDates を yesterdayStatus に渡し忘れ
    /// → 救済済の昨日が missed で comeback 誤発火 の regression test。
    @Test
    func isComebackToday_false_whenYesterdayWasRescued() {
        let suite = "rescue-yesterday-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let today = nextSaturday(after: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        // 昨日を rescue ticket で救済 = .achieved 扱いになる
        let ticketStore = RescueTicketStore(defaults: defaults)
        _ = ticketStore.useTicket(on: yesterday, allowance: 1)

        let vm = HomeViewModel(
            dateProvider: FixedDateProvider(date: today),
            calendar: cal,
            rescueTicketStore: ticketStore
        )
        // 過去 7..14 日の習慣 + 昨日 missed 系シナリオを再現するための records
        let records = (7...14).map { offset in
            record(on: cal.date(byAdding: .day, value: -offset, to: today)!)
        }
        vm.refresh(records: records)
        #expect(vm.isComebackToday == false,
                "rescue ticket で救済された昨日は missed 扱いせず、復帰モードを出さない")
    }

    /// 「次の土曜日 (= today を week 後半に固定)」を返す helper。
    /// rest day 自動補完 (週前半 Mon/Tue まで) によってテスト結果がブレるのを防ぐ。
    private func nextSaturday(after base: Date) -> Date {
        var date = cal.startOfDay(for: base)
        for _ in 0...7 {
            if cal.component(.weekday, from: date) == 7 { return date } // Gregorian Sat = 7
            date = cal.date(byAdding: .day, value: 1, to: date)!
        }
        return date
    }

    /// 昨日達成済み → 復帰モードではない (通常)。
    @Test
    func isComebackToday_false_whenYesterdayAchieved() {
        let today = cal.startOfDay(for: Date())
        let vm = makeViewModel(today: today)
        let records = (1...5).map { offset in
            record(on: cal.date(byAdding: .day, value: -offset, to: today)!)
        }
        vm.refresh(records: records)
        #expect(vm.isComebackToday == false)
    }

    /// 今日達成済み → 復帰モードではない (もう戻ってきた)。
    @Test
    func isComebackToday_false_whenTodayAlreadyDone() {
        let today = cal.startOfDay(for: Date())
        let vm = makeViewModel(today: today)
        let records = [
            record(on: today),
            record(on: cal.date(byAdding: .day, value: -3, to: today)!),
            record(on: cal.date(byAdding: .day, value: -4, to: today)!),
            record(on: cal.date(byAdding: .day, value: -5, to: today)!),
        ]
        vm.refresh(records: records)
        #expect(vm.isComebackToday == false)
    }

    /// 累計達成 < 3 (= まだ習慣を持っていない新規ユーザー) は復帰扱いしない
    /// (「復帰」と言うほどの習慣がない)。
    @Test
    func isComebackToday_false_whenLifetimeUnder3() {
        let today = cal.startOfDay(for: Date())
        let vm = makeViewModel(today: today)
        let records = [
            record(on: cal.date(byAdding: .day, value: -10, to: today)!),
            record(on: cal.date(byAdding: .day, value: -11, to: today)!),
        ]
        vm.refresh(records: records)
        #expect(vm.isComebackToday == false, "累計 2 日では復帰モード対象外")
    }

    /// 記録なし状態 (= 完全新規) は復帰モードではない。
    @Test
    func isComebackToday_false_whenNoRecords() {
        let today = cal.startOfDay(for: Date())
        let vm = makeViewModel(today: today)
        vm.refresh(records: [])
        #expect(vm.isComebackToday == false)
    }
}
