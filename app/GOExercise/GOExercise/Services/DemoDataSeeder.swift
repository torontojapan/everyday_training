import Foundation
import OSLog
import SwiftData

private let seederLogger = Logger(subsystem: "com.goexercise.app", category: "DemoDataSeeder")

enum DemoScenario: String {
    case basic
    case streakBroken = "streak-broken"
    case longStreak = "long-streak"
    case monthBoundary = "month-boundary"
    case empty
    case edgeMinute = "edge-minute"
    // --- 達成リデザイン A〜F の実機/sim検証用(DEBUG・各ランク/復活を即出し)---
    /// 連続7日(rank1 みならいネコ・bronze)。
    case rank7 = "rank-7"
    /// 連続100日(rank6 つわものネコ・gold)。
    case rank100 = "rank-100"
    /// 連続500日(rank11 ぬしネコ・rainbow)。
    case rank500 = "rank-500"
    /// 直近で連続が途切れた「4日グレース内」=復活ポップ(D)が出る状態。
    case revive = "revive"
    /// 1 ヶ月使い込んだ状態を全機能のせて再現する demo シナリオ。
    /// - 30 日連続ワークアウト (種目バリエーション)
    /// - 30 日分の体重記録 (緩やかな減量曲線 + 朝晩の二重記録で同日複数記録機能を可視化)
    /// - 5 日分の生理エントリ
    /// - 身長 / 目標体重 / 開始体重を userDefaults に保存 (BMI / 進捗バー / 予測日が出る)
    case monthly
    /// 1 年 (365 日) フルに使い込んだ状態。手動 QA 用に「ぜんぶ満タン」のシナリオ。
    /// - 365 日連続ワークアウト (種目テンプレートをローテで多様性確保)
    /// - 365 日分の体重 (75kg → 65kg 線形減量 + ノイズ + 偶数日 2 件)
    /// - 13 周期 × 5 日 の生理エントリ (1 年全期間に渡る周期オーバーレイ)
    /// - 身長 168 / 開始 75 / 目標 65 → BMI / 進捗 100% に向かう
    /// - 過去 6 ヶ月で 6 枚の保険チケット使用済履歴 (履歴画面で確認できる)
    /// - 365 日達成によりほぼ全 milestone が migrate により acknowledged 化
    case yearly
}

@MainActor
enum DemoDataSeeder {
    static func seed(
        context: ModelContext,
        today: Date,
        scenario: DemoScenario = .basic,
        calendar: Calendar = .mondayFirst
    ) {
        let descriptor = FetchDescriptor<WorkoutRecord>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let todayStart = calendar.startOfDay(for: today)

        switch scenario {
        case .basic:
            seedBasic(context: context, todayStart: todayStart, calendar: calendar)
        case .streakBroken:
            seedStreakBroken(context: context, todayStart: todayStart, calendar: calendar)
        case .longStreak:
            seedLongStreak(context: context, todayStart: todayStart, calendar: calendar)
            seedMenstrualSamples(context: context, todayStart: todayStart, calendar: calendar)
        case .monthBoundary:
            seedMonthBoundary(context: context, todayStart: todayStart, calendar: calendar)
        case .empty:
            break
        case .edgeMinute:
            seedEdgeMinute(context: context, todayStart: todayStart, calendar: calendar)
        case .rank7:
            seedConsecutive(days: 7, context: context, todayStart: todayStart, calendar: calendar)
        case .rank100:
            seedConsecutive(days: 100, context: context, todayStart: todayStart, calendar: calendar)
        case .rank500:
            seedConsecutive(days: 500, context: context, todayStart: todayStart, calendar: calendar)
        case .revive:
            seedReviveWindow(context: context, todayStart: todayStart, calendar: calendar)
        case .monthly:
            seedLongStreak(context: context, todayStart: todayStart, calendar: calendar)
            // 周期オーバーレイがチャート全期間に渡って描けるよう、
            // 直近 (5..9 日前) + 1 周期前 (33..37 日前) の 2 周期分を seed。
            seedMenstrualSamples(context: context, todayStart: todayStart, calendar: calendar)
            for offset in 33...37 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                context.insert(MenstrualEntry(date: day, calendar: calendar))
            }
            seedMonthlyWeight(context: context, todayStart: todayStart, calendar: calendar)
            seedHealthPreferences()
            // 体重 chart の周期オーバーレイがデモ画面に出るよう opt-in を有効化。
            CycleTrackingSettings().isEnabled = true
        case .yearly:
            seedYearlyWorkouts(context: context, todayStart: todayStart, calendar: calendar)
            seedYearlyMenstrual(context: context, todayStart: todayStart, calendar: calendar)
            seedYearlyWeight(context: context, todayStart: todayStart, calendar: calendar)
            seedYearlyHealthPreferences()
            seedYearlyRescueTicketHistory(todayStart: todayStart, calendar: calendar)
            CycleTrackingSettings().isEnabled = true
        }

