package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.SignOutScope
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Apple
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.exceptions.HttpRequestException
import io.github.jan.supabase.exceptions.NotFoundRestException
import io.github.jan.supabase.functions.functions
import io.github.jan.supabase.postgrest.from

/**
 * Supabase 実装。iOS `SupabaseFriendsService` の社交フロー移植(profiles/friendships/
 * friend_requests/cheers)。friendships は **ordered pair (min,max)** で 1 行に正規化
 * (iOS と同じ。双方向の重複行を防ぎ、nested or フィルタも不要)。
 * **コンパイル = API 実在確認**。実通信での正本性検証は実機 PoC(キー所有者作業)で行う。
 */
class SupabaseFriendsService(private val client: SupabaseClient) : FriendsService {

    override val isMock: Boolean = false

    private suspend fun ensureUid(): String {
        client.auth.currentUserOrNull()?.id?.let { return it }
        client.auth.signInAnonymously()
        return client.auth.currentUserOrNull()?.id ?: throw FriendsError.NotSignedIn
    }

    private suspend fun profileRow(userId: String): ProfileRow? =
        client.from("profiles").select { filter { eq("user_id", userId) }; limit(1) }
            .decodeList<ProfileRow>().firstOrNull()

    private suspend fun profileRowByCode(code: String): ProfileRow? =
        client.from("profiles").select { filter { eq("friend_code", code) }; limit(1) }
            .decodeList<ProfileRow>().firstOrNull()

    private suspend fun generateUniqueCode(): String {
        repeat(8) {
            val code = FriendCode.generate()
            if (profileRowByCode(code) == null) return code
        }
        return FriendCode.generate()
    }

    private fun orderedPair(a: String, b: String): Pair<String, String> =
        if (a < b) a to b else b to a

    override suspend fun myProfile(): FriendProfile? {
        val uid = client.auth.currentUserOrNull()?.id ?: return null
        return profileRow(uid)?.toProfile()
    }

    override suspend fun signIn(displayName: String, username: String) {
        val uid = ensureUid()
        val existing = profileRow(uid)
        if (existing != null) return // 既存プロフィールは保持(復元時 等)
        val row = ProfileRow(
            userId = uid,
            friendCode = generateUniqueCode(),
            username = username.trim(),
            displayName = displayName.trim().ifEmpty { "あなた" },
        )
        client.from("profiles").upsert(row) { onConflict = "user_id" }
    }

    override suspend fun signOut() {
        client.auth.signOut()
    }

    override suspend fun refreshFriends(): List<FriendProfile> {
        val uid = ensureUid()
        val edges = client.from("friendships").select {
            filter {
                eq("status", "active")
                or { eq("user_a", uid); eq("user_b", uid) }
            }
        }.decodeList<FriendshipRow>()
        val otherIds = edges.map { if (it.userA == uid) it.userB else it.userA }
        if (otherIds.isEmpty()) return emptyList()
        return client.from("profiles").select { filter { isIn("user_id", otherIds) } }
            .decodeList<ProfileRow>().map { it.toProfile() }
            .sortedByDescending { it.currentStreak }
    }

    override suspend fun pendingRequests(): List<FriendRequest> {
        val uid = ensureUid()
        val reqs = client.from("friend_requests").select {
            filter { eq("to_user", uid); eq("status", "pending") }
        }.decodeList<RequestRow>()
        if (reqs.isEmpty()) return emptyList()
        val fromIds = reqs.map { it.fromUser }
        val byId = client.from("profiles").select { filter { isIn("user_id", fromIds) } }
            .decodeList<ProfileRow>().associateBy { it.userId }
        return reqs.mapNotNull { r -> byId[r.fromUser]?.let { FriendRequest(id = r.id, fromProfile = it.toProfile()) } }
    }

