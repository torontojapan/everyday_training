import Foundation

enum DailyStatus: String, Codable, CaseIterable, Sendable {
    case achieved
    case rest
    case missed
    case future
    case todayPending
    case todayAchieved
    /// フリーズ(保険チケット)で救済された日。達成扱いだが「実際に運動した日(◎)」とは
    /// 表示を分ける(ユーザー要望: ◎=実運動 / ○=フリーズ / 休=休養日)。
    case rescued

    var symbol: String {
        switch self {
        case .achieved: "◎"
        case .rescued: "○"
        case .rest: "休"
        case .missed: "×"
        case .future: "-"
        case .todayPending: "・"
        case .todayAchieved: "◎"
        }
    }

    var countsAsAchieved: Bool {
        self == .achieved || self == .rest || self == .todayAchieved || self == .rescued
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
