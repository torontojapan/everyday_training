import Foundation

enum CatStateResolver {
    static func resolve(
        todayStatus: DailyStatus,
        now: Date,
        yesterdayAchieved: Bool,
        streakExtendedThisRun: Bool,
        calendar: Calendar = .current
    ) -> CatState {
        if streakExtendedThisRun {
            return .streakExtended
        }

        if todayStatus == .todayAchieved || todayStatus == .achieved {
            return .celebrating
        }

        if todayStatus == .rest {
            return .resting
        }

        if todayStatus == .todayPending, !yesterdayAchieved {
            return .encouraging
        }

        let hour = calendar.component(.hour, from: now)
        switch hour {
        case ..<12:
            return .waitingMorning
        case 12..<18:
            return .worriedNoon
        default:
            return .beggingNight
        }
    }
}