    override suspend fun sendRequest(toCode: String) {
        val uid = ensureUid()
        val target = toCode.uppercase()
        val me = profileRow(uid)
        if (me?.friendCode == target) throw FriendsError.CannotAddSelf
        val t = profileRowByCode(target) ?: throw FriendsError.CodeNotFound
        val (a, b) = orderedPair(uid, t.userId)
        val active = client.from("friendships").select {
            filter { eq("user_a", a); eq("user_b", b); eq("status", "active") }
        }.decodeList<FriendshipRow>()
        if (active.isNotEmpty()) throw FriendsError.AlreadyFriends
        val dup = client.from("friend_requests").select {
            filter { eq("from_user", uid); eq("to_user", t.userId); eq("status", "pending") }
        }.decodeList<RequestRow>()
        if (dup.isNotEmpty()) throw FriendsError.DuplicateRequest
        client.from("friend_requests").insert(RequestWrite(fromUser = uid, toUser = t.userId))
    }

    override suspend fun acceptRequest(request: FriendRequest) {
        val uid = ensureUid()
        val fromId = profileRowByCode(request.fromProfile.friendCode)?.userId ?: throw FriendsError.CodeNotFound
        val (a, b) = orderedPair(uid, fromId)
        client.from("friendships").upsert(FriendshipRow(userA = a, userB = b, status = "active")) { onConflict = "user_a,user_b" }
        runCatching { client.from("friend_requests").delete { filter { eq("id", request.id) } } }
    }

    override suspend fun declineRequest(request: FriendRequest) {
        ensureUid()
        runCatching { client.from("friend_requests").delete { filter { eq("id", request.id) } } }
    }

    override suspend fun removeFriend(profile: FriendProfile) {
        val uid = ensureUid()
        val otherId = profileRowByCode(profile.friendCode)?.userId ?: return
        val (a, b) = orderedPair(uid, otherId)
        client.from("friendships").delete { filter { eq("user_a", a); eq("user_b", b) } }
    }

    override suspend fun sendCheer(kind: CheerKind, toCode: String) {
        val uid = ensureUid()
        val toId = profileRowByCode(toCode)?.userId ?: throw FriendsError.CodeNotFound
        client.from("cheers").insert(CheerWrite(fromUser = uid, toUser = toId, kind = kind.rawValue))
    }

    override suspend fun publishMyProfile(profile: FriendProfile) {
        val uid = ensureUid()
        val row = ProfileRow(
            userId = uid,
            friendCode = profile.friendCode,
            username = profile.username,
            displayName = profile.displayName,
            currentStreak = profile.currentStreak,
            totalAchievedDays = profile.totalAchievedDays,
            todayAchieved = profile.todayAchieved,
            todayCategoryName = profile.todayCategoryName,
            decorationTier = profile.decorationTier,
            weeklyTotalMinutes = profile.weeklyTotalMinutes,
            monthlyTotalMinutes = profile.monthlyTotalMinutes,
            monthlyAchievedDays = profile.monthlyAchievedDays,
        )
        client.from("profiles").upsert(row) { onConflict = "user_id" }
    }

    // ================= アカウント連携(#5 / Phase2)=================
    // iOS `SupabaseFriendsService` の連携層を移植。**Android は鏡像**: Google=native id_token /
    // Apple=web/PKCE(iOS は逆)。supabase-kt 3.6 の API は javap で実在確認済
    // (linkIdentityWithIdToken / signInWith(IDToken) / linkIdentity→URL / getOAuthUrl→URL /
    //  exchangeCodeForSession / signOut(scope) / functions.invoke→HttpResponse)。
    // **コンパイル = API 実在確認**。実通信での正本性(redirect 許可リスト/EF デプロイ/衝突写像)
    // は #10 実機 PoC(キー所有者作業)で確定する。

    private var backup = AccountBackupStatus.Anonymous
    override val backupStatus: AccountBackupStatus get() = backup

    /** 現セッションの identity から連携状態を更新。iOS refreshBackupStatus 相当。 */
    override suspend fun refreshBackupStatus() {
        val user = runCatching { client.auth.currentUserOrNull() }.getOrNull()
        backup = if (user == null) {
            AccountBackupStatus.Anonymous
        } else {
            val provider = user.identities?.firstOrNull { it.provider != "anonymous" }?.provider
            AccountBackupStatus(isBackedUp = user.isAnonymous != true, providerName = provider)
        }
    }

