import Foundation
import SwiftData
import Testing
@testable import CerealExercise

@MainActor
struct WeightStoreTests {
    /// In-memory SwiftData container + isolated UserDefaults to prevent
    /// test cross-pollination via `UserHealthPreferences.shared`.
    private func makeStore() throws -> (WeightStore, ModelContext, UserHealthPreferences) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: WeightEntry.self, configurations: config)
        let context = ModelContext(container)
        let defaults = UserDefaults(suiteName: "test-store-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        return (WeightStore(context: context, healthPrefs: prefs), context, prefs)
    }

    private func calendar() -> Calendar { .mondayFirst }

    /// 「直近7日」は **今日を含む 7 カレンダー日**。
    /// 今日 = day 0、cutoff = day -6 で、それより古いものは除外される。
    @Test
    func chartEntriesWeek_includesTodayAnd6DaysBack_excludesDay7() throws {
        let (store, context, _) = try makeStore()
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
        let (store, context, _) = try makeStore()
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
        let (store, context, _) = try makeStore()
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
        let (store, context, _) = try makeStore()
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
        let (store, _, _) = try makeStore()
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

    /// 減量目標: 開始 70 → 目標 65 → 現在 67.5。残り = +2.5kg、進捗 = (70-67.5)/(70-65) = 50%。
    @Test
    func remainingAndProgress_lossGoal() {
        let defaults = UserDefaults(suiteName: "test-target-loss-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        prefs.startKilograms = 70.0
        prefs.targetKilograms = 65.0

        // 現在 67.5
        #expect(prefs.remainingToTarget(currentKilograms: 67.5) == 2.5)
        #expect(prefs.isLossGoal() == true)
        let ratio = prefs.progressRatio(currentKilograms: 67.5) ?? 0
        #expect(abs(ratio - 0.5) < 0.001)

        // 目標到達 → 残り 0, 進捗 100%
        #expect(prefs.remainingToTarget(currentKilograms: 65.0) == 0.0)
        let achieved = prefs.progressRatio(currentKilograms: 65.0) ?? 0
        #expect(abs(achieved - 1.0) < 0.001)

        // 目標超過 → 残りはマイナス、進捗は 1.0 (頭打ち)
        #expect(prefs.remainingToTarget(currentKilograms: 63.0) == -2.0)
        let overshoot = prefs.progressRatio(currentKilograms: 63.0) ?? 0
        #expect(abs(overshoot - 1.0) < 0.001)
    }

    /// 増量目標: 開始 55 → 目標 60 → 現在 57。進捗 = (57-55)/(60-55) = 40%。
    @Test
    func remainingAndProgress_gainGoal() {
        let defaults = UserDefaults(suiteName: "test-target-gain-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        prefs.startKilograms = 55.0
        prefs.targetKilograms = 60.0

        #expect(prefs.isLossGoal() == false)
        let ratio = prefs.progressRatio(currentKilograms: 57.0) ?? 0
        #expect(abs(ratio - 0.4) < 0.001)
        // 進捗が後退 → 0 で底打ち
        let regressed = prefs.progressRatio(currentKilograms: 54.0) ?? 0
        #expect(abs(regressed - 0.0) < 0.001)
    }

    /// 目標未設定または開始未設定なら進捗は nil。
    @Test
    func progress_returnsNil_whenIncomplete() {
        let defaults = UserDefaults(suiteName: "test-target-nil-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        #expect(prefs.progressRatio(currentKilograms: 65) == nil)
        prefs.startKilograms = 70
        #expect(prefs.progressRatio(currentKilograms: 65) == nil, "目標未設定なら nil")
        prefs.targetKilograms = 70 // start == target
        #expect(prefs.progressRatio(currentKilograms: 65) == nil, "start == target は意味がないので nil")
    }

    /// 開始 == 目標 (差分なし) の場合は isLossGoal も nil を返す。
    /// View 側で「目標達成」判定が誤動作しないようにするための前提 (Codex round1)。
    @Test
    func isLossGoal_returnsNil_whenStartEqualsTarget() {
        let defaults = UserDefaults(suiteName: "test-loss-nil-\(UUID().uuidString)")!
        let prefs = UserHealthPreferences(defaults: defaults)
        prefs.startKilograms = 65.0
        prefs.targetKilograms = 65.0
        #expect(prefs.isLossGoal() == nil)
        // 浮動小数点誤差レベル (0.0005) も nil
        prefs.targetKilograms = 65.0005
        #expect(prefs.isLossGoal() == nil)
    }

    /// 初回 add で start が自動キャプチャされる (DI 経由)。
    /// 同じ store で 2 回目以降の add では start が変わらない。
    @Test
    func addCapturesStartWeight_onlyOnFirstSuccessfulSave() throws {
        let (store, _, prefs) = try makeStore()
        #expect(prefs.startKilograms == nil)

        _ = store.add(date: Date(), weightKilograms: 70.0)
        #expect(prefs.startKilograms == 70.0, "初回 add で start = 70.0 がキャプチャされる")

        _ = store.add(date: Date().addingTimeInterval(86400), weightKilograms: 69.5)
        #expect(prefs.startKilograms == 70.0, "2 件目以降は start を上書きしない")
    }

    /// latestNonFuture は未来日エントリをスキップする (Codex round6)。
    @Test
    func latestNonFuture_skipsFutureEntries() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let futureDate = cal.date(byAdding: .day, value: 3, to: today)!
        context.insert(WeightEntry(date: yesterday, weightKilograms: 65.0))
        context.insert(WeightEntry(date: futureDate, weightKilograms: 99.0))
        try context.save()
        store.fetchEntries()

        #expect(store.latest?.weightKilograms == 99.0, "latest は未来日も含めた最新")
        #expect(store.latestNonFuture?.weightKilograms == 65.0, "latestNonFuture は未来日をスキップ")
    }

    /// 別のテストで polluted な start が他テストに漏れないこと
    /// (Codex round5: DI 化前は UserDefaults.standard がテスト間で共有されていた)。
    @Test
    func addCapturesStartWeight_doesNotLeakBetweenStores() throws {
        let (store1, _, prefs1) = try makeStore()
        let (store2, _, prefs2) = try makeStore()

        _ = store1.add(date: Date(), weightKilograms: 80.0)
        #expect(prefs1.startKilograms == 80.0)
        #expect(prefs2.startKilograms == nil, "別 store の start に影響しない")

        _ = store2.add(date: Date(), weightKilograms: 60.0)
        #expect(prefs1.startKilograms == 80.0, "store2 の add で store1 の start は変わらない")
        #expect(prefs2.startKilograms == 60.0)
    }
}
