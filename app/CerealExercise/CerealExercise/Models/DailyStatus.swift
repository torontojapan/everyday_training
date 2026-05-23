import Foundation

enum DailyStatus: String, Codable, CaseIterable, Sendable {
    case achieved
    case rest
    case missed
    case future
    case todayPending
    case todayAchieved

    var symbol: String {
        switch self {
        case .achieved: "○"
        case .rest: "休"
        case .missed: "×"
        case .future: "-"
        case .todayPending: "・"
        case .todayAchieved: "◎"
        }
    }

    var countsAsAchieved: Bool {
        self == .achieved || self == .rest || self == .todayAchieved
    }
}

struct DailyStatusEntry: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let status: DailyStatus
    let recordIds: [UUID]
}

struct StreakState: Equatable, Sendable {
    let currentStreak: Int
    let longestStreak: Int
    let lastAchievedDate: Date?
}

struct WeeklyProgress: Equatable, Sendable {
    let achievedCount: Int
    let totalDays: Int

    var rate: Double {
        guard totalDays > 0 else { return 0 }
        return Double(achievedCount) / Double(totalDays)
    }
}