    /** 復元/切替の前に、現匿名セッションに失われると困るデータ(友達/申請)があるか。fail closed=true。 */
    override suspend fun anonymousSessionHasData(): Boolean {
        val user = client.auth.currentUserOrNull() ?: return false
        if (user.isAnonymous == false) return false // 連携済みは上書き確認不要
        val uid = user.id
        return try {
            val f = client.from("friendships").select {
                filter { or { eq("user_a", uid); eq("user_b", uid) } }; limit(1)
            }.decodeList<FriendshipRow>()
            if (f.isNotEmpty()) return true
            client.from("friend_requests").select {
                filter { or { eq("from_user", uid); eq("to_user", uid) } }; limit(1)
            }.decodeList<RequestRow>().isNotEmpty()
        } catch (e: Exception) {
            true // 読めない時は警告側に倒す(消えると困るので上書き確認を出す)
        }
    }

    // ---- Google = native id_token(uid 保持で連結 / 切替 / 復元)----

    override suspend fun linkGoogleIdToken(idToken: String) {
        try {
            client.auth.linkIdentityWithIdToken(Google, idToken) {}
            refreshBackupStatus()
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
    }

    override suspend fun switchToGoogleIdToken(idToken: String) {
        signInWithGoogle(idToken)
    }

    override suspend fun restoreWithGoogleIdToken(idToken: String): RestoreOutcome =
        signInWithGoogle(idToken)

    /** Google id_token で完全サインイン(uid 切替)。既存プロフィール有無で restored/created を返す。 */
    private suspend fun signInWithGoogle(idToken: String): RestoreOutcome {
        try {
            client.auth.signInWith(IDToken) { this.idToken = idToken; provider = Google }
            return finishIdentitySwitch()
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
    }

    // ---- Apple = web/PKCE(Custom Tabs。flow が認可 URL を開き callback を返す)----

    override suspend fun linkAppleWeb(flow: WebAuthFlow) {
        try {
            val authUrl = client.auth.linkIdentity(Apple, redirectUrl = SupabaseConfig.googleRedirectUrl) {}
                ?: throw AccountLinkError.Failed
            val code = parseCallbackForCode(flow(authUrl))
            client.auth.exchangeCodeForSession(code)
            refreshBackupStatus()
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
    }

    override suspend fun switchToAppleWeb(flow: WebAuthFlow) {
        signInWithAppleWeb(flow)
    }

    override suspend fun restoreWithAppleWeb(flow: WebAuthFlow): RestoreOutcome =
        signInWithAppleWeb(flow)

    /** Apple web で完全サインイン(uid 切替)。getOAuthUrl→flow→exchangeCodeForSession。 */
    private suspend fun signInWithAppleWeb(flow: WebAuthFlow): RestoreOutcome {
        try {
            val authUrl = client.auth.getOAuthUrl(Apple, redirectUrl = SupabaseConfig.googleRedirectUrl) {}
            val code = parseCallbackForCode(flow(authUrl))
            client.auth.exchangeCodeForSession(code)
            return finishIdentitySwitch()
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
    }

    /** サインイン(切替/復元)後: 既存プロフィールが有れば restored、無ければ既定で作成し created。 */
    private suspend fun finishIdentitySwitch(): RestoreOutcome {
        val uid = client.auth.currentUserOrNull()?.id ?: throw AccountLinkError.Failed
        val existing = profileRow(uid)
        val outcome = if (existing != null) {
            RestoreOutcome.Restored
        } else {
            signIn(displayName = "", username = "") // 既定名で新規プロフィール作成(= サインアップ)
            RestoreOutcome.Created
        }
        refreshBackupStatus()
        return outcome
    }

    // ---- アカウント削除(審査 5.1.1(v)。二段構え)----

    override suspend fun deleteAccount() {
        val uid = client.auth.currentUserOrNull()?.id ?: throw FriendsError.NotSignedIn
        // Stage1: Edge Function `delete-account`(service_role で auth ごと cascade 削除 + 全セッション失効)。
        // デプロイ済みで **非404 失敗(500/401/405)は fail closed**(success と誤報告せず再試行させる。
        // auth 行+refresh token が生き残ると復活するため)。404/ネット断/不確定のみ Stage2 へ。
        // TODO(#10 PoC): supabase-kt の functions.invoke は HttpResponse を返し HTTP エラーで throw しない
        // 前提。実機で 404/500 の挙動(throw か status か)を確定し、必要なら例外の status 抽出を足す。
        // supabase-kt は非2xx を typed RestException で投げる。404(未デプロイ)/ネット断のみ Stage2 へ。
        // 401/405/500 等(EF に到達した上での失敗)は **fail closed**(success 誤報告で auth 行/
        // refresh token が生き残り復活するのを防ぐ)。
        val efStatus = try {
            client.functions.invoke("delete-account").status.value
        } catch (e: NotFoundRestException) {
            404 // EF 未デプロイ → Stage2 フォールバック
        } catch (e: HttpRequestException) {
            -1 // ネット断/到達不可 → Stage2 フォールバック(RLS も落ちれば throw され再試行可)
        } catch (e: java.io.IOException) {
            -1
        } catch (e: Exception) {
            throw AccountLinkError.BackendUnavailable // 401/405/500 等 → fail closed
        }
        when {
            efStatus in 200..299 -> { runCatching { client.auth.signOut(SignOutScope.LOCAL) }; backup = AccountBackupStatus.Anonymous; return }
            efStatus == 404 || efStatus == -1 -> Unit // フォールバックへ
            else -> throw AccountLinkError.BackendUnavailable // 非throw で非2xx が返った場合も fail closed
        }
        // Stage2: クライアント RLS フォールバック(本人 uid のデータのみ削除)。
        client.from("cheers").delete { filter { or { eq("from_user", uid); eq("to_user", uid) } } }
        client.from("friend_requests").delete { filter { or { eq("from_user", uid); eq("to_user", uid) } } }
        client.from("friendships").delete { filter { or { eq("user_a", uid); eq("user_b", uid) } } }
        client.from("profiles").delete { filter { eq("user_id", uid) } }
        runCatching { client.auth.signOut(SignOutScope.GLOBAL) } // best-effort(token 失効は EF の役目)
        backup = AccountBackupStatus.Anonymous
    }

    // ---- エラー写像(iOS mapLinkError / mapPKCECallback 相当の簡易版)----

    /** 例外を利用者向け AccountLinkError に写像。message 内の error code トークンで判定。 */
    private fun mapLinkError(e: Throwable): AccountLinkError = when (e) {
        is AccountLinkError -> e
        else -> {
            val msg = (e.message ?: "").lowercase()
            when {
                "identity_already_exists" in msg || "email_exists" in msg || "user_already_exists" in msg ->
                    AccountLinkError.AlreadyLinkedToAnotherAccount
                "provider_disabled" in msg || "manual_linking_disabled" in msg || "oauth_provider_not_supported" in msg ->
                    AccountLinkError.ProviderUnavailable
                "access_denied" in msg -> AccountLinkError.Cancelled
                else -> AccountLinkError.Failed
            }
        }
    }

    /** web callback の query から code を抽出。error_code/error は AccountLinkError に写像して投げる。
     *  OAuth callback の値は URL エンコードされ得る(code に %2B/%2F/%3D 等)ため percent-decode する。 */
    private fun parseCallbackForCode(callback: String): String {
        val query = callback.substringAfter('?', "").substringBefore('#')
        val params = query.split("&").mapNotNull {
            val i = it.indexOf('='); if (i < 0) null else it.substring(0, i) to urlDecode(it.substring(i + 1))
        }.toMap()
        params["error_code"]?.let { throw mapCallbackToken(it) }
        if (params["error"] == "access_denied") throw AccountLinkError.Cancelled
        return params["code"] ?: throw AccountLinkError.Failed
    }

    private fun urlDecode(s: String): String =
        runCatching { java.net.URLDecoder.decode(s, "UTF-8") }.getOrDefault(s)

    private fun mapCallbackToken(token: String): AccountLinkError = when (token) {
        "identity_already_exists", "email_exists", "user_already_exists" -> AccountLinkError.AlreadyLinkedToAnotherAccount
        "provider_disabled", "manual_linking_disabled", "oauth_provider_not_supported" -> AccountLinkError.ProviderUnavailable
        "access_denied" -> AccountLinkError.Cancelled
        else -> AccountLinkError.Failed
    }
}