        do {
            try context.save()
        } catch {
            // Surface seed failures in Console.app so we can diagnose
            // half-seeded scenarios instead of failing silently and leaving
            // the user with a partly-populated demo state.
            seederLogger.error("Demo data save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func standardTemplates() -> [(WorkoutCategory, [ExerciseItem])] {
        [
            (.strength, [
                ExerciseItem(id: UUID(), name: "スクワット", durationSeconds: nil, reps: 20, sets: 3, memo: nil),
                ExerciseItem(id: UUID(), name: "腕立て伏せ", durationSeconds: nil, reps: 10, sets: 2, memo: nil)
            ]),
            (.cardio, [
                ExerciseItem(id: UUID(), name: "ジョギング", durationSeconds: 1200, reps: nil, sets: nil, memo: "公園周回")
            ]),
            (.yoga, [
                ExerciseItem(id: UUID(), name: "太陽礼拝", durationSeconds: 600, reps: nil, sets: nil, memo: nil)
            ]),
            (.stretch, [
                ExerciseItem(id: UUID(), name: "前屈ストレッチ", durationSeconds: 180, reps: nil, sets: 2, memo: nil),
                ExerciseItem(id: UUID(), name: "肩回し", durationSeconds: 120, reps: nil, sets: 2, memo: nil)
            ])
        ]
    }

    private static func insertRecord(
        context: ModelContext,
        date: Date,
        templateIndex: Int,
        calendar: Calendar
    ) {
        let templates = standardTemplates()
        let pick = templates[templateIndex % templates.count]
        let record = WorkoutRecord(
            date: date,
            category: pick.0,
            exercises: pick.1,
            memo: nil,
            calendar: calendar
        )
        context.insert(record)
    }

    /// Seed a 5-day stretch of menstrual entries roughly a week back. Used
    /// alongside the long-streak workout data so the demo state on screen
    /// shots and dev sessions clearly demonstrates the cycle tracking UI.
    private static func seedMenstrualSamples(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 5...9 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            context.insert(MenstrualEntry(date: day, calendar: calendar))
        }
    }

