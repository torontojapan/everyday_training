import Foundation
import OSLog
import Supabase

/// Supabase (PostgREST + Anonymous Auth) backed implementation of `FriendsService`.
///
/// 設計 (中立BE / Apple↔Android 共有対応):
/// - **識別**: Supabase Anonymous Auth の `auth.uid()` (アプリ生成UUID)。ログイン不要UX。
/// - **friend code**: クライアント生成 (O/0/I/1除外, 6桁) + `profiles.friend_code` UNIQUE + 衝突リトライ。
/// - **friendship**: `friendships` に **双方向1行** (user_a < user_b に正規化) → 承認後に双方が即見える
///   (CloudKit の片側エッジ問題を解消)。
/// - **RLS**: 各行は本人のみ書込可、cheer は friendship 必須 (schema.sql 参照)。
/// - 共有データは表示名/連続記録/今日のカテゴリ・種目名まで。体重・体調は持たない。
@MainActor
final class SupabaseFriendsService: FriendsService {

    private let client: SupabaseClient?
    private let defaults: UserDefaults
    private let captchaProvider: any CaptchaTokenProviding
    private let logger = Logger(subsystem: "com.goexercise.app", category: "SupabaseFriends")
    private static let myProfileKey = "supabase.friends.myProfile.v1"

    private(set) var myProfile: FriendProfile?

