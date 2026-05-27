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
    /// 閾値拡充 (10/30/50/100/200/...) 反映時のサイレントマイグレーション完了フラグ。
    /// 旧 [30, 100, 365] 時代のユーザーがアップグレード後に過去の達成画面を
    /// 大量に見せられないよう、既に通過済みのマイルストーンを暗黙的に
    /// acknowledged に流し込むため。
    static let migratedExpandedThresholdsKey = "milestones.migrated.expandedThresholds.v1"

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
        // 閾値拡充版に上げた直後の既存ユーザー保護:
        // 既に通過済みのマイルストーンをサイレントに acknowledged 化して、
        // 次の本物の達成からだけ celebration を出すようにする (Codex 指摘)。
        migrateExpandedThresholdsIfNeeded(firstUseDate: firstUseDate, today: today,
                                          lifetimeAchieved: lifetimeAchieved,
                                          currentStreak: currentStreak)

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
        defaults.removeObject(forKey: Self.migratedExpandedThresholdsKey)
    }

    /// 旧マイルストーン定義 ([30, 100, 365]) からの拡充直後、既存の高ストリーク
    /// ユーザーに過去達成済みのお祝いを連発しないようサイレントに飲み込む。
    /// 1 回だけ実行 (defaults flag でガード)。
    private func migrateExpandedThresholdsIfNeeded(
        firstUseDate: Date, today: Date,
        lifetimeAchieved: Int, currentStreak: Int
    ) {
        guard !defaults.bool(forKey: Self.migratedExpandedThresholdsKey) else { return }
        var ack = acknowledgedKeys()
        // 現時点で既に通過済みの全マイルストーンを silent ack。
        // 「次に到達する新しい節目」(例: 350 のユーザーが 400 に到達したとき)
        // から celebration が再開する。
        for m in candidates(firstUseDate: firstUseDate, today: today,
                            lifetimeAchieved: lifetimeAchieved,
                            currentStreak: currentStreak) {
            ack.insert(key(for: m))
        }
        defaults.set(Array(ack), forKey: Self.acknowledgedKey)
        defaults.set(true, forKey: Self.migratedExpandedThresholdsKey)
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
        // 初期 (10/30/50) は短期で達成感を刻んで習慣化を後押し、100 以降は
        // 100 単位で「節目」感を強める設計 (ユーザー要望)。
        for target in Self.currentStreakMilestones(upTo: currentStreak) {
            result.append(.currentStreak(target))
        }

        return result
    }

    /// `currentStreak` が達した可能性のあるマイルストーン値を昇順で返す。
    /// `[10, 30, 50, 100, 200, 300, 400, ...]` を `currentStreak` 以下まで。
    /// 100 以降は 100 単位で機械的に進むので閾値定義に上限を持たせない。
    /// 純関数なので `nonisolated` でテストから自由に呼べるようにする。
    nonisolated static func currentStreakMilestones(upTo current: Int) -> [Int] {
        guard current >= 10 else { return [] }
        var result: [Int] = []
        for t in [10, 30, 50] where current >= t { result.append(t) }
        // 100 単位は理論上無限に続くが、現実的に到達する 100..2000 程度で打ち切る
        // (= 5 年半連続、これ以上は別のシステムで祝うべきオーバーキル領域)。
        var t = 100
        while t <= 2000, current >= t {
            result.append(t)
            t += 100
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
