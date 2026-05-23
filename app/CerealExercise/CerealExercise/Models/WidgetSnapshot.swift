import Foundation

struct WidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let todayAchieved: Bool
    let isRestDay: Bool
    let currentStreak: Int
    let weeklyAchieved: Int
    let weeklyTotal: Int
    let catState: String
    let message: String
    let nightDeadlineHoursLeft: Int

    static func make(
        generatedAt: Date,
        todayAchieved: Bool,
        isRestDay: Bool,
        currentStreak: Int,
        weeklyAchieved: Int,
        weeklyTotal: Int,
        catState: CatState,
        message: String,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let startOfDay = calendar.startOfDay(for: generatedAt)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? generatedAt
        let endOfDay = calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? generatedAt
        let hoursLeft = max(0, calendar.dateComponents([.hour], from: generatedAt, to: endOfDay).hour ?? 0)

        return WidgetSnapshot(
            generatedAt: generatedAt,
            todayAchieved: todayAchieved,
            isRestDay: isRestDay,
            currentStreak: currentStreak,
            weeklyAchieved: weeklyAchieved,
            weeklyTotal: weeklyTotal,
            catState: catState.rawValue,
            message: message,
            nightDeadlineHoursLeft: hoursLeft
        )
    }
}