    init(defaults: UserDefaults = .standard, captchaProvider: (any CaptchaTokenProviding)? = nil) {
        self.defaults = defaults
        self.captchaProvider = captchaProvider ?? Self.makeCaptchaProvider()
        if let url = SupabaseConfig.url, SupabaseConfig.isConfigured {
            self.client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.anonKey)
        } else {
            self.client = nil
        }
        if let data = defaults.data(forKey: Self.myProfileKey),
           let decoded = try? JSONDecoder().decode(FriendProfile.self, from: data) {
            self.myProfile = decoded
        }
    }

    /// config-gated: site key 未設定なら no-op (captchaToken なし = 従来挙動)。
    private static func makeCaptchaProvider() -> any CaptchaTokenProviding {
        #if canImport(WebKit) && os(iOS)
        if SupabaseConfig.isCaptchaEnabled {
            return TurnstileCaptchaTokenProvider(siteKey: SupabaseConfig.turnstileSiteKey)
        }
        #endif
        return NoCaptchaTokenProvider()
    }

    private var myCode: String? { myProfile?.friendCode }

    // MARK: - Auth

    private func ensureUID() async throws -> UUID {
        guard let client else { throw FriendsServiceError.backendUnavailable }
        if let existing = try? await client.auth.session { return existing.user.id }
        // 新規匿名サインイン時のみ CAPTCHA トークンを取得 (無効なら nil = 従来挙動)。
        let captchaToken = try await captchaProvider.obtainTokenIfNeeded()
        let session = try await client.auth.signInAnonymously(captchaToken: captchaToken)
        return session.user.id
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client else { throw FriendsServiceError.backendUnavailable }
        return client
    }

    // MARK: - Sign in / out

    func signIn(displayName rawDisplayName: String, username rawUsername: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let displayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        // 既存プロフィール (同一 uid) があれば stats を引き継ぐ。
        let existing: [ProfileRow] = try await client.from("profiles")
            .select().eq("user_id", value: uid.uuidString).limit(1).execute().value

        let code: String
        if let row = existing.first {
            code = row.friend_code
        } else {
            code = try await generateUniqueCode(client: client)
        }

        let write = ProfileWrite(
            user_id: uid.uuidString,
            friend_code: code,
            username: username.isEmpty ? (existing.first?.username ?? "you") : username,
            display_name: displayName.isEmpty ? (existing.first?.display_name ?? "あなた") : displayName,
            current_streak: existing.first?.current_streak ?? 0,
            total_achieved_days: existing.first?.total_achieved_days ?? 0,
            today_achieved: existing.first?.today_achieved ?? false,
            today_category_name: existing.first?.today_category_name,
            today_exercise_names: existing.first?.today_exercise_names,
            today_exercise_details: existing.first?.today_exercise_details,
            decoration_tier: existing.first?.decoration_tier ?? 0,
            weekly_achievements: existing.first?.weekly_achievements,
            weekly_total_minutes: existing.first?.weekly_total_minutes,
            monthly_total_minutes: existing.first?.monthly_total_minutes,
            monthly_achieved_days: existing.first?.monthly_achieved_days,
            my_cat_breed: existing.first?.my_cat_breed
        )
        try await client.from("profiles").upsert(write, onConflict: "user_id").execute()
        cache(profile(from: write, code: code))
    }

    func signOut() async {
        guard let client else { myProfile = nil; defaults.removeObject(forKey: Self.myProfileKey); return }
        if let uid = try? await ensureUID() {
            try? await client.from("profiles").delete().eq("user_id", value: uid.uuidString).execute()
            try? await client.from("friendships").delete()
                .or("user_a.eq.\(uid.uuidString),user_b.eq.\(uid.uuidString)").execute()
            try? await client.from("friend_requests").delete()
                .or("from_user.eq.\(uid.uuidString),to_user.eq.\(uid.uuidString)").execute()
        }
        try? await client.auth.signOut()
        myProfile = nil
        defaults.removeObject(forKey: Self.myProfileKey)
    }

    private func generateUniqueCode(client: SupabaseClient) async throws -> String {
        for _ in 0..<8 {
            let code = FriendCode.generate()
            let hit: [ProfileRow] = try await client.from("profiles")
                .select("friend_code").eq("friend_code", value: code).limit(1).execute().value
            if hit.isEmpty { return code }
        }
        return FriendCode.generate()
    }

    // MARK: - Publish

    func publishMyProfile(_ profile: FriendProfile) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let write = ProfileWrite(from: profile, uid: uid)
        try await client.from("profiles").upsert(write, onConflict: "user_id").execute()
        cache(profile)
    }

    // MARK: - Friends / requests

    func refreshFriends() async throws -> [FriendProfile] {
        let client = try requireClient()
        let uid = try await ensureUID()
        guard myCode != nil else { throw FriendsServiceError.notSignedIn }

        let edges: [FriendshipRow] = try await client.from("friendships")
            .select().eq("status", value: "active")
            .or("user_a.eq.\(uid.uuidString),user_b.eq.\(uid.uuidString)")
            .execute().value
        let otherIDs = edges.map { $0.user_a == uid.uuidString ? $0.user_b : $0.user_a }
        guard !otherIDs.isEmpty else { return [] }

        let rows: [ProfileRow] = try await client.from("profiles")
            .select().in("user_id", values: otherIDs).execute().value
        return rows.map { profile(from: $0) }.sorted { $0.currentStreak > $1.currentStreak }
    }

    func pendingRequests() async throws -> [FriendRequest] {
        let client = try requireClient()
        let uid = try await ensureUID()
        guard myCode != nil else { throw FriendsServiceError.notSignedIn }

        let reqs: [RequestRow] = try await client.from("friend_requests")
            .select().eq("to_user", value: uid.uuidString).eq("status", value: "pending")
            .execute().value
        guard !reqs.isEmpty else { return [] }
        let fromIDs = reqs.map { $0.from_user }
        let profs: [ProfileRow] = try await client.from("profiles")
            .select().in("user_id", values: fromIDs).execute().value
        let byID = Dictionary(uniqueKeysWithValues: profs.map { ($0.user_id, $0) })
        return reqs.compactMap { r -> FriendRequest? in
            guard let p = byID[r.from_user] else { return nil }
            return FriendRequest(id: r.id, fromProfile: profile(from: p), requestedAt: Date())
        }
    }

    func sendRequest(to code: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let target = code.uppercased()
        guard let me = myProfile, me.friendCode != target else { throw FriendsServiceError.cannotAddSelf }

        let targets: [ProfileRow] = try await client.from("profiles")
            .select().eq("friend_code", value: target).limit(1).execute().value
        guard let t = targets.first else { throw FriendsServiceError.codeNotFound }

        let active: [FriendshipRow] = try await client.from("friendships")
            .select().eq("status", value: "active")
            .or("and(user_a.eq.\(uid.uuidString),user_b.eq.\(t.user_id)),and(user_a.eq.\(t.user_id),user_b.eq.\(uid.uuidString))")
            .execute().value
        if !active.isEmpty { throw FriendsServiceError.alreadyFriends }

        let dup: [RequestRow] = try await client.from("friend_requests")
            .select().eq("from_user", value: uid.uuidString).eq("to_user", value: t.user_id)
            .eq("status", value: "pending").execute().value
        if !dup.isEmpty { throw FriendsServiceError.duplicateRequest }

        try await client.from("friend_requests")
            .insert(RequestWrite(from_user: uid.uuidString, to_user: t.user_id, status: "pending"))
            .execute()
    }

    func acceptRequest(_ request: FriendRequest) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        // 申請者 uid を friend_code から解決。
        let fromRows: [ProfileRow] = try await client.from("profiles")
            .select("user_id").eq("friend_code", value: request.fromProfile.friendCode).limit(1).execute().value
        guard let fromID = fromRows.first?.user_id else { throw FriendsServiceError.codeNotFound }
        try await upsertFriendship(client: client, a: uid.uuidString, b: fromID)
        try? await client.from("friend_requests").delete().eq("id", value: request.id).execute()
    }

    func declineRequest(_ request: FriendRequest) async throws {
        let client = try requireClient()
        _ = try await ensureUID()
        try? await client.from("friend_requests").delete().eq("id", value: request.id).execute()
    }

    func removeFriend(_ profile: FriendProfile) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("user_id").eq("friend_code", value: profile.friendCode).limit(1).execute().value
        guard let otherID = rows.first?.user_id else { return }
        let (a, b) = orderedPair(uid.uuidString, otherID)
        try await client.from("friendships").delete()
            .eq("user_a", value: a).eq("user_b", value: b).execute()
    }

    func searchByUsername(_ query: String) async throws -> [FriendProfile] {
        let client = try requireClient()
        _ = try await ensureUID()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().ilike("username", pattern: "%\(q)%").limit(25).execute().value
        return rows.map { profile(from: $0) }.filter { $0.friendCode != myCode }
    }

    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let rows: [ProfileRow] = try await client.from("profiles")
            .select("user_id").eq("friend_code", value: friendCode).limit(1).execute().value
        guard let toID = rows.first?.user_id else { throw FriendsServiceError.codeNotFound }
        try await client.from("cheers")
            .insert(CheerWrite(from_user: uid.uuidString, to_user: toID, kind: kind.rawValue))
            .execute()
    }

    // MARK: - Helpers

    private func orderedPair(_ x: String, _ y: String) -> (String, String) {
        x < y ? (x, y) : (y, x)
    }

    private func upsertFriendship(client: SupabaseClient, a: String, b: String) async throws {
        let (ua, ub) = orderedPair(a, b)
        try await client.from("friendships")
            .upsert(FriendshipWrite(user_a: ua, user_b: ub, status: "active"), onConflict: "user_a,user_b")
            .execute()
    }

    private func cache(_ profile: FriendProfile) {
        myProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.myProfileKey)
        }
    }

    // MARK: - Row <-> FriendProfile

    private func profile(from r: ProfileRow) -> FriendProfile {
        FriendProfile(
            id: r.friend_code, friendCode: r.friend_code,
            username: r.username, displayName: r.display_name,
            currentStreak: r.current_streak, totalAchievedDays: r.total_achieved_days,
            todayAchieved: r.today_achieved, todayCategoryName: r.today_category_name,
            todayExerciseNames: r.today_exercise_names ?? [],
            decorationTier: r.decoration_tier, lastUpdated: Date(),
            weeklyAchievements: r.weekly_achievements,
            connectedSince: nil,
            todayExerciseDetails: r.today_exercise_details,
            weeklyTotalMinutes: r.weekly_total_minutes,
            monthlyTotalMinutes: r.monthly_total_minutes,
            monthlyAchievedDays: r.monthly_achieved_days,
            myCatBreed: r.my_cat_breed.flatMap { CatBreed(rawValue: $0) }
        )
    }

    private func profile(from w: ProfileWrite, code: String) -> FriendProfile {
        FriendProfile(
            id: code, friendCode: code,
            username: w.username, displayName: w.display_name,
            currentStreak: w.current_streak, totalAchievedDays: w.total_achieved_days,
            todayAchieved: w.today_achieved, todayCategoryName: w.today_category_name,
            todayExerciseNames: w.today_exercise_names ?? [],
            decorationTier: w.decoration_tier, lastUpdated: Date(),
            weeklyAchievements: w.weekly_achievements,
            connectedSince: nil,
            todayExerciseDetails: w.today_exercise_details,
            weeklyTotalMinutes: w.weekly_total_minutes,
            monthlyTotalMinutes: w.monthly_total_minutes,
            monthlyAchievedDays: w.monthly_achieved_days,
            myCatBreed: w.my_cat_breed.flatMap { CatBreed(rawValue: $0) }
        )
    }
}

