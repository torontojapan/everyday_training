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
        // セッション読取は「無セッション」と「一時障害」を厳密に区別する (監査 P1)。
        // 旧実装の `try?` は両者を潰し、リフレッシュトークンの一時失効/通信失敗でも
        // フォールスルーして **新規匿名サインイン** してしまう。友達/星/連携済みの既存
        // アイデンティティが新しい匿名 uid で上書きされ、friends 空表示や friend_code
        // UNIQUE 衝突を招く。新規匿名作成は sessionMissing(=確実に無セッション)のみに限定する。
        do {
            let existing = try await client.auth.session
            return existing.user.id
        } catch AuthError.sessionMissing {
            // 新規匿名サインイン時のみ CAPTCHA トークンを取得 (無効なら nil = 従来挙動)。
            let captchaToken = try await captchaProvider.obtainTokenIfNeeded()
            let session = try await client.auth.signInAnonymously(captchaToken: captchaToken)
            return session.user.id
        } catch {
            // 一時障害は新規作成せず失敗として伝播 (既存アイデンティティを温存)。
            throw FriendsServiceError.backendUnavailable
        }
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

    func restoreWithApple(idToken: String, nonce: String) async throws -> RestoreOutcome {
        do {
            // 新端末/再インストール: Apple 既存アカウントにサインインしプロフィールをロード。
            // 既存行があれば restored、無ければ新規作成で created。
            let hadProfile = try await signInWithApple(idToken: idToken, nonce: nonce)
            return hadProfile ? .restored : .created
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    // MARK: Google (web/PKCE)
    //
    // Apple のネイティブ id_token と違い、Google は Supabase の OAuth(PKCE) を web で通す:
    //   1. 認可 URL を生成 (link は `getLinkIdentityURL`、restore/switch は `getOAuthSignInURL`)
    //      — この時点で SDK が PKCE code verifier を保存する。
    //   2. `flow` (ASWebAuthenticationSession) で web 認可 → `goexercise://` コールバック URL を取得。
    //   3. `session(from:)` が PKCE code を交換しセッションを確立する。
    // 衝突 (identity_already_exists) はコールバック URL の error_code に載り、`session(from:)` が
    // `AuthError.pkceGrantCodeExchange(code:)` で throw する → `mapLinkError` で写像 (Apple と対称)。

    func linkGoogle(presenting flow: WebAuthFlow) async throws {
        do {
            let client = try requireClient()
            // 現匿名セッションを保持したまま Google identity を連結 (uid 不変の昇格)。
            let response = try await client.auth.getLinkIdentityURL(
                provider: .google, redirectTo: SupabaseConfig.googleRedirectURL
            )
            let callbackURL = try await flow(response.url)
            _ = try await client.auth.session(from: callbackURL)
            await refreshBackupStatus()
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    func switchToGoogleAccount(presenting flow: WebAuthFlow) async throws {
        do {
            _ = try await signInWithGoogle(presenting: flow)
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    func restoreWithGoogle(presenting flow: WebAuthFlow) async throws -> RestoreOutcome {
        do {
            let hadProfile = try await signInWithGoogle(presenting: flow)
            return hadProfile ? .restored : .created
        } catch {
            throw Self.mapLinkError(error)
        }
    }

    /// Google web/PKCE で既存(または新規)アカウントにサインインし、プロフィールをロードする共通処理。
    /// `switchToGoogleAccount` (衝突切替) と `restoreWithGoogle` (復元) が共用する。
    /// post-auth 失敗時の巻き戻し方針・空文字 signIn による既存保持は `signInWithApple` と同一
    /// (詳細はそちらの doc コメント参照)。
    /// - Returns: サインイン先 uid に**既存プロフィール行があったか** (restored / created の判定用)。
    @discardableResult
    private func signInWithGoogle(presenting flow: WebAuthFlow) async throws -> Bool {
        let client = try requireClient()
        // 認可 URL を生成 (PKCE verifier を保存) → web 認可 → コールバックで code 交換。
        // 現匿名 uid は破棄され、Google 側の既存(または新規)アカウントに入る。
        let url = try client.auth.getOAuthSignInURL(
            provider: .google, redirectTo: SupabaseConfig.googleRedirectURL
        )
        let callbackURL = try await flow(url)
        _ = try await client.auth.session(from: callbackURL)
        do {
            // ローカルキャッシュは切替先のものに置き換える。
            myProfile = nil
            defaults.removeObject(forKey: Self.myProfileKey)
            // signIn の upsert より前に既存有無を確定する (upsert 後では必ず存在してしまうため)。
            let session = try await client.auth.session
            let existing: [ProfileRow] = try await client.from("profiles")
                .select().eq("user_id", value: session.user.id.uuidString).limit(1).execute().value
            let hadProfile = !existing.isEmpty
            // 空文字 = 既存保持。新規(既存なし)時のみ signIn 内の既定値/コード生成で作成される。
            try await signIn(displayName: "", username: "")
            await refreshBackupStatus()
            return hadProfile
        } catch {
            // 認可は成立したが profile ロード失敗。切替を巻き戻して安全側へ (signInWithApple と同様)。
            // scope: .local — このデバイスのセッションのみ破棄 (.global は全端末失効のため使わない)。
            try? await client.auth.signOut(scope: .local)
            myProfile = nil
            defaults.removeObject(forKey: Self.myProfileKey)
            await refreshBackupStatus()
            throw error
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
        // Google web/PKCE: 衝突/プロバイダ無効/拒否はコールバック URL の error_code / error に載って
        // `pkceGrantCodeExchange` として throw される。`errorCode` は .unknown になるので、
        // 関連値の code / error 文字列を直接写像する (Apple の id_token 経路と対称)。
        if case let .pkceGrantCodeExchange(_, errorString, code) = authError {
            return mapPKCECallback(code: code, error: errorString)
        }
        switch authError.errorCode {
        case .identityAlreadyExists, .emailExists:
            return .alreadyLinkedToAnotherAccount
        case .providerDisabled, .manualLinkingDisabled, .oauthProviderNotSupported:
            return .providerUnavailable
        default:
            return .failed
        }
    }

    /// コールバック URL の `error_code` (code) と OAuth2 `error` (error) を写像する (PKCE web flow)。
    /// SDK は該当パラメータが無いと `"unspecified_code"`/`"unspecified_error"` のプレースホルダを
    /// 入れるため、両フィールドを見つつプレースホルダは無視する (Codex round1)。
    /// 例: Google 同意画面の拒否は `error=access_denied` のみで `error_code` 不在 = code はプレースホルダ
    /// になり得るので、error 側も評価しないと `.cancelled` を取り逃す。
    private static func mapPKCECallback(code: String?, error: String?) -> AccountLinkError {
        let tokens = [code, error].compactMap { $0 }
            .filter { $0 != "unspecified_code" && $0 != "unspecified_error" }
        for token in tokens {
            switch token {
            case ErrorCode.identityAlreadyExists.rawValue,
                 ErrorCode.emailExists.rawValue,
                 ErrorCode.userAlreadyExists.rawValue:
                return .alreadyLinkedToAnotherAccount
            case ErrorCode.providerDisabled.rawValue,
                 ErrorCode.manualLinkingDisabled.rawValue,
                 ErrorCode.oauthProviderNotSupported.rawValue:
                return .providerUnavailable
            case "access_denied":
                // Google の同意画面でユーザーが拒否/中止した場合。エラー扱いにしない。
                return .cancelled
            default:
                continue
            }
        }
        return .failed
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
            try? await client.from("referrals").delete()
                .or("referrer_user_id.eq.\(uid),referee_user_id.eq.\(uid)").execute()
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
    /// **削除の二段構え (Codex round3 で確定)**:
    /// 1. **Edge Function `delete-account` (正本/authoritative)**: service_role の `auth.admin.deleteUser(uid)`
    ///    で **auth ユーザー自体**を削除する。これにより各表は `on delete cascade` で連鎖削除され、
    ///    **全端末の全セッション/トークンもサーバ側で無効化**される (= access token の残存窓も閉じ、
    ///    account resurrection を根絶)。成功すればこれが完全削除。
    /// 2. **クライアント側フォールバック (Edge Function 未デプロイ/失敗時)**: anon key で本人 uid の
    ///    `cheers`/`friend_requests`/`friendships`/`profiles` を RLS 範囲で削除 (審査要件 5.1.1(v) を充足)
    ///    + best-effort `signOut(scope:.global)` で refresh token を失効。`auth.users` 行自体は anon key
    ///    では消せないため残るが PII は無く、Edge Function デプロイ後の再実行で回収される。
    ///    ※ この未デプロイ期間に残る access token (~1h) の窓は **設計上の既知の許容範囲**で、Edge Function
    ///      デプロイで解消する (友達機能はまだ未出荷)。
    ///
    /// **無セッション**は `notSignedIn` で throw (誤った成功報告を避ける, Codex round1)。
    /// **データ削除 (フォールバック) の失敗**はセッション有効中なので throw 伝播 = 冪等再試行可能。
    /// **signOut は best-effort (`try?`)**: supabase-swift の signOut は **/logout 送信前にローカル
    /// セッションを除去**するため、通信失敗で throw させると次回 `notSignedIn` で再試行不能に陥る
    /// (Codex round3)。トークン失効の正本は Edge Function なので、ここの signOut は失敗しても
    /// 致命的でない (データは削除済み = 審査要件は満たす)。
    func deleteAccount() async throws {
        let client = try requireClient()
        // ensureUID は呼ばない (削除中に新規匿名セッションを作らない)。
        // 無セッションは「過去にサーバ行を作成した本人」の削除導線 (signedInBody) からの呼び出しと
        // 矛盾する = データ取りこぼしを意味するので、成功と誤報告せず throw する (Codex round1)。
        let session: Session
        do {
            session = try await client.auth.session
        } catch {
            throw FriendsServiceError.notSignedIn
        }
        let uid = session.user.id.uuidString

        // 1) 正本: Edge Function で auth ユーザーごと削除 (cascade で全表 + 全セッション無効化)。
        //    セッションが有効なうちに呼ぶ (JWT で本人検証)。成功すれば完全削除 = ローカル掃除して終了。
        do {
            try await client.functions.invoke("delete-account", options: FunctionInvokeOptions(method: .post))
            // auth ユーザー削除済み = 全セッション失効済み。ローカルセッション/キャッシュだけ掃除する
            // (signOut は best-effort: /logout が 401/404 を返しても SDK が握り潰す)。
            try? await client.auth.signOut(scope: .local)
            clearLocalSession()
            return
        } catch let FunctionsError.httpError(code, _) where code != 404 {
            // **fail closed (Codex round4)**: Edge Function はデプロイされているが削除に失敗
            // (例: 500 delete_failed / server_misconfigured, 401 invalid_token, 405)。auth ユーザーは
            // 確実に残っている。ここで data-delete フォールバックして success を返すと、auth 行 +
            // 全端末の refresh token が生き残ったまま「削除完了」と誤報告し resurrection を許す
            // (= 「EF 未デプロイ」の許容範囲外)。サイレント成功にせず throw し、セッション無傷のまま
            // 再試行させる (再試行で EF が削除に成功すれば完全削除に収束)。
            throw FriendsServiceError.backendUnavailable
        } catch {
            // 404 (未デプロイ) / ネット断 / lost-response (URLError) 等の**不確定/許容**ケースのみ
            // 2) のフォールバックへ。デプロイ済み EF の明示的サーバ失敗は上で fail closed 済み。
        }

        // 2) フォールバック: 本人データをクライアント側で削除し審査要件を満たす。
        //    FK は全て auth.users を参照 (表間 FK 無し) のため削除順は任意。冪等。
        //    セッション有効中なので失敗は throw 伝播 = 再試行可能。
        try await client.from("cheers").delete()
            .or("from_user.eq.\(uid),to_user.eq.\(uid)").execute()
        try await client.from("friend_requests").delete()
            .or("from_user.eq.\(uid),to_user.eq.\(uid)").execute()
        try await client.from("friendships").delete()
            .or("user_a.eq.\(uid),user_b.eq.\(uid)").execute()
        try await client.from("referrals").delete()
            .or("referrer_user_id.eq.\(uid),referee_user_id.eq.\(uid)").execute()
        try await client.from("profiles").delete()
            .eq("user_id", value: uid).execute()
        // refresh token 失効を試みる (best-effort)。supabase-swift は /logout 前にローカルセッションを
        // 除去するため、通信失敗で throw させると再試行で notSignedIn になり詰む (Codex round3)。
        // トークン失効の正本は Edge Function なのでここは握り潰してよい (データは削除済み)。
        try? await client.auth.signOut(scope: .global)
        clearLocalSession()
    }

    /// ローカルのプロフィールキャッシュ/バックアップ状態を消す (削除完了時)。
    private func clearLocalSession() {
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
        let me = uid.uuidString.lowercased()   // DB の user_a/b は小文字。大小混在の == は常に不一致になる。
        let otherIDs = edges.map { $0.user_a.lowercased() == me ? $0.user_b : $0.user_a }
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

    // MARK: - 友達紹介 (リファラル)

    func submitInviteCode(_ code: String) async throws {
        let client = try requireClient()
        let uid = try await ensureUID()
        let target = code.uppercased()
        guard let me = myProfile, me.friendCode != target else { throw FriendsServiceError.cannotAddSelf }
        // 紹介者(referrer)を friend_code から解決。
        let rows: [ProfileRow] = try await client.from("profiles")
            .select().eq("friend_code", value: target).limit(1).execute().value
        guard let referrer = rows.first else { throw FriendsServiceError.codeNotFound }
        if referrer.user_id.lowercased() == uid.uuidString.lowercased() { throw FriendsServiceError.cannotAddSelf }
        // 1人1紹介者: 既に referee 行があれば不可。
        let existing: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid.uuidString).limit(1).execute().value
        if !existing.isEmpty { throw FriendsServiceError.duplicateRequest }
        // 自動友達化を **先に** 行う(承認フロースキップ・upsert は冪等)。
        // referral insert を先にすると、直後の friendship upsert が一過性に失敗したとき、
        // 再試行が上の duplicate-referee guard(referrals に行あり)で弾かれ friendship が永久に
        // 作られない=「報酬はあるが友達でない」状態が残る(GPT-5.5/Claude 監査)。順序を逆にすれば
        // referral insert 失敗時の再試行でも friendship は冪等に再作成され、最悪でも
        // 「友達だが紹介報酬なし」(安全側)に収束する。
        try await upsertFriendship(client: client, a: uid.uuidString, b: referrer.user_id)
        // pending 紹介を作成(referee = 自分。RLS で referee 本人のみ insert 可)。
        try await client.from("referrals")
            .insert(ReferralInsert(referrer_user_id: referrer.user_id, referee_user_id: uid.uuidString))
            .execute()
    }

    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation? {
        guard hasFirstRecord else { return nil }
        let client = try requireClient()
        let uid = try await ensureUID()
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid.uuidString).limit(1).execute().value
        guard let row = rows.first, row.status == "pending" else { return nil }
        let nowISO = ISO8601DateFormatter().string(from: Date())
        try await client.from("referrals")
            .update(ReferralConfirmUpdate(status: "confirmed", confirmed_at: nowISO))
            .eq("referee_user_id", value: uid.uuidString).execute()
        let referrer: [ProfileRow] = try await client.from("profiles")
            .select().eq("user_id", value: row.referrer_user_id).limit(1).execute().value
        return ReferralConfirmation(id: uid.uuidString,
                                    friendDisplayName: referrer.first?.display_name ?? "ともだち",
                                    role: .referee)
    }

    /// サインイン中のセッションを返す。未サインイン(sessionMissing)は nil、
    /// 一時障害(トークン更新失敗/通信失敗)は throw する。これにより紹介系の集計が
    /// 一時障害時に「空(=サインアウト相当)」を**成功として**返して ReferralStore の
    /// 既存値を上書きしてしまう事故を防ぐ(監査 P2。ensureUID と同じ方針)。
    private func signedInSessionOrNil() async throws -> Session? {
        guard let client else { return nil }
        do {
            return try await client.auth.session
        } catch AuthError.sessionMissing {
            return nil
        }
    }

    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation] {
        guard myProfile != nil, let session = try await signedInSessionOrNil() else { return [] }
        let client = try requireClient()
        let uid = session.user.id.uuidString
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referrer_user_id", value: uid)
            .eq("status", value: "confirmed").eq("seen_by_referrer", value: false)
            .execute().value
        guard !rows.isEmpty else { return [] }
        let refereeIDs = rows.map { $0.referee_user_id }
        let profs: [ProfileRow] = try await client.from("profiles")
            .select().in("user_id", values: refereeIDs).execute().value
        let byID = Dictionary(uniqueKeysWithValues: profs.map { ($0.user_id, $0) })
        // 取得分**だけ**を seen=true にする(再ポップ防止)。select と update の間に新たな
        // confirmed が来ても、返していない行を seen にして祝祭を取りこぼさないよう referee_user_id で
        // 限定する(Claude 監査: select/update レース)。
        try await client.from("referrals")
            .update(ReferralSeenUpdate(seen_by_referrer: true))
            .eq("referrer_user_id", value: uid)
            .eq("status", value: "confirmed").eq("seen_by_referrer", value: false)
            .in("referee_user_id", values: refereeIDs)
            .execute()
        return rows.map { r in
            ReferralConfirmation(id: r.referee_user_id,
                                 friendDisplayName: byID[r.referee_user_id]?.display_name ?? "ともだち",
                                 role: .referrer)
        }
    }

    func referralSummary() async throws -> ReferralSummary {
        // 未サインインなら匿名アカウントを作らずに空を返す(孤児防止)。一時障害は throw して
        // ReferralStore の既存 summary を温存する(空で上書きしない、監査 P2)。
        guard myProfile != nil, let session = try await signedInSessionOrNil() else { return .empty }
        let client = try requireClient()
        let uid = session.user.id.uuidString
        let now = Date()
        let asReferrer: [ReferralRow] = try await client.from("referrals")
            .select().eq("referrer_user_id", value: uid).eq("status", value: "confirmed").execute().value
        let stars = asReferrer.count
        var bonus = asReferrer.filter { ReferralClock.isInMonth($0.confirmed_at, of: now) }.count
        let asReferee: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: uid).eq("status", value: "confirmed").limit(1).execute().value
        if let r = asReferee.first, ReferralClock.isInMonth(r.confirmed_at, of: now) { bonus += 1 }
        return ReferralSummary(starBadges: stars, freezeBonusThisMonth: bonus)
    }

    func hasReferrer() async throws -> Bool {
        guard myProfile != nil, let session = try await signedInSessionOrNil() else { return false }
        let client = try requireClient()
        let rows: [ReferralRow] = try await client.from("referrals")
            .select().eq("referee_user_id", value: session.user.id.uuidString).limit(1).execute().value
        return !rows.isEmpty
    }

    // MARK: - Helpers

    /// user_a < user_b 正規化。`UUID.uuidString` は大文字・DB由来IDは小文字のため、
    /// 比較・格納とも小文字に揃える (混在のまま比較すると Swift の大小区別で順序が反転し、
    /// Postgres 側 `check (user_a < user_b)` に違反する = iOS 固有の承認失敗バグの修正)。
    private func orderedPair(_ x: String, _ y: String) -> (String, String) {
        let lx = x.lowercased(), ly = y.lowercased()
        return lx < ly ? (lx, ly) : (ly, lx)
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
private struct ReferralRow: Decodable {
    let referrer_user_id: String
    let referee_user_id: String
    var status: String = "pending"
    var confirmed_at: String?
    var seen_by_referrer: Bool = false
}
private struct ReferralInsert: Encodable {
    let referrer_user_id: String
    let referee_user_id: String
}
private struct ReferralConfirmUpdate: Encodable {
    let status: String
    let confirmed_at: String
}
private struct ReferralSeenUpdate: Encodable {
    let seen_by_referrer: Bool
}
