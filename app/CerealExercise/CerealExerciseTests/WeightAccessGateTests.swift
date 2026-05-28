import Foundation
import Testing
@testable import CerealExercise

@MainActor
struct WeightAccessGateTests {
    private func makeGate(now: Date = Date(), trialDays: Int = 30)
    -> (gate: WeightAccessGate, defaults: UserDefaults, dateProvider: MutableDateProvider) {
        let suiteName = "test.weightGate.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let dp = MutableDateProvider(now: now)
        let gate = WeightAccessGate(defaults: defaults, dateProvider: dp,
                                     calendar: .mondayFirst, trialDays: trialDays)
        return (gate, defaults, dp)
    }

    @Test
    func notOpened_yet_returnsFullTrial() {
        let (gate, _, _) = makeGate()
        // 体重タブを 1 度も開いていない = trial 開始前なので満日数。
        let access = gate.currentAccess(isSubscribed: false)
        #expect(access == .freeTrialActive(remainingDays: 30))
        #expect(access.isUnlocked == true)
    }

    @Test
    func markOpened_thenSameDay_returnsFullTrial() {
        let (gate, _, _) = makeGate()
        gate.markOpenedIfNeeded()
        let access = gate.currentAccess(isSubscribed: false)
        #expect(access == .freeTrialActive(remainingDays: 30))
    }

    @Test
    func markOpened_isIdempotent() {
        let (gate, _, dp) = makeGate()
        gate.markOpenedIfNeeded()
        let firstDate = gate.firstOpenedDate()
        // 1 日後にもう一度呼んでも firstOpenedDate は変わらない
        dp.now = dp.now.addingTimeInterval(86_400)
        gate.markOpenedIfNeeded()
        #expect(gate.firstOpenedDate() == firstDate)
    }

    @Test
    func day29_returnsRemainingOne() {
        let start = Calendar.mondayFirst.startOfDay(for: Date())
        let (gate, _, dp) = makeGate(now: start)
        gate.markOpenedIfNeeded()
        // 29 日経過: 残り 1 日
        dp.now = Calendar.mondayFirst.date(byAdding: .day, value: 29, to: start)!
        let access = gate.currentAccess(isSubscribed: false)
        #expect(access == .freeTrialActive(remainingDays: 1))
        #expect(access.isUnlocked == true)
    }

    @Test
    func day30_returnsExpired() {
        let start = Calendar.mondayFirst.startOfDay(for: Date())
        let (gate, _, dp) = makeGate(now: start)
        gate.markOpenedIfNeeded()
        dp.now = Calendar.mondayFirst.date(byAdding: .day, value: 30, to: start)!
        let access = gate.currentAccess(isSubscribed: false)
        #expect(access == .freeTrialExpired)
        #expect(access.isUnlocked == false)
    }

    @Test
    func day100_stillExpired() {
        let start = Calendar.mondayFirst.startOfDay(for: Date())
        let (gate, _, dp) = makeGate(now: start)
        gate.markOpenedIfNeeded()
        dp.now = Calendar.mondayFirst.date(byAdding: .day, value: 100, to: start)!
        #expect(gate.currentAccess(isSubscribed: false) == .freeTrialExpired)
    }

    @Test
    func subscribed_overridesExpired() {
        let start = Calendar.mondayFirst.startOfDay(for: Date())
        let (gate, _, dp) = makeGate(now: start)
        gate.markOpenedIfNeeded()
        dp.now = Calendar.mondayFirst.date(byAdding: .day, value: 100, to: start)!
        #expect(gate.currentAccess(isSubscribed: true) == .subscribed)
        #expect(gate.currentAccess(isSubscribed: true).isUnlocked == true)
    }

    @Test
    func clear_resetsFirstOpened() {
        let (gate, _, _) = makeGate()
        gate.markOpenedIfNeeded()
        #expect(gate.firstOpenedDate() != nil)
        gate.clear()
        #expect(gate.firstOpenedDate() == nil)
    }
}

/// テスト用に「今」を後から変更できる DateProvider 実装。
/// 既存の `FixedDateProvider` は struct で immutable なため、時刻進行を
/// シミュレートするテスト向けに mutable な class 版を提供する。
final class MutableDateProvider: DateProviding, @unchecked Sendable {
    var now: Date
    init(now: Date) { self.now = now }
    func currentDate() -> Date { now }
}
