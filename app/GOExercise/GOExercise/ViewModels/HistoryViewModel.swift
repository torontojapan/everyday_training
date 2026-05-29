import Foundation
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    private let calendar: Calendar

    private(set) var groupedByDate: [(Date, [WorkoutRecord])] = []

    init(calendar: Calendar = .mondayFirst) {
        self.calendar = calendar
    }

    func refresh(records: [WorkoutRecord]) {
        let grouped = Dictionary(grouping: records) { record in
            calendar.startOfDay(for: record.date)
        }
        groupedByDate = grouped
            .map { date, records in
                (date, records.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.0 > $1.0 }
    }
}
