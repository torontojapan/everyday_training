import Foundation

struct FriendProfile: Identifiable, Hashable, Sendable, Codable {
    let id: String              // = friendCode
    var friendCode: String      // 6 桁英数字 (ABC123 等)
    var username: String        // 表示用ユーザー名 (重複可)
    var displayName: String     // 「Jun」「猫好き」等の自由表記
    var currentStreak: Int
    var totalAchievedDays: Int
    var todayAchieved: Bool
    var todayCategoryName: String?      // 例: "筋トレ"
    var todayExerciseNames: [String]    // 例: ["スクワット", "プランク"]
    var decorationTier: Int             // publish 値 = CatRank.rank (0..11)。表示は computed rank を使用。
    var lastUpdated: Date

    /// 7 要素 (月→日)。未達成日は false。`Codable` 互換のため optional。
    /// ランキング集計 ([[WeeklyRankingCalculator]]) と旧クライアント互換のため維持。
    var weeklyAchievements: [Bool]?
    /// 7 要素 (月→日) の **日ごとの状態** (運動/休養/フリーズ/未達/今日/未来)。
    /// 友達詳細の「今週の達成」を本人のホーム週ストリップ ([[WeeklyCalendarView]]) と
    /// 同じ状態別表示にするための正本。`countsAsAchieved` で潰した Bool では
    /// 休養日 (休) と実運動 (◎) を区別できず、全部が緑✓に見えていた不具合を解消する。
    /// nil = 旧データ/旧クライアント (この場合は weeklyAchievements から近似復元)。
    var weeklyStatuses: [DailyStatus]? = nil
    /// 友達になった日。Mock では signIn 直後に設定。
    var connectedSince: Date?
    /// 詳細共有 ON の友達のみセットされる。回数/時間/セット数を含む。
    /// nil = 共有していない、空配列 = 共有 ON だが今日まだ記録なし。
    var todayExerciseDetails: [SharedExerciseDetail]?
    /// 今週 (月→日) の合計運動時間 (分)。週間ランキングの tiebreak に使用。
    /// Codable 互換のため optional。
    var weeklyTotalMinutes: Int?
    /// 今月 (1日〜月末) の合計運動時間 (分)。月間ランキングに使用。
    var monthlyTotalMinutes: Int?
    /// 今月の達成日数。月間ランキングの tiebreak で使う。
    var monthlyAchievedDays: Int?
    /// 友達自身が設定している猫キャラ。Phase 6.7 で導入。nil なら
    /// friendCode の安定 hash で default を表示する (古い payload との
    /// 互換性のため optional)。
    var myCatBreed: CatBreed?

    var weeklyAchievementsOrEmpty: [Bool] {
        let raw = weeklyAchievements ?? []
        if raw.count == 7 { return raw }
        var padded = raw
        while padded.count < 7 { padded.append(false) }
        return Array(padded.prefix(7))
    }

    /// 友達ストリップ描画用の 7 状態 (月→日)。`weeklyStatuses` があればそれを使い、
    /// 無い (旧データ/旧クライアント) 場合は Bool 配列から近似復元する
    /// (true→achieved / false→missed)。長さは常に 7 に正規化する。
    var weeklyStatusesOrEmpty: [DailyStatus] {
        if let raw = weeklyStatuses, !raw.isEmpty {
            var padded = raw
            while padded.count < 7 { padded.append(.future) }
            return Array(padded.prefix(7))
        }
        // フォールバック: Bool しか持たない旧 payload は状態を区別できないため
        // 達成日のみ ◎、それ以外は × で近似する。
        return weeklyAchievementsOrEmpty.map { $0 ? .achieved : .missed }
    }

    /// 友達の称号 = 現在の連続から算出(バックエンド変更なし。spec F)。
    var rank: CatRank { CatRank(currentStreak: currentStreak) }
}

/// 友達カードに opt-in で見せる種目の詳細。本人がプライバシー設定で
/// 共有 ON にしている場合のみ送信される。
struct SharedExerciseDetail: Identifiable, Hashable, Sendable, Codable {
    var id: UUID
    var name: String
    var durationMinutes: Int?
    var reps: Int?
    var sets: Int?

    init(id: UUID = UUID(),
         name: String,
         durationMinutes: Int? = nil,
         reps: Int? = nil,
         sets: Int? = nil) {
        self.id = id
        self.name = name
        self.durationMinutes = durationMinutes
        self.reps = reps
        self.sets = sets
    }

    /// 「20回 × 3セット」「10分」など、UI 表示用の人が読めるサマリー。
    var summary: String {
        var parts: [String] = []
        if let reps, let sets {
            parts.append("\(reps)回 × \(sets)セット")
        } else if let reps {
            parts.append("\(reps)回")
        } else if let sets {
            parts.append("\(sets)セット")
        }
        if let durationMinutes {
            parts.append("\(durationMinutes)分")
        }
        return parts.joined(separator: " / ")
    }
}

struct FriendRequest: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var fromProfile: FriendProfile
    var requestedAt: Date
}

enum FriendCode {
    static let length = 6
    /// 24 letters + 8 digits, omitting visually ambiguous O / 0 / I / 1.
    static let alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    static let allowedCharacters = CharacterSet(charactersIn: alphabet)

    /// Generates a random 6-character alphanumeric code, excluding ambiguous chars.
    static func generate() -> String {
        let chars = Array(alphabet)
        return String((0..<length).map { _ in chars.randomElement() ?? "A" })
    }
}

enum FriendCodeValidator {
    /// Strip whitespace + lowercase, uppercase the rest, then keep only the
    /// allowed alphabet, and clip to 6 chars. Used to make the input field
    /// "self-correcting" as the user types.
    static func sanitize(_ raw: String) -> String {
        let upper = raw.uppercased()
        let filtered = upper.unicodeScalars.filter { FriendCode.allowedCharacters.contains($0) }
        return String(String.UnicodeScalarView(filtered.prefix(FriendCode.length)))
    }

    static func isValid(_ code: String) -> Bool {
        guard code.count == FriendCode.length else { return false }
        return code.unicodeScalars.allSatisfy { FriendCode.allowedCharacters.contains($0) }
    }
}
