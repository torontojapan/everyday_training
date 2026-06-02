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
    private(set) var backupStatus: AccountBackupStatus = .anonymous

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

    // MARK: - アカウント連携 (Phase 2)

    /// 復元前チェック: 現在の**匿名**セッションに、失われると困るデータ(友達)があるか。
    /// welcome から復元/切替する際、上書き前に確認ダイアログを出すか判定する (Codex#3)。
    /// 連携済み(永続)セッションや未サインインは対象外 = false (確認不要)。
    func anonymousSessionHasData() async -> Bool {
        guard let client else { return false }
        // セッション読取は「無セッション」と「一時障害」を区別する (Codex)。
        // sessionMissing = 確実に無セッション → 失われるデータ無し = false。
        // それ以外の読取エラーは不確実なので安全側 = true (確認ダイアログを出す)。
        let session: Session
        do {
            session = try await client.auth.session
        } catch AuthError.sessionMissing {
            return false
        } catch {
            return true
        }
        // 連携済み(非匿名)は復元/切替で失われるデータが無い = 確認不要。
        guard session.user.isAnonymous else { return false }
        let uid = session.user.id.uuidString
        // 全カラム select: Row 型は必須カラムを持つので部分 select だと decode が throw する (Codex)。
        // 友達(承認済み)に加え、保留中の申請も「失われると困るデータ」として扱う。
        do {
            let edges: [FriendshipRow] = try await client.from("friendships")
                .select().or("user_a.eq.\(uid),user_b.eq.\(uid)").limit(1).execute().value
            if !edges.isEmpty { return true }
            let reqs: [RequestRow] = try await client.from("friend_requests")
                .select().or("from_user.eq.\(uid),to_user.eq.\(uid)").limit(1).execute().value
            return !reqs.isEmpty
        } catch {
            // データ有無を判定できない(通信失敗等)ときは安全側 = 確認ダイアログを出す
            // (fail closed: 上書き前に必ずユーザーへ提示, Codex)。
            return true
        }
    }

    func refreshBackupStatus() async {
        guard let client else { backupStatus = .anonymous; return }
        guard let session = try? await client.auth.session else { backupStatus = .anonymous; return }
        let user = session.user
        let provider = user.identities?.first(where: { $0.provider != "anonymous" })?.provider
        backupStatus = AccountBackupStatus(isBackedUp: !user.isAnonymous, providerName: provider)
    }

    func linkApple(idToken: String, nonce: String) async throws {
        do {
            let client = try requireClient()
            try await client.auth.linkIdentityWithIdToken(
                credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
            )
            await refreshBackupStatus()
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    func switchToAppleAccount(idToken: String, nonce: String) async throws {
        do {
            _ = try await signInWithApple(idToken: idToken, nonce: nonce)
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    func restoreWithApple(idToken: String, nonce: String) async throws -> AppleRestoreOutcome {
        do {
            // 新端末/再インストール: Apple 既存アカウントにサインインしプロフィールをロード。
            // 既存行があれば restored、無ければ新規作成で created。
            let hadProfile = try await signInWithApple(idToken: idToken, nonce: nonce)
            return hadProfile ? .restored : .created
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    /// Apple id_token で既存(または新規)アカウントにサインインし、プロフィールをロードする共通処理。
    /// `switchToAppleAccount` (衝突切替) と `restoreWithApple` (復元) が共用する。
    ///
    /// **重要 (Codex#1)**: profile ロードは `signIn(displayName:"", username:"")` で**空文字**を渡す。
    /// `signIn` の `displayName.isEmpty ? existing : input` 分岐により、空文字は既存アカウントの
    /// `display_name`/`username` を**保持**する (fallback 名を渡すと既存表示名を上書きしてしまう)。
    ///
    /// **post-auth 失敗時 (Codex)**: `signInWithIdToken` 成立後に profile ロードが失敗すると、
    /// セッションだけ Apple 側へ切替わった半端な状態が残り、その後の `ensureSignedIn`(自動既定名)が
    /// Apple 既存プロフィールを上書きしうる。失敗時は `signOut` で切替を巻き戻し、クリーンな
    /// サインアウト状態へ戻す (非匿名セッションの signOut はクラウド削除しない = データは無事)。
    ///
    /// - Returns: サインイン先 uid に**既存プロフィール行があったか** (restored / created の判定用)。
    @discardableResult
    private func signInWithApple(idToken: String, nonce: String) async throws -> Bool {
        let client = try requireClient()
        // 既存アカウントにサインイン (現匿名 uid は破棄 = 参照不能に。孤児は cron で回収)。
        _ = try await client.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(provider: .apple, idToken: idToken, nonce: nonce)
        )
        do {
            // ローカルキャッシュは切替先のものに置き換える。
            myProfile = nil
            defaults.removeObject(forKey: Self.myProfileKey)
            // signIn の upsert より前に既存有無を確定する (upsert 後では必ず存在してしまうため)。
            // 全カラム select する: ProfileRow は friend_code 等が必須なので部分 select だと
            // decode が throw する (Codex)。
            let session = try await client.auth.session
            let existing: [ProfileRow] = try await client.from("profiles")
                .select().eq("user_id", value: session.user.id.uuidString).limit(1).execute().value
            let hadProfile = !existing.isEmpty
            // 空文字 = 既存保持。新規(既存なし)時のみ signIn 内の既定値/コード生成で作成される。
            try await signIn(displayName: "", username: "")
            await refreshBackupStatus()
            return hadProfile
        } catch {
            // 認可は成立したが profile ロード失敗。切替を巻き戻して安全側へ (上記 doc 参照, Codex)。
            // scope: .local — このデバイスのセッションのみ破棄する。既定の .global は Apple
            // アカウントの全デバイスの refresh token を失効させてしまうため使わない (Codex)。
            try? await client.auth.signOut(scope: .local)
            myProfile = nil
            defaults.removeObject(forKey: Self.myProfileKey)
            await refreshBackupStatus()
            throw error
        }
    }

    /// Supabase の AuthError / バックエンド不可を UI 向けの [[AccountLinkError]] に写像する。
    private static func mapLinkError(_ error: Error) -> AccountLinkError {
        if let linkError = error as? AccountLinkError { return linkError }
        if let serviceError = error as? FriendsServiceError, case .backendUnavailable = serviceError {
            return .backendUnavailable
        }
        guard let authError = error as? AuthError else { return .failed }
        switch authError.errorCode {
        case .identityAlreadyExists, .emailExists:
            return .alreadyLinkedToAnotherAccount
        case .providerDisabled, .manualLinkingDisabled, .oauthProviderNotSupported:
            return .providerUnavailable
        default:
            return .failed
        }
    }

    // MARK: - Sign in / out

    func signIn(displayName rawDisplayName: String, username rawUsername: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        // 非匿名(連携済み)セッションは既存の実アカウント。自動既定名/生成 username で
        // display_name/username を上書きしないよう空文字に倒して既存保持させる。これにより
        // stale-session (認可成立済みだが profile 未キャッシュ、rollback signOut 失敗等) で
        // 「この端末で始める」を押しても Apple プロフィールを潰さない (Codex)。
        // gate OFF 時は linking 無効=常に匿名セッションなので挙動不変 = バイト互換。
        let isAnonymousSession = (try? await client.auth.session)?.user.isAnonymous ?? true
        let displayName = isAnonymousSession ? rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let username = isAnonymousSession ? rawUsername.trimmingCharacters(in: .whitespacesAndNewlines) : ""

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
        // セッションは1回だけ読む。**匿名のときだけ**クラウドデータを削除する (=「忘れる」)。
        // 連携済み(バックアップ)は保持 = 別端末/再サインインで復旧可能。
        // ensureUID は呼ばない (サインアウト中に新規匿名セッションを作らない / 誤分類削除を防ぐ, Codex)。
        // セッション取得失敗時は不確実なので削除しない (安全側)。
        if let session = try? await client.auth.session, session.user.isAnonymous {
            let uid = session.user.id.uuidString
            try? await client.from("profiles").delete().eq("user_id", value: uid).execute()
            try? await client.from("friendships").delete()
                .or("user_a.eq.\(uid),user_b.eq.\(uid)").execute()
            try? await client.from("friend_requests").delete()
                .or("from_user.eq.\(uid),to_user.eq.\(uid)").execute()
        }
        try? await client.auth.signOut()
        myProfile = nil
        backupStatus = .anonymous
        defaults.removeObject(forKey: Self.myProfileKey)
    }

    /// アカウント削除 (審査 5.1.1(v))。匿名/連携済みを問わず本人 uid のデータを全消去する。
    ///
    /// **`signOut` との違い**: signOut は「匿名のみ」削除し連携済みは保持する (バックアップを壊さない)。
    /// 本メソッドはユーザーが明示的に「削除」を選んだ導線専用で、**連携済みも含めて消す**。
    ///
    /// **削除範囲**: `cheers`/`friend_requests`/`friendships`/`profiles` を RLS の本人行のみ削除
    /// (相互行 `friendships` は1行なので相手側からも即座に消える)。`cheers` は schema.sql に
    /// `cheers_delete` ポリシーを追加して当事者削除を許可済み。
    ///
    /// **`auth.users` 行**: anon key では削除不可 (service_role 必須)。本メソッドはデータ消去 +
    /// ローカルサインアウトまで。auth 行自体の削除/匿名化は Edge Function `delete-account`
    /// (service_role + `auth.admin.deleteUser`) で別途行う設計 (supabase/functions/delete-account)。
    /// データが消えていれば残る auth 行に PII は無く、行削除時に各表は cascade で連鎖削除される。
    ///
    /// **失敗時**: 途中 (セッション取得 / 各 delete / signOut) で throw した場合はサインアウトせず
    /// throw を伝播し、UI で再試行できる (各 delete は冪等なので再実行で完了する)。
    /// 無セッションは `notSignedIn` で throw する (誤った成功報告を避ける, Codex round1)。
    func deleteAccount() async throws {
        let client = try requireClient()
        // ensureUID は呼ばない (削除中に新規匿名セッションを作らない)。
        // セッションが取れないと anon key では本人データを削除できない。**成功と誤報告しない** —
        // throw して呼び出し側で profile を保持し再試行できるようにする (Codex round1)。
        // 早期 return でローカルだけ掃除すると、サーバ行が残ったまま「削除完了」と見え、
        // かつサインアウトで再試行不能になる。削除導線は signedInBody (profile!=nil =
        // 過去にサーバ行を作成済) からのみ出るため、無セッションはデータ取りこぼしを意味する。
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            throw FriendsServiceError.notSignedIn
        }
        let uid = session.user.id.uuidString
        // FK は全て auth.users を参照 (表間 FK 無し) のため削除順は任意。冪等。
        try await client.from("cheers").delete()
            .or("from_user.eq.\(uid),to_user.eq.\(uid)").execute()
        try await client.from("friend_requests").delete()
            .or("from_user.eq.\(uid),to_user.eq.\(uid)").execute()
        try await client.from("friendships").delete()
            .or("user_a.eq.\(uid),user_b.eq.\(uid)").execute()
        try await client.from("profiles").delete()
            .eq("user_id", value: uid).execute()
        // データ消去成立後に **`.global`** サインアウト。削除では本人の全デバイスの refresh token を
        // 失効させたい (Codex round2: 別デバイスが生きたセッションでデータを再作成する account
        // resurrection を防ぐ)。連携済みアカウントが複数端末にあるケースを潰す。
        // ※ rollback 経路 (signInWithApple の失敗時) は失敗操作なので他端末を巻き込まない .local だが、
        //   こちらは**意図的な削除**なので全端末失効が正しい。匿名は端末ローカル1セッションのみ=実質同じ。
        // ※ 残存の access token (既定~1h) が切れるまでの窓と auth.users 行自体の削除は service_role
        //   が要るため、完全消去は Edge Function `delete-account` (supabase/functions) で行う設計。
        // **`try?` にしない (Codex round1)**: signOut 失敗を握り潰すと、セッションが残ったまま
        // 「削除成功」と報告され、次の ensureSignedIn が**削除済み uid のプロフィールを再作成**して
        // しまう。失敗は throw し、データ削除は冪等なので再試行で収束させる。
        try await client.auth.signOut(scope: .global)
        myProfile = nil
        backupStatus = .anonymous
        defaults.removeObject(forKey: Self.myProfileKey)
    }

    private func generateUniqueCode(client: SupabaseClient) async throws -> String {
        for _ in 0..<8 {
            let code = FriendCode.generate()
            // 全カラム select: ProfileRow は user_id 等が必須なので部分 select だと decode が
            // throw する (Codex)。存在チェックのみだが既存 Row 型に合わせる。
            let hit: [ProfileRow] = try await client.from("profiles")
                .select().eq("friend_code", value: code).limit(1).execute().value
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
        // 申請者 uid を friend_code から解決 (全カラム select: 部分 select は decode throw, Codex)。
        let fromRows: [ProfileRow] = try await client.from("profiles")
            .select().eq("friend_code", value: request.fromProfile.friendCode).limit(1).execute().value
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
            .select().eq("friend_code", value: profile.friendCode).limit(1).execute().value
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
            .select().eq("friend_code", value: friendCode).limit(1).execute().value
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