    private static func seedBasic(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 0..<12 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    private static func seedStreakBroken(context: ModelContext, todayStart: Date, calendar: Calendar) {
        // 3 週間前から 2 週間前は連続達成、今週は完全に空にして streak を確実に切る。
        // (今日が月曜のときに月曜だけ achieved で streak=1 になってしまうのを避ける)
        for offset in 14...20 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    private static func seedLongStreak(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    /// 今日を含む直近 `days` 日を連続達成にする(連続日数 = days)。
    /// 達成リデザイン検証用: rank の背景(A)・称号(C)・初回起動時の昇格トースト(B)を確認できる。
    private static func seedConsecutive(days: Int, context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    /// 「直近で連続が途切れた(4日グレース内)」状態を作る。復活ポップ(D)検証用。
    /// 直近4日(今日含む)を空け、その手前は十分長い連続にする。rest 自動補完(週2)を
    /// 超える非達成日が現在週に生じるよう、今日が週後半なら yesterday が missed になる。
    /// (週前半に当たって popup が出ない場合は別途 `--force-revive` で確認可)
    private static func seedReviveWindow(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 4..<44 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    private static func seedMonthBoundary(context: ModelContext, todayStart: Date, calendar: Calendar) {
        // 過去 14 日連続で記録 (月またぎ確認)
        for offset in 0..<14 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            insertRecord(context: context, date: day, templateIndex: offset, calendar: calendar)
        }
    }

    /// 30 日分の体重エントリを「緩やかな減量 + 自然なゆらぎ + 同日 2 件」で作る。
    /// 出発点: 68.0kg、ゴール: 65.0kg 付近 (slope 約 -0.1kg/日)。
    /// - 偶数日には朝/夜の 2 件、奇数日には 1 件のみ → 履歴で時刻表示と
    ///   日内最新集約 (グラフ) の両方が可視化される。
    /// - 7 日移動平均トレンドが綺麗に出るよう、ゆらぎは ±0.2kg に抑える。
    private static func seedMonthlyWeight(context: ModelContext, todayStart: Date, calendar: Calendar) {
        // 既存の体重エントリがあれば skip (再 seed で増殖しないように)。
        let weightDesc = FetchDescriptor<WeightEntry>()
        if let existing = try? context.fetch(weightDesc), !existing.isEmpty { return }

        let startKg = 68.0
        let endKg = 65.2
        let days = 30
        let slope = (endKg - startKg) / Double(days - 1) // kg/日 (負)
        // 決定論的な擬似ノイズ。乱数を使うとスクショ間で揺らぐので index ベース。
        let noisePattern: [Double] = [0.0, 0.18, -0.12, 0.05, -0.20, 0.10, 0.00, 0.15, -0.08, 0.12,
                                       -0.18, 0.04, 0.00, 0.20, -0.10, 0.08, -0.05, 0.16, -0.14, 0.06,
                                       0.00, 0.10, -0.18, 0.04, 0.12, -0.06, 0.00, 0.08, -0.10, 0.05]

        for offset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            // offset = 0 が今日。線形回帰用の "日付ベース x" は 29 - offset (古いほど小さい)。
            let x = Double(days - 1 - offset)
            let baseWeight = startKg + slope * x + noisePattern[offset]
            // 朝の記録 (07:00)
            let morning = dayStart.addingTimeInterval(7 * 3600)
            context.insert(WeightEntry(date: morning, weightKilograms: baseWeight, memo: nil))
            // 偶数日は夜の記録も入れる (朝より 0.3kg 軽い = 体内の自然な乾燥)
            if offset.isMultiple(of: 2) {
                let evening = dayStart.addingTimeInterval(21 * 3600)
                context.insert(WeightEntry(date: evening, weightKilograms: baseWeight - 0.3,
                                            memo: offset == 0 ? "夕食後" : nil))
            }
        }
    }

    /// 身長 / 開始体重 / 目標体重 を userDefaults に保存。
    /// これで BMI 表示・進捗バー・目標達成予測の全てが UI に出る。
    private static func seedHealthPreferences() {
        let prefs = UserHealthPreferences.shared
        // 既に値があればユーザー設定を尊重して上書きしない (再 seed 安全)。
        if prefs.heightCentimeters == nil { prefs.heightCentimeters = 168 }
        if prefs.startKilograms == nil { prefs.startKilograms = 68.0 }
        if prefs.targetKilograms == nil { prefs.targetKilograms = 64.0 }
    }

    /// 365 日連続のワークアウト。種目テンプレートを回しつつ、月の境目で
    /// 種目バランスが少しずつ変わるよう offset を 2 つの素数で混ぜる。
    private static func seedYearlyWorkouts(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for offset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            // 種目を「曜日 (offset % 7) + 月 (offset / 30 を素数 3 で回す)」で変化
            let weekdayBias = offset % 7
            let monthBias = (offset / 30) * 3
            insertRecord(context: context, date: day,
                         templateIndex: weekdayBias + monthBias, calendar: calendar)
        }
    }

    /// 13 周期 × 5 日。今日から 5 日前を初回、その後 28 日周期で過去 1 年に並べる。
    private static func seedYearlyMenstrual(context: ModelContext, todayStart: Date, calendar: Calendar) {
        for cycle in 0..<13 {
            let cycleStart = 5 + cycle * 28  // 直近周期: -5..-9, 次: -33..-37, ...
            for d in 0..<5 {
                let offset = cycleStart + d
                guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
                context.insert(MenstrualEntry(date: day, calendar: calendar))
            }
        }
    }

    /// 365 日分の体重。75kg → 65kg の線形 + 決定論的ノイズ + 偶数日 2 件記録。
    /// monthly と同じく非乱数で再現性を担保。
    private static func seedYearlyWeight(context: ModelContext, todayStart: Date, calendar: Calendar) {
        let weightDesc = FetchDescriptor<WeightEntry>()
        if let existing = try? context.fetch(weightDesc), !existing.isEmpty { return }

        let startKg = 75.0
        let endKg = 65.0
        let days = 365
        let slope = (endKg - startKg) / Double(days - 1)
        // 30 要素のノイズ循環。offset % 30 で展開する。
        let noisePattern: [Double] = [0.0, 0.18, -0.12, 0.05, -0.20, 0.10, 0.00, 0.15, -0.08, 0.12,
                                       -0.18, 0.04, 0.00, 0.20, -0.10, 0.08, -0.05, 0.16, -0.14, 0.06,
                                       0.00, 0.10, -0.18, 0.04, 0.12, -0.06, 0.00, 0.08, -0.10, 0.05]

        for offset in 0..<days {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let x = Double(days - 1 - offset)
            let base = startKg + slope * x + noisePattern[offset % 30]
            let morning = dayStart.addingTimeInterval(7 * 3600)
            context.insert(WeightEntry(date: morning, weightKilograms: base, memo: nil))
            if offset.isMultiple(of: 2) {
                let evening = dayStart.addingTimeInterval(21 * 3600)
                context.insert(WeightEntry(date: evening, weightKilograms: base - 0.3, memo: nil))
            }
        }
    }

    /// 開始 75kg / 目標 65kg / 身長 168cm。
    /// (monthly は 68→64kg だが yearly は 1 年分の幅で見せたいので 75→65 にする)
    private static func seedYearlyHealthPreferences() {
        let prefs = UserHealthPreferences.shared
        if prefs.heightCentimeters == nil { prefs.heightCentimeters = 168 }
        if prefs.startKilograms == nil { prefs.startKilograms = 75.0 }
        if prefs.targetKilograms == nil { prefs.targetKilograms = 65.0 }
    }

    /// 過去 6 ヶ月、月初付近で 1 枚ずつ保険チケットを使用した履歴。
    /// 履歴画面の保険チケットセクションで「過去使った日」が見えるようにする。
    private static func seedYearlyRescueTicketHistory(todayStart: Date, calendar: Calendar) {
        let defaults = UserDefaults.standard
        var dates = (defaults.array(forKey: RescueTicketStore.usedDatesKey) as? [Double]) ?? []
        for monthsBack in 1...6 {
            guard let monthBack = calendar.date(byAdding: .month, value: -monthsBack, to: todayStart),
                  let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: monthBack)),
                  let midMonth = calendar.date(byAdding: .day, value: 14, to: firstOfMonth) else { continue }
            dates.append(calendar.startOfDay(for: midMonth).timeIntervalSince1970)
        }
        defaults.set(dates, forKey: RescueTicketStore.usedDatesKey)
    }

    private static func seedEdgeMinute(context: ModelContext, todayStart: Date, calendar: Calendar) {
        // ちょうど 60 秒 (1分) の記録 → 達成
        let exactly60 = WorkoutRecord(
            date: todayStart,
            category: .stretch,
            exercises: [ExerciseItem(id: UUID(), name: "肩回し", durationSeconds: 60, reps: nil, sets: nil, memo: "ちょうど1分")],
            memo: nil,
            calendar: calendar
        )
        context.insert(exactly60)

        // 昨日: 59 秒の記録 (1分未満、種目1件あり → 1種目以上ルールで達成扱い)
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) {
            let just59 = WorkoutRecord(
                date: yesterday,
                category: .stretch,
                exercises: [ExerciseItem(id: UUID(), name: "深呼吸", durationSeconds: 59, reps: nil, sets: nil, memo: "59秒")],
                memo: nil,
                calendar: calendar
            )
            context.insert(just59)
        }
    }
}
