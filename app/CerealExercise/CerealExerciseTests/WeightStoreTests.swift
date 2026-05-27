import Foundation
import SwiftData
import Testing
@testable import CerealExercise

@MainActor
struct WeightStoreTests {
    /// In-memory SwiftData container for test isolation.
    private func makeStore() throws -> (WeightStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)
        return (WeightStore(context: context), context)
    }

    private func calendar() -> Calendar { .mondayFirst }

    /// 「直近7日」は **今日を含む 7 カレンダー日**。
    /// 今日 = day 0、cutoff = day -6 で、それより古いものは除外される。
    @Test
    func chartEntriesWeek_includesTodayAnd6DaysBack_excludesDay7() throws {
        let (store, context) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // Insert entries at day 0, -3, -6, -7. Day -7 must be excluded.
        for offset in [0, -3, -6, -7] {
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        try context.save()
        store.fetchEntries()

        let week = store.chartEntries(period: .week, today: today)
        #expect(week.count == 3, "week は今日+6日前まで = 3 件 (day 0/-3/-6), day -7 は除外")
        #expect(!week.contains { cal.isDate($0.date, inSameDayAs: cal.date(byAdding: .day, value: -7, to: today)!) })
    }

    /// 「直近30日」も同様に inclusive: cutoff = day -29。
    @Test
    func chartEntriesMonth_inclusiveBoundary() throws {
        let (store, context) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        for offset in [0, -29, -30] {
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        try context.save()
        store.fetchEntries()

        let month = store.chartEntries(period: .month, today: today)
        #expect(month.count == 2, "today と day -29 は含まれ、day -30 は除外される")
    }

    /// `.all` は全件返す (cutoff なし)。未来日は除外。
    @Test
    func chartEntriesAll_returnsEverything() throws {
        let (store, context) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        for offset in [0, -100, -365] {
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        try context.save()
        store.fetchEntries()

        let all = store.chartEntries(period: .all, today: today)
        #expect(all.count == 3)
    }

    /// 未来日エントリ (時計ズレ / インポートで混入) は全期間に対して除外。
    @Test
    func chartEntries_excludesFutureDates() throws {
        let (store, context) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 過去・現在・未来 3 件
        for offset in [-3, 0, 5] {
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        try context.save()
        store.fetchEntries()

        #expect(store.chartEntries(period: .week, today: today).count == 2, "week は今日と day -3 = 2 件、未来日は除外")
        #expect(store.chartEntries(period: .all, today: today).count == 2, ".all でも未来日は除外")
    }

    /// 同じ日に add すると上書きされる現状の挙動を locking 。
    /// (Iteration 2 で見直し対象)
    @Test
    func addSameDay_overwritesExisting() throws {
        let (store, _) = try makeStore()
        let today = Date()
        _ = store.add(date: today, weightKilograms: 65.0, memo: "morning")
        _ = store.add(date: today, weightKilograms: 64.5, memo: "evening")

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.weightKilograms == 64.5)
        #expect(store.entries.first?.memo == "evening")
    }

    /// BMI 計算: 身長 170 cm, 体重 68 kg → BMI ≈ 23.53。
    @Test
    func bmiCalculation_correctForKnownValues() {
        let defaults = UserDefaults(suiteName: "test-bmi-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        prefs.heightCentimeters = 170
        let bmi = prefs.bmi(weightKilograms: 68.0)
        #expect(bmi != nil)
        if let bmi {
            #expect(abs(bmi - 23.529) < 0.01)
            #expect(BMICategory(bmi: bmi) == .normal)
        }
    }

    @Test
    func bmiNil_whenHeightMissing() {
        let defaults = UserDefaults(suiteName: "test-bmi-nil-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        #expect(prefs.bmi(weightKilograms: 70) == nil)
    }

    @Test
    func bmiCategoryThresholds() {
        #expect(BMICategory(bmi: 18.4) == .underweight)
        #expect(BMICategory(bmi: 18.5) == .normal)
        #expect(BMICategory(bmi: 24.9) == .normal)
        #expect(BMICategory(bmi: 25.0) == .overweight)
        #expect(BMICategory(bmi: 29.9) == .overweight)
        #expect(BMICategory(bmi: 30.0) == .obese)
    }
}
