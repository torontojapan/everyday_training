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
    var decorationTier: Int             // 0..4 (None / Bandana / Headband / Medal / Crown)
    var lastUpdated: Date

    /// 7 要素 (月→日)。未達成日は false。`Codable` 互換のため optional。
    var weeklyAchievements: [Bool]?
    /// 友達になった日。Mock では signIn 直後に設定。
    var connectedSince: Date?

    var weeklyAchievementsOrEmpty: [Bool] {
        let raw = weeklyAchievements ?? []
        if raw.count == 7 { return raw }
        var padded = raw
        while padded.count < 7 { padded.append(false) }
        return Array(padded.prefix(7))
    }

    var decoration: CatDecoration {
        switch decorationTier {
        case 1: return .bandana
        case 2: return .headband
        case 3: return .medal
        case 4: return .crown
        default: return .none
        }
    }
}

struct FriendRequest: Identifiable, Hashable, Sendable {
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
