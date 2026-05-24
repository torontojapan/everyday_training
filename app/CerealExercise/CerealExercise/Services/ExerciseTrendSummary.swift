import Foundation

@MainActor
enum ExerciseTrendSummary {
    struct DailySummary: Equatable {
        let categoryCounts: [WorkoutCategory: Int]
        let exerciseCount: Int
        let totalDurationSeconds: Int

        var hasExerciseData: Bool {
            exerciseCount > 0
        }
    }

    struct WeeklySummary: Equatable {
        let usedCategories: [WorkoutCategory]
        let totalDurationSeconds: Int
        let topExerciseNames: [String]

        var hasExerciseData: Bool {
            !usedCategories.isEmpty || totalDurationSeconds > 0 || !topExerciseNames.isEmpty
        }
    }

    static func today(records: [WorkoutRecord], today: Date, calendar: Calendar) -> DailySummary {
        let matchingRecords = records.filter { calendar.isDate($0.date, inSameDayAs: today) }
        return dailySummary(from: matchingRecords)
    }

    static func week(records: [WorkoutRecord], week: DateInterval, calendar: Calendar) -> WeeklySummary {
        let matchingRecords = records.filter { record in
            let dayStart = calendar.startOfDay(for: record.date)
            return week.start <= dayStart && dayStart < week.end
        }

        let usedCategorySet = Set(matchingRecords.map(\.category))
        let usedCategories = WorkoutCategory.allCases.filter { usedCategorySet.contains($0) }
        let totalDurationSeconds = matchingRecords.flatMap(\.exercises).compactMap(\.durationSeconds).reduce(0, +)
        let exerciseNameCounts = matchingRecords
            .flatMap(\.exercises)
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: [String: Int]()) { counts, name in
                counts[name, default: 0] += 1
            }
        let topExerciseNames = exerciseNameCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map(\.key)

        return WeeklySummary(
            usedCategories: usedCategories,
            totalDurationSeconds: totalDurationSeconds,
            topExerciseNames: topExerciseNames
        )
    }

    private static func dailySummary(from records: [WorkoutRecord]) -> DailySummary {
        let categoryCounts = records.reduce(into: [WorkoutCategory: Int]()) { counts, record in
            counts[record.category, default: 0] += 1
        }
        let exercises = records.flatMap(\.exercises)
        let totalDurationSeconds = exercises.compactMap(\.durationSeconds).reduce(0, +)

        return DailySummary(
            categoryCounts: categoryCounts,
            exerciseCount: exercises.count,
            totalDurationSeconds: totalDurationSeconds
        )
    }
}
