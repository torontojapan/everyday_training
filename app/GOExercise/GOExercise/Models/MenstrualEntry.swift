import Foundation
import SwiftData

@Model
final class MenstrualEntry {
    @Attribute(.unique) var id: UUID
    var date: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        calendar: Calendar = .current,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.createdAt = createdAt
    }
}
