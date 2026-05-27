import Foundation
import OSLog
import SwiftData

private let seederLogger = Logger(subsystem: "com.serial.cerealexercise", category: "DemoDataSeeder")

enum DemoScenario: String {
    case basic
    case streakBroken = "streak-broken"
    case longStreak = "long-streak"
    case monthBoundary = "month-boundary"
    case empty
    case edgeMinute = "edge-minute"
    /// 1 ヶ月使い込んだ状態を全機能のせて再現する demo シナリオ。
    /// - 30 日連続ワークアウト (種目バリエーション)
    /// - 30 日分の体重記録 (緩やかな減量曲線 + 朝晩の二重記録で同日複数記録機能を可視化)
    /// - 5 日分の生理エントリ
    /// - 身長 / 目標体重 / 開始体重を userDefaults に保存 (BMI / 進捗バー / 予測日が出る)
    case monthly
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
        case .monthly:
            seedLongStreak(context: context, todayStart: todayStart, calendar: calendar)
            seedMenstrualSamples(context: context, todayStart: todayStart, calendar: calendar)
            seedMonthlyWeight(context: context, todayStart: todayStart, calendar: calendar)
            seedHealthPreferences()
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
