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

    /// 同日複数記録は両方とも保持される (朝/晩を別エントリで管理する仕様)。
    /// グラフでは「日内最新」に集約されるが、履歴とエントリ配列には両方残る。
    @Test
    func addSameDay_keepsBothEntries() throws {
        let (store, _, _) = try makeStore()
        let morning = Date()
        let evening = morning.addingTimeInterval(8 * 3600) // 同日 8 時間後
        _ = store.add(date: morning, weightKilograms: 65.0, memo: "morning")
        _ = store.add(date: evening, weightKilograms: 64.5, memo: "evening")

        #expect(store.entries.count == 2, "同日2件とも保持される")
        // entries は date 降順なので evening (新しい時刻) が先頭。
        #expect(store.entries.first?.weightKilograms == 64.5)
        #expect(store.entries.first?.memo == "evening")
        #expect(store.entries.last?.weightKilograms == 65.0)
        #expect(store.entries.last?.memo == "morning")
    }

    /// グラフ用 chartEntries は同日複数エントリを「日内最新」に集約する。
    /// 朝 65.0 / 夜 64.5 なら夜の 64.5 のみが返る。
    @Test
    func chartEntries_collapsesToDailyLatest() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        let morning = today.addingTimeInterval(7 * 3600)   // 朝 7:00
        let evening = today.addingTimeInterval(20 * 3600)  // 夜 20:00
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: today)!.addingTimeInterval(7 * 3600)
        context.insert(WeightEntry(date: morning, weightKilograms: 65.0))
        context.insert(WeightEntry(date: evening, weightKilograms: 64.5))
        context.insert(WeightEntry(date: yesterdayMorning, weightKilograms: 66.0))
        try context.save()
        store.fetchEntries()

        let week = store.chartEntries(period: .week, today: today)
        #expect(week.count == 2, "今日 + 昨日 = 2 日分 (今日は 2 件あるが日内最新 1 件に集約)")
        #expect(week.first?.weightKilograms == 64.5, "今日の最新 = 夜の 64.5")
        #expect(week.last?.weightKilograms == 66.0, "昨日の唯一の記録 = 66.0")
    }

    /// 今日の現在時刻入りエントリ (例: today の 14:00) が "未来" 扱いで除外されないこと。
    /// 旧実装は上限を `<= todayStart (今日 00:00)` にしていて、time-stamped な
    /// 今日のエントリを取りこぼしていた (P0-4 で fix)。
    @Test
    func chartEntries_includesTodayEntriesWithTime() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        let nowish = today.addingTimeInterval(14 * 3600) // 今日 14:00
        context.insert(WeightEntry(date: nowish, weightKilograms: 65.0))
        try context.save()
        store.fetchEntries()

        #expect(store.chartEntries(period: .week, today: today).count == 1)
        #expect(store.chartEntries(period: .all, today: today).count == 1)
    }

    /// latestNonFuture も今日の現在時刻入りエントリを除外してはいけない。
    @Test
    func latestNonFuture_includesTodayCurrentTime() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        let nowish = today.addingTimeInterval(14 * 3600)
        context.insert(WeightEntry(date: nowish, weightKilograms: 65.0))
        try context.save()
        store.fetchEntries()

        #expect(store.latestNonFuture?.weightKilograms == 65.0)
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

    // MARK: - Trendline (P1-1)

    /// 7 日移動平均: 7 日分の連続データがあれば最終日の trend = 7 日平均。
    @Test
    func trendline_lastPointEqualsTrailingWindowAverage() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 7 日連続で 60.0 〜 63.0 を 0.5 刻みで入れる (oldest → newest)
        let weights: [Double] = [60.0, 60.5, 61.0, 61.5, 62.0, 62.5, 63.0]
        for (i, w) in weights.enumerated() {
            let offset = -(weights.count - 1 - i) // -6, -5, ..., 0
            let date = cal.date(byAdding: .day, value: offset, to: today)!
                .addingTimeInterval(8 * 3600) // 8:00 で記録
            context.insert(WeightEntry(date: date, weightKilograms: w))
        }
        try context.save()
        store.fetchEntries()

        let trend = store.trendline(period: .week, window: 7, minSamples: 2, today: today)
        // day -6 は window 内に自分 1 件しかない (minSamples=2 未満) のでスキップされる。
        // よって day -5 〜 today の 6 点が trend に含まれる。
        #expect(trend.count == weights.count - 1)
        // 古→新 で並んでいる
        #expect(trend.first?.date == cal.startOfDay(for: cal.date(byAdding: .day, value: -5, to: today)!))
        #expect(trend.last?.date == today)
        // 最終点 (today) の平均 = (60+60.5+61+61.5+62+62.5+63) / 7 = 61.5
        let expectedLast = weights.reduce(0, +) / Double(weights.count)
        #expect(abs((trend.last?.average ?? 0) - expectedLast) < 1e-9)
    }

    /// 同日複数記録は **日内最新** が trend に使われる (chartEntries と整合)。
    @Test
    func trendline_usesDailyLatestForSameDayEntries() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 今日: 朝 70.0, 夜 65.0 — trend には 65.0 (夜) が反映されるべき
        context.insert(WeightEntry(date: today.addingTimeInterval(7 * 3600),
                                   weightKilograms: 70.0))
        context.insert(WeightEntry(date: today.addingTimeInterval(20 * 3600),
                                   weightKilograms: 65.0))
        // 昨日: 単一 67.0
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        context.insert(WeightEntry(date: yesterday.addingTimeInterval(8 * 3600),
                                   weightKilograms: 67.0))
        try context.save()
        store.fetchEntries()

        let trend = store.trendline(period: .week, window: 7, minSamples: 2, today: today)
        // 2 件 (昨日 + 今日) の trend が出る (minSamples=2 を満たすのは今日の点のみ)
        // 昨日の時点では window 内に 1 件しかない → スキップ
        #expect(trend.count == 1)
        #expect(trend.first?.date == today)
        let expected = (67.0 + 65.0) / 2.0  // 昨日 67 + 今日 65 (夜の最新値)
        #expect(abs((trend.first?.average ?? 0) - expected) < 1e-9)
    }

    /// minSamples 未満の日は trend に含まれない。
    @Test
    func trendline_skipsPointsBelowMinSamples() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        context.insert(WeightEntry(date: today.addingTimeInterval(10 * 3600),
                                   weightKilograms: 65.0))
        try context.save()
        store.fetchEntries()

        // 1 件しかない → minSamples=2 では trend なし
        #expect(store.trendline(period: .week, window: 7, minSamples: 2, today: today).isEmpty)
        // minSamples=1 なら 1 点だけ trend が出る
        let lax = store.trendline(period: .week, window: 7, minSamples: 1, today: today)
        #expect(lax.count == 1)
        #expect(lax.first?.average == 65.0)
    }

    /// 窓のサイズは calendar 日ベース。時刻情報の差異で誤判定しないこと。
    /// 7 日 window で「今日 20:00 を anchor にしたとき 6 日前 7:00 を含む」
    /// を保証する (時刻ベースの -6 days だと 6 日前 14:00 になり、7:00 を取りこぼす可能性)。
    @Test
    func trendline_windowIsCalendarDayBased() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 今日 20:00 と 6 日前 7:00
        context.insert(WeightEntry(date: today.addingTimeInterval(20 * 3600),
                                   weightKilograms: 60.0))
        let sixDaysAgo = cal.date(byAdding: .day, value: -6, to: today)!
        context.insert(WeightEntry(date: sixDaysAgo.addingTimeInterval(7 * 3600),
                                   weightKilograms: 66.0))
        try context.save()
        store.fetchEntries()

        let trend = store.trendline(period: .week, window: 7, minSamples: 2, today: today)
        // 今日の anchor で 6 日前を取り込めれば 2 点平均が出る。
        let todayPoint = trend.first { $0.date == today }
        #expect(todayPoint != nil, "今日 anchor で 6 日前 7:00 のエントリも window に入るべき")
        if let p = todayPoint {
            #expect(abs(p.average - 63.0) < 1e-9, "(60 + 66) / 2 = 63.0")
        }
    }

    // MARK: - Forecast (P1-2)

    /// 30 日かけて毎日 0.1kg 減らしたケース: slope = -0.1 kg/日。
    /// 現在 67.0 / 目標 65.0 → (-2.0) / (-0.1) = 20 日で達成 (近似)。
    @Test
    func forecast_lossGoal_linearTrendReturnsExpectedDays() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 30 日分: oldest 70.0 → newest 67.0 (slope = -0.1 kg/日)
        for offset in 0...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            let weight = 67.0 + Double(offset) * 0.1
            context.insert(WeightEntry(date: date, weightKilograms: weight))
        }
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 65.0

        let days = store.forecastDaysToTarget(today: today)
        #expect(days != nil)
        if let days {
            // 線形なら ~20 日。移動平均の遅延で多少前後 (15-25 程度を許容)。
            #expect(days >= 15 && days <= 25, "got \(days)")
        }
    }

    /// 増量ケース: 30 日かけて毎日 0.05kg 増。現在 55 / 目標 60 → 100 日前後。
    @Test
    func forecast_gainGoal_positiveSlopeProducesPositiveDays() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        for offset in 0...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            let weight = 55.0 - Double(offset) * 0.05 // newest 55.0, oldest ≒ 53.55
            context.insert(WeightEntry(date: date, weightKilograms: weight))
        }
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 60.0

        let days = store.forecastDaysToTarget(today: today)
        #expect(days != nil)
        if let days {
            #expect(days > 0)
            #expect(days <= 365)
        }
    }

    /// 目標方向と逆 (減量目標なのに増えてる) は nil を返す (達成しないので予測不能扱い)。
    @Test
    func forecast_wrongDirection_returnsNil() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 目標は減量 (target 60)、しかし傾きは増量 (oldest 65 → newest 67)
        for offset in 0...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            let weight = 67.0 - Double(offset) * (2.0 / 29.0) // newest 67, oldest 65
            context.insert(WeightEntry(date: date, weightKilograms: weight))
        }
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 60.0

        #expect(store.forecastDaysToTarget(today: today) == nil)
    }

    /// 傾きが極小 (|slope| < minSlopeKgPerDay) なら nil (ノイズに過剰反応しない)。
    @Test
    func forecast_flatTrend_returnsNil() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        for offset in 0...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 60.0

        #expect(store.forecastDaysToTarget(today: today) == nil)
    }

    /// 既に目標到達 (epsilon 内) は 0 を返す (UI 側で「圏内」表示)。
    @Test
    func forecast_alreadyAtTarget_returnsZero() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        context.insert(WeightEntry(date: today.addingTimeInterval(8 * 3600),
                                   weightKilograms: 65.02))
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 65.0

        #expect(store.forecastDaysToTarget(today: today) == 0)
    }

    /// epsilon ガード (delta < 50g → 0) と「丸めて 0」が衝突しないよう、
    /// 残量があれば最低 1 日にする (Codex round1 priority 2)。
    @Test
    func forecast_alreadyAtTarget_byEpsilon_returnsZero() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 30 日連続、最新値が target の epsilon 内 → 早期 0
        for offset in 0...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            let weight = 65.04 + Double(offset) * 0.103
            context.insert(WeightEntry(date: date, weightKilograms: weight))
        }
        try context.save()
        store.fetchEntries()
        prefs.targetKilograms = 65.0 // raw との差 0.04kg → 早期 0
        #expect(store.forecastDaysToTarget(today: today) == 0)
    }

    /// **本命の round-to-zero 回帰防止**: `0 < days < 0.5` のときに
    /// `Int(days.rounded()) == 0` となって UI が「圏内」表示と衝突するのを防ぐ。
    /// 設計: 直近 7 日は 65.0kg で plateau (trend baseline ≒ 65.0)、
    /// それ以前 23 日は 65 → 80kg まで急傾斜 (slope ≒ -0.5 kg/日)。
    /// target = 64.85 → delta = -0.15, days = 0.15 / 0.5 = 0.3 → 0 (pre-fix), 1 (post-fix)。
    @Test
    func forecast_steepSlope_returnsAtLeastOneDay() throws {
        let (store, context, prefs) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        // 直近 7 日: 65.0 で plateau (trend.last の baseline)
        for offset in 0...6 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            context.insert(WeightEntry(date: date, weightKilograms: 65.0))
        }
        // それ以前 23 日: 65 → 80 まで線形ランプ (slope 約 -0.5 kg/日)
        for offset in 7...29 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
                .addingTimeInterval(8 * 3600)
            let weight = 65.0 + Double(offset - 7) * (15.0 / 22.0)
            context.insert(WeightEntry(date: date, weightKilograms: weight))
        }
        try context.save()
        store.fetchEntries()
        // delta = -0.15 (>epsilon 0.05)、days = 0.15 / 0.5 ≒ 0.3 → 旧実装で 0、新実装で 1。
        prefs.targetKilograms = 64.85

        let days = store.forecastDaysToTarget(today: today)
        #expect(days != nil, "epsilon 外なので nil ではない")
        if let days {
            #expect(days == 1, "round-to-zero を防いで最低 1 日に切り上がる (got \(days))")
        }
    }

    /// `entries` のソート順は date 降順 → createdAt 降順 → id 降順 で
    /// deterministic (Codex round1 priority 3)。3 段すべての tie-break を確認:
    ///   - **date 違い** (一次キー): 後の日が先頭 (cross-day 検証)
    ///   - date 同一 / createdAt 違い (二次キー): createdAt 降順
    ///   - date + createdAt 同一 / id 違い (三次キー): id 降順
    /// さらに **複数回 fetch しても順序が安定** であることを確認 (SwiftData の
    /// 内部キャッシュやインデックス変動の影響を受けない)。
    @Test
    func entries_deterministicSort_whenTimestampsCollide() throws {
        let (store, context, _) = try makeStore()
        let cal = calendar()
        let today = cal.startOfDay(for: Date())
        let todayMorning = today.addingTimeInterval(10 * 3600)
        let yesterdayMorning = cal.date(byAdding: .day, value: -1, to: today)!
            .addingTimeInterval(10 * 3600)
        let sameCreatedAt = Date(timeIntervalSince1970: 500)

        // (Y) **昨日** のエントリ: createdAt がかなり新しくても、date が前なので
        //     **必ず後ろ** に来ることを確認 (date が一次キー、createdAt より優先)。
        let y = WeightEntry(date: yesterdayMorning, weightKilograms: 70.0,
                            createdAt: Date(timeIntervalSince1970: 9999)) // 一番新しい createdAt
        // (A) 今日 / createdAt 違い → createdAt 降順で並ぶ
        let a1 = WeightEntry(date: todayMorning, weightKilograms: 65.0,
                             createdAt: Date(timeIntervalSince1970: 100))
        let a2 = WeightEntry(date: todayMorning, weightKilograms: 64.0,
                             createdAt: Date(timeIntervalSince1970: 200))
        // (B) 今日 / createdAt 同一 / id 違い → id 降順で並ぶ
        let lowID  = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let highID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
        let b1 = WeightEntry(id: lowID, date: todayMorning,
                             weightKilograms: 63.0, createdAt: sameCreatedAt)
        let b2 = WeightEntry(id: highID, date: todayMorning,
                             weightKilograms: 62.0, createdAt: sameCreatedAt)
        // 順番ぐちゃぐちゃに insert (y を真ん中に挟んで date 優先性を検証)
        context.insert(b1); context.insert(a1); context.insert(y)
        context.insert(b2); context.insert(a2)
        try context.save()
        store.fetchEntries()

        // 期待順序 (新→古):
        //   今日: createdAt 500 グループ (b2 → b1) → createdAt 200 (a2) → createdAt 100 (a1)
        //   昨日: y (createdAt が一番新しいが date が前なので最後)
        // → [62.0 (b2), 63.0 (b1), 64.0 (a2), 65.0 (a1), 70.0 (y)]
        let firstWeights = store.entries.map(\.weightKilograms)
        let expectedOrder: [Double] = [62.0, 63.0, 64.0, 65.0, 70.0]
        #expect(firstWeights == expectedOrder,
                "date 降順 → createdAt 降順 → id 降順: \(firstWeights)")
        #expect(store.entries.last?.weightKilograms == 70.0,
                "昨日のエントリは createdAt が新しくても date 優先で末尾に来る")

        // 再 fetch しても同じ順序になることを 3 回確認
        for round in 1...3 {
            store.fetchEntries()
            #expect(store.entries.map(\.weightKilograms) == expectedOrder,
                    "fetch round \(round) でも同じ順序")
        }

        // chartEntries (日内最新採用) は今日の先頭 62.0 と昨日の 70.0 = 2 件
        let chart = store.chartEntries(period: .week, today: today)
        #expect(chart.count == 2)
        #expect(chart.first?.weightKilograms == 62.0, "今日の日内最新")
        #expect(chart.last?.weightKilograms == 70.0, "昨日の唯一の記録")
    }

    /// 目標未設定 / 体重 0 件 / トレンド不足 などは nil。
    @Test
    func forecast_insufficientInputs_returnNil() throws {
        let (store, _, prefs) = try makeStore()
        let today = Date()
        // 体重 0 件 + 目標未設定
        #expect(store.forecastDaysToTarget(today: today) == nil)
        // 目標だけ設定でも体重がない → nil
        prefs.targetKilograms = 60.0
        #expect(store.forecastDaysToTarget(today: today) == nil)
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
