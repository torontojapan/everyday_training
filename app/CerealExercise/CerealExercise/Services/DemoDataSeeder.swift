import Foundation
import SwiftData

enum DemoScenario: String {
    case basic
    case streakBroken = "streak-broken"
    case longStreak = "long-streak"
    case monthBoundary = "month-boundary"
    case empty
    case edgeMinute = "edge-minute"
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
        case .monthBoundary:
            seedMonthBoundary(context: context, todayStart: todayStart, calendar: calendar)
        case .empty:
            break
        case .edgeMinute:
            seedEdgeMinute(context: context, todayStart: todayStart, calendar: calendar)
        }

        try? context.save()
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