// MARK: - Rows (snake_case columns)

private struct ProfileRow: Decodable {
    let user_id: String
    let friend_code: String
    var username: String = "user"
    var display_name: String = "ともだち"
    var current_streak: Int = 0
    var total_achieved_days: Int = 0
    var today_achieved: Bool = false
    var today_category_name: String?
    var today_exercise_names: [String]?
    var today_exercise_details: [SharedExerciseDetail]?
    var decoration_tier: Int = 0
    var weekly_achievements: [Bool]?
    var weekly_total_minutes: Int?
    var monthly_total_minutes: Int?
    var monthly_achieved_days: Int?
    var my_cat_breed: String?
}

private struct ProfileWrite: Encodable {
    let user_id: String
    let friend_code: String
    let username: String
    let display_name: String
    let current_streak: Int
    let total_achieved_days: Int
    let today_achieved: Bool
    let today_category_name: String?
    let today_exercise_names: [String]?
    let today_exercise_details: [SharedExerciseDetail]?
    let decoration_tier: Int
    let weekly_achievements: [Bool]?
    let weekly_total_minutes: Int?
    let monthly_total_minutes: Int?
    let monthly_achieved_days: Int?
    let my_cat_breed: String?

    init(from p: FriendProfile, uid: UUID) {
        user_id = uid.uuidString
        friend_code = p.friendCode
        username = p.username
        display_name = p.displayName
        current_streak = p.currentStreak
        total_achieved_days = p.totalAchievedDays
        today_achieved = p.todayAchieved
        today_category_name = p.todayCategoryName
        today_exercise_names = p.todayExerciseNames
        today_exercise_details = p.todayExerciseDetails
        decoration_tier = p.decorationTier
        weekly_achievements = p.weeklyAchievementsOrEmpty
        weekly_total_minutes = p.weeklyTotalMinutes
        monthly_total_minutes = p.monthlyTotalMinutes
        monthly_achieved_days = p.monthlyAchievedDays
        my_cat_breed = p.myCatBreed?.rawValue
    }

