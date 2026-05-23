import Foundation
import SwiftData

@MainActor
enum DemoDataSeeder {
    static func seed(context: ModelContext, today: Date, calendar: Calendar = .mondayFirst) {
        let descriptor = FetchDescriptor<WorkoutRecord>()
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let templates: [(WorkoutCategory, [ExerciseItem])] = [
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

        let todayStart = calendar.startOfDay(for: today)
        for offset in 0..<12 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: todayStart) else { continue }
            let pick = templates[offset % templates.count]
            let record = WorkoutRecord(
                date: day,
                category: pick.0,
                exercises: pick.1,
                memo: nil,
                calendar: calendar
            )
            context.insert(record)
        }

        try? context.save()
    }
}
