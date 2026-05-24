import Foundation
import SwiftData

@Model
final class WeightEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weightKilograms: Double
    var memo: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        weightKilograms: Double,
        memo: String? = nil,
        calendar: Calendar = .current,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = calendar.startOfDay(for: date)
        self.weightKilograms = weightKilograms
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