    init(user_id: String, friend_code: String, username: String, display_name: String,
         current_streak: Int, total_achieved_days: Int, today_achieved: Bool,
         today_category_name: String?, today_exercise_names: [String]?,
         today_exercise_details: [SharedExerciseDetail]?, decoration_tier: Int,
         weekly_achievements: [Bool]?, weekly_total_minutes: Int?,
         monthly_total_minutes: Int?, monthly_achieved_days: Int?, my_cat_breed: String?) {
        self.user_id = user_id; self.friend_code = friend_code; self.username = username
        self.display_name = display_name; self.current_streak = current_streak
        self.total_achieved_days = total_achieved_days; self.today_achieved = today_achieved
        self.today_category_name = today_category_name; self.today_exercise_names = today_exercise_names
        self.today_exercise_details = today_exercise_details; self.decoration_tier = decoration_tier
        self.weekly_achievements = weekly_achievements; self.weekly_total_minutes = weekly_total_minutes
        self.monthly_total_minutes = monthly_total_minutes; self.monthly_achieved_days = monthly_achieved_days
        self.my_cat_breed = my_cat_breed
    }
}

private struct FriendshipRow: Decodable {
    let user_a: String
    let user_b: String
    var status: String = "active"
}
private struct FriendshipWrite: Encodable {
    let user_a: String
    let user_b: String
    let status: String
}
private struct RequestRow: Decodable {
    let id: String
    let from_user: String
    let to_user: String
    var status: String = "pending"
}
private struct RequestWrite: Encodable {
    let from_user: String
    let to_user: String
    let status: String
}
private struct CheerWrite: Encodable {
    let from_user: String
    let to_user: String
    let kind: String
}
