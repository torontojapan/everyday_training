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
    /// `@ObservationIgnored nonisolated(unsafe)`: 観測対象外にし、MainActor 隔離
    /// deinit から removeObserver できるようにする。代入は init (MainActor) のみ、
    /// deinit 読み取りは最終 1 回なので実質レースしない (StoreKitManager と同方針)。
    @ObservationIgnored private nonisolated(unsafe) var resetObserver: NSObjectProtocol?

    init(context: ModelContext, dateProvider: any DateProviding = SystemDateProvider(), calendar: Calendar = .mondayFirst) {
        self.context = context
        self.dateProvider = dateProvider
        self.calendar = calendar
        fetchRecords()
        // 全記録削除後、削除済みオブジェクトを掴んだままにならないよう再フェッチ。
        resetObserver = NotificationCenter.default.addObserver(
            forName: .goDataDidReset, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetchRecords() }
        }
    }

    deinit {
        if let resetObserver {
            NotificationCenter.default.removeObserver(resetObserver)
        }
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
