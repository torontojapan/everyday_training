import Foundation

struct SharedSnapshotStore {
    static let appGroupIdentifier = "group.com.goexercise.app"
    static let snapshotKey = "widget.snapshot"

    private let defaults: UserDefaults?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)) {
        self.defaults = defaults
    }

    func write(_ snapshot: WidgetSnapshot) -> Bool {
        guard let data = try? encoder.encode(snapshot) else { return false }
        defaults?.set(data, forKey: Self.snapshotKey)
        return defaults != nil
    }

    func read() -> WidgetSnapshot {
        guard
            let data = defaults?.data(forKey: Self.snapshotKey),
            let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data)
        else {
            return Self.fallbackSnapshot()
        }
        return snapshot
    }

    static func fallbackSnapshot(now: Date = Date(), calendar: Calendar = .current) -> WidgetSnapshot {
        WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: false,
            isRestDay: false,
            currentStreak: 0,
            weeklyAchieved: 0,
            weeklyTotal: 7,
            catState: .waitingMorning,
            message: "今日の運動、まだ待ってるよ",
            calendar: calendar
        )
    }
}
