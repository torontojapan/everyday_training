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
}

struct FriendRequest: Identifiable, Hashable, Sendable {
    let id: String
    var fromProfile: FriendProfile
    var requestedAt: Date
}

enum FriendCode {
    /// Generates a random 6-character alphanumeric code, excluding ambiguous chars (O/0/I/1).
    static func generate() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in alphabet.randomElement() ?? "A" })
    }
}
