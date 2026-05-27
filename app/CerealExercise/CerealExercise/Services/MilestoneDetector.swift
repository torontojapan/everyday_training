import Foundation

enum Milestone: Equatable, Sendable {
    case anniversary(years: Int)
    case lifetimeDays(Int)        // 100, 365, 1000, ...
    case currentStreak(Int)       // 30, 100, 365

    var headline: String {
        switch self {
        case .anniversary(let years): return "\(years)周年おめでとう!"
        case .lifetimeDays(let d): return "累計 \(d) 日達成!"
        case .currentStreak(let d): return "連続 \(d) 日達成!"
        }
    }

    var emoji: String {
        switch self {
        case .anniversary: return "🎉"
        case .lifetimeDays(let d) where d >= 365: return "🏆"
        case .lifetimeDays: return "🎖️"
        case .currentStreak(let d) where d >= 100: return "🔥"
        case .currentStreak: return "✨"
        }
    }

    var detail: String {
        switch self {
        case .anniversary(let years):
            return "GOエクササイズを始めてから\(years)周年です。ここまでよくがんばったね!"
        case .lifetimeDays(let d):
            return "通算 \(d) 日の運動を達成しました。続けることに大きな意味があります。"
        case .currentStreak(let d):
            return "\(d) 日連続で運動を続けています。すごい習慣力!"
        }
    }

    /// SNS シェア用の本文。emoji + 達成見出し + 軽い招待コピー。
    /// 末尾には ShareLink が URL を付加するので URL は含めない (二重貼り防止)。
    /// 140 字以内に収めて Twitter (X) のプレビュー切れも避ける。
    var shareMessage: String {
        switch self {
        case .anniversary(let years):
            return "\(emoji) GOエクササイズ \(years)周年達成！ねこ達とゆるく運動習慣を続けてます。一緒にやろう"
        case .lifetimeDays(let d):
            return "\(emoji) GOエクササイズで通算 \(d) 日達成！ねこ達とゆるく続けてます。一緒にやろう"
        case .currentStreak(let d):
            return "\(emoji) GOエクササイズで \(d) 日連続達成！ねこ達とゆるく運動習慣つくってます"
        }
    }

    /// メールアプリでシェアした場合の件名 (Twitter 等では使われない)。
    var shareSubject: String { headline }
}

@MainActor
final class MilestoneDetector {
    static let acknowledgedKey = "milestones.acknowledged"

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
    }

    /// Returns the next milestone the user hasn't been congratulated on yet, if any.
    func nextPending(
        records: [WorkoutRecord],
        firstUseDate: Date,
        today: Date,
        lifetimeAchieved: Int,
        currentStreak: Int
    ) -> Milestone? {
        let acknowledged = acknowledgedKeys()

        for milestone in candidates(firstUseDate: firstUseDate, today: today,
                                    lifetimeAchieved: lifetimeAchieved,
                                    currentStreak: currentStreak) {
            if !acknowledged.contains(key(for: milestone)) {
                return milestone
            }
        }
        return nil
    }

    func acknowledge(_ milestone: Milestone) {
        var acknowledged = acknowledgedKeys()
        acknowledged.insert(key(for: milestone))
        defaults.set(Array(acknowledged), forKey: Self.acknowledgedKey)
    }

    func clear() {
        defaults.removeObject(forKey: Self.acknowledgedKey)
    }

    private func candidates(firstUseDate: Date, today: Date, lifetimeAchieved: Int, currentStreak: Int) -> [Milestone] {
        var result: [Milestone] = []

        // Anniversary (1, 2, 3 ... years).
        let years = calendar.dateComponents([.year], from: firstUseDate, to: today).year ?? 0
        if years >= 1 {
            result.append(.anniversary(years: years))
        }

        // Lifetime totals.
        for target in [100, 365, 500, 1000] {
            if lifetimeAchieved >= target {
                result.append(.lifetimeDays(target))
            }
        }

        // Current streak.
        for target in [30, 100, 365] {
            if currentStreak >= target {
                result.append(.currentStreak(target))
            }
        }

        return result
    }

    private func acknowledgedKeys() -> Set<String> {
        Set((defaults.array(forKey: Self.acknowledgedKey) as? [String]) ?? [])
    }

    private func key(for milestone: Milestone) -> String {
        switch milestone {
        case .anniversary(let years): return "anniv.\(years)"
        case .lifetimeDays(let d): return "lifetime.\(d)"
        case .currentStreak(let d): return "streak.\(d)"
        }
    }
}
