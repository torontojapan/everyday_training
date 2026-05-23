import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WorkoutStore {
    private let context: ModelContext
    private let dateProvider: any DateProviding
    private let calendar: Calendar

    private(set) var records: [WorkoutRecord] = []
    private(set) var lastErrorMessage: String?

    init(context: ModelContext, dateProvider: any DateProviding = SystemDateProvider(), calendar: Calendar = .mondayFirst) {
        self.context = context
        self.dateProvider = dateProvider
        self.calendar = calendar
        fetchRecords()
    }

    var today: Date {
        calendar.startOfDay(for: dateProvider.currentDate())
    }

    func fetchRecords() {
        let descriptor = FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        do {
            records = try context.fetch(descriptor)
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "記録の読み込みに失敗しました"
            records = []
        }
    }

    @discardableResult
    func add(category: WorkoutCategory, exercises: [ExerciseItem], memo: String?) -> WorkoutRecord {
        let record = WorkoutRecord(date: today, category: category, exercises: exercises, memo: memo, calendar: calendar)
        context.insert(record)
        save()
        return record
    }

    func save() {
        do {
            try context.save()
            fetchRecords()
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = "保存に失敗しました"
        }
    }
}
