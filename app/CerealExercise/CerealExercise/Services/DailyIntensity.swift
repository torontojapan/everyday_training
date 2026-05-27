import Foundation

/// 「今日のミニマムライン」(Codex UX 提案 #1)。
/// 元気な日と疲れた日で同じハードルを要求すると、忙しい日に記録自体を避ける。
/// 3 段階のラインを毎日選べる UI を出して「今日は軽めでも OK」と先に宣言できる
/// 仕組み。実際の達成判定は変えない (achievement criteria は既に十分緩い)。
/// 違いは:
/// - ホームの猫メッセージのトーンが変わる
/// - 履歴に小さな葉アイコンで区別表示される
/// - 友達公園 (将来) で「今日は回復日です」状態が共有できる
enum DailyIntensity: String, CaseIterable, Sendable, Codable {
    case normal       // いつも通り
    case light        // 軽め (忙しい日)
    case recovery     // 回復 (疲労 / 体調)

    var displayName: String {
        switch self {
        case .normal:   return "いつも通り"
        case .light:    return "軽め"
        case .recovery: return "回復"
        }
    }

    var emoji: String {
        switch self {
        case .normal:   return "🎯"
        case .light:    return "🌿"
        case .recovery: return "☕"
        }
    }

    /// 履歴行に出すミニバッジ。`.normal` は通常表示なのでバッジなしを返す。
    var historyBadgeEmoji: String? {
        switch self {
        case .normal:   return nil
        case .light:    return "🌿"
        case .recovery: return "☕"
        }
    }
}

/// 「今日のミニマムライン」の日次選択を永続化する store。
/// `UserDefaults` に `intensity.<yyyy-MM-dd>` キーで保存。
@MainActor
final class DailyIntensityStore {
    static let shared = DailyIntensityStore()

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let formatter: DateFormatter

    init(defaults: UserDefaults = .standard, calendar: Calendar = .mondayFirst) {
        self.defaults = defaults
        self.calendar = calendar
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        self.formatter = f
    }

    private func key(for date: Date) -> String {
        "intensity.\(formatter.string(from: calendar.startOfDay(for: date)))"
    }

    func intensity(on date: Date) -> DailyIntensity {
        guard let raw = defaults.string(forKey: key(for: date)),
              let value = DailyIntensity(rawValue: raw) else { return .normal }
        return value
    }

    func set(_ intensity: DailyIntensity, on date: Date) {
        if intensity == .normal {
            // normal はデフォルトなのでキーを掃除して肥大化を防ぐ。
            defaults.removeObject(forKey: key(for: date))
        } else {
            defaults.set(intensity.rawValue, forKey: key(for: date))
        }
    }
}
