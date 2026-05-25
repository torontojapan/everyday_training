import SwiftUI

/// 5 段階のリーグ。月末に上位 → 1 段昇格、下位 → 1 段降格。
enum League: Int, CaseIterable, Identifiable, Codable, Sendable {
    case bronze = 0
    case silver = 1
    case gold = 2
    case platinum = 3
    case diamond = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .bronze: return "ブロンズ"
        case .silver: return "シルバー"
        case .gold: return "ゴールド"
        case .platinum: return "プラチナ"
        case .diamond: return "ダイヤモンド"
        }
    }

    var emoji: String {
        switch self {
        case .bronze: return "🥉"
        case .silver: return "🥈"
        case .gold: return "🥇"
        case .platinum: return "💠"
        case .diamond: return "💎"
        }
    }

    /// chip / bg 色 (ヘッダーカードなどで使用)
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.78, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.62, green: 0.65, blue: 0.70)
        case .gold: return Color(red: 0.90, green: 0.65, blue: 0.20)
        case .platinum: return Color(red: 0.45, green: 0.70, blue: 0.85)
        case .diamond: return Color(red: 0.55, green: 0.85, blue: 0.95)
        }
    }

    /// 月末判定用ルール:
    /// - top 1 / 2 の friends は昇格 (max を超えない)
    /// - bottom 1 は降格 (bronze はそれ以下に下がらない)
    static let promotionCount = 2
    static let relegationCount = 1
}

/// 月末に呼び出される結果型。CelebrationCenter.fire(.legendary) を呼ぶ
/// かどうかの判断などに使う。
enum LeagueOutcome: Equatable, Sendable {
    case promoted(from: League, to: League)
    case demoted(from: League, to: League)
    case held(at: League)

    var isPromotion: Bool {
        if case .promoted = self { return true }
        return false
    }
}

@MainActor
@Observable
final class LeagueStore {
    static let leagueKey = "league.current"
    static let monthKey  = "league.currentMonth"   // "yyyy-MM"
    static let shared = LeagueStore()

    private let defaults: UserDefaults

    /// 現在のリーグ。デフォルトはブロンズ。
    var currentLeague: League {
        didSet { defaults.set(currentLeague.rawValue, forKey: Self.leagueKey) }
    }

    /// 「現在のリーグ判定が適用されている月」(yyyy-MM)。月跨ぎを検知するために使用。
    private var trackedMonth: String {
        didSet { defaults.set(trackedMonth, forKey: Self.monthKey) }
    }

    init(defaults: UserDefaults = .standard, today: Date = Date()) {
        self.defaults = defaults
        if let raw = defaults.object(forKey: Self.leagueKey) as? Int,
           let league = League(rawValue: raw) {
            self.currentLeague = league
        } else {
            self.currentLeague = .bronze
        }
        self.trackedMonth = defaults.string(forKey: Self.monthKey) ?? Self.monthKey(for: today)
    }

    /// 月跨ぎが起きたら currentLeague を outcome に従って遷移し、tracked month を更新。
    /// 既に同月内なら何もしない。
    @discardableResult
    func applyMonthlyOutcomeIfNeeded(today: Date, outcomeFor: (League) -> LeagueOutcome) -> LeagueOutcome? {
        let nowMonth = Self.monthKey(for: today)
        guard nowMonth != trackedMonth else { return nil }

        let outcome = outcomeFor(currentLeague)
        switch outcome {
        case .promoted(_, let to): currentLeague = to
        case .demoted(_, let to):  currentLeague = to
        case .held: break
        }
        trackedMonth = nowMonth
        return outcome
    }

    static func monthKey(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM"
        return f.string(from: date)
    }
}

enum LeagueRules {
    /// myRank: 1-based rank within the league cohort. cohortSize: total entries.
    static func outcome(from league: League, myRank: Int, cohortSize: Int) -> LeagueOutcome {
        if myRank <= League.promotionCount {
            if league == .diamond { return .held(at: .diamond) }
            return .promoted(from: league, to: League(rawValue: league.rawValue + 1)!)
        }
        if cohortSize >= 2, myRank > cohortSize - League.relegationCount {
            if league == .bronze { return .held(at: .bronze) }
            return .demoted(from: league, to: League(rawValue: league.rawValue - 1)!)
        }
        return .held(at: league)
    }
}
