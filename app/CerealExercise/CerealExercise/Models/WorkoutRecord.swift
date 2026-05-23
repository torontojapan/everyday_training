import Foundation
import SwiftData

@Model
final class WorkoutRecord: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var categoryRaw: String
    var exercisesData: Data
    var memo: String?
    var createdAt: Date
    var updatedAt: Date

    var category: WorkoutCategory {
        get { WorkoutCategory(rawValue: categoryRaw) ?? .other }
        set {
            categoryRaw = newValue.rawValue
            updatedAt = Date()
        }
    }

    var exercises: [ExerciseItem] {
        get {
            (try? JSONDecoder().decode([ExerciseItem].self, from: exercisesData)) ?? []
        }
        set {
            exercisesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
        }
    }

    init(
        id: UUID = UUID(),
        date: Date,
        category: WorkoutCategory,
        exercises: [ExerciseItem],
        memo: String? = nil,
        calendar: Calendar = .current,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.categoryRaw = category.rawValue
        self.exercisesData = (try? JSONEncoder().encode(exercises)) ?? Data()
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
