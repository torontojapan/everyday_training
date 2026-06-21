package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.ReceivedCheer
import io.github.jan.supabase.postgrest.query.Order
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.domain.friends.ReferralSummary
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
class SupabaseFriendsService(
    private val client: SupabaseClient,
    private val cheerWatermark: CheerWatermarkStore? = null,
) : FriendsService {

    override val isMock: Boolean = false

    private suspend fun ensureUid(): String {
        // 起動直後はストレージからのセッション復元が未完のことがある。匿名作成前に初期化を待つ。
        // ここを怠ると既存の連携アカウント(Apple/Google)が一時的に未ロードの隙に新規匿名アカウントを
        // 作って上書きし、友達/星を喪失する(iOS の sessionMissing 限定ガードと対称)。
        runCatching { client.auth.awaitInitialization() }
        client.auth.currentUserOrNull()?.id?.let { return it }
        // 初期化後も user が無いが session は在る(リフレッシュ失敗等の一時障害)→ 匿名で上書きせずエラー。
        if (client.auth.currentSessionOrNull() != null) throw FriendsError.NotSignedIn
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

    // UUID 大小を正規化して friendships_check 違反(iOS UUID 大文字由来の ship-blocker)を防ぐ。
    // ロジックは FriendshipPair に集約し回帰テスト([FriendshipPairTest])で担保。
    private fun orderedPair(a: String, b: String): Pair<String, String> = FriendshipPair.ordered(a, b)

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
        // anti-resurrection の手順判断は AccountDeletionFlow に集約(回帰テストで担保)。
        // **匿名のときだけ**クラウドデータを削除する(=iOS「忘れる」セマンティクス)。連携済み
        // (バックアップ)は保持=別端末/再サインインで復旧可能。ensureUid は呼ばない(サインアウト中に
        // 新規匿名セッションを作らない)。uid 取得失敗時は不確実なので削除しない(安全側=誤削除より残留)。
        val user = client.auth.currentUserOrNull()
        AccountDeletionFlow.signOut(
            user = user?.let { AccountDeletionFlow.SessionUser(isAnonymous = it.isAnonymous == true) },
            // 匿名は signOut=auth 削除されない(cascade 不発)ため、本人スコープの機微行も明示削除する。
            // best-effort(各テーブル独立): 一部失敗でも auth signOut まで到達させる。
            deleteOwnedData = { user?.id?.let { uid -> deleteOwnedRows(uid, bestEffort = true) } },
            signOut = {
                client.auth.signOut()
                backup = AccountBackupStatus.Anonymous
            },
        )
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

    override suspend fun searchByUsername(query: String): List<FriendProfile> {
        val q = query.trim()
        if (q.isEmpty()) return emptyList()
        val uid = client.auth.currentUserOrNull()?.id
        // username 部分一致(大小無視 ilike)。自分自身は除外。最大 25 件。iOS searchByUsername パリティ。
        return client.from("profiles").select {
            filter { ilike("username", "%$q%") }
            limit(25)
        }.decodeList<ProfileRow>()
            .filter { it.userId != uid }
            .map { it.toProfile() }
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

    override suspend fun sendCheer(kind: CheerKind, toCode: String, message: String?) {
        val uid = ensureUid()
        val toId = profileRowByCode(toCode)?.userId ?: throw FriendsError.CodeNotFound
        // 一言コメント: クライアント 30 字 + DB 60 字 check の二重ガード(送信前に最終クランプ)。
        val clamped = message?.trim()?.takeIf { it.isNotEmpty() }?.take(30)
        try {
            client.from("cheers").insert(CheerWrite(fromUser = uid, toUser = toId, kind = kind.rawValue, message = clamped))
        } catch (e: Exception) {
            // 本番に message 列が未適用の環境では列エラーになるため、コメント無しで再送する
            // (応援自体は届く。列適用後は自動的にコメント付きになる)。iOS と同型のフォールバック。
            if (clamped != null && (e.message?.contains("message") == true)) {
                client.from("cheers").insert(CheerWrite(fromUser = uid, toUser = toId, kind = kind.rawValue, message = null))
            } else {
                throw e
            }
        }
    }

    override suspend fun unseenReceivedCheers(): List<ReceivedCheer> {
        val store = cheerWatermark ?: return emptyList()
        val uid = client.auth.currentUserOrNull()?.id?.lowercase() ?: return emptyList()
        val last = store.lastSeen(uid)
        val now = System.currentTimeMillis()
        if (last == null) {
            // 初回は「今」を起点にして過去の蓄積を一気に出さない(前進ロジックは CheerWatermarkLogic に集約)。
            store.setLastSeen(uid, CheerWatermarkLogic.evaluate(null, now, emptyList()).newWatermark)
            return emptyList()
        }
        val sinceIso = backupTimestamp(java.time.Instant.ofEpochMilli(last))
        val rows = client.from("cheers").select {
            filter {
                eq("to_user", uid)
                gt("created_at", sinceIso)
            }
            order("created_at", io.github.jan.supabase.postgrest.query.Order.ASCENDING)
        }.decodeList<CheerRow>()
        if (rows.isEmpty()) return emptyList()
        val fromIds = rows.map { it.fromUser.lowercase() }.distinct()
        val profs = client.from("profiles").select {
            filter { isIn("user_id", fromIds) }
        }.decodeList<ProfileRow>()
        val nameById = profs.associate { it.userId.lowercase() to it.displayName }
        val parsed = rows.map { row ->
            ReceivedCheer(
                id = row.id,
                fromDisplayName = nameById[row.fromUser.lowercase()] ?: "ともだち",
                kindRaw = row.kind,
                message = row.message,
                createdAtEpochMs = (com.goexercise.app.domain.friends.ReferralClock.parseTimestamp(row.createdAt)
                    ?: java.time.Instant.now()).toEpochMilli(),
            )
        }
        // watermark の前進と「より後だけ surface」は CheerWatermarkLogic に一本化する
        // (サーバ側 gt フィルタが緩んでも二度出さない多層防御)。
        val outcome = CheerWatermarkLogic.evaluate(last, now, parsed)
        store.setLastSeen(uid, outcome.newWatermark)
        return outcome.unseen
    }

    override suspend fun publishMyProfile(profile: FriendProfile) {
        // **非作成**: publish は常に「既存プロフィールの更新」。ensureUid は使わない
        // (Home の自動 publish 等で未サインイン時に呼ばれても匿名アカウントを新規作成させない=opt-in 厳守。
        //  作成は signIn/連携/復元のみ)。サインアウト直後のレースでも孤児を作らず NotSignedIn で弾く。
        val uid = client.auth.currentUserOrNull()?.id ?: throw FriendsError.NotSignedIn
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
            weeklyAchievements = profile.weeklyAchievementsOrEmpty,
            weeklyStatuses = profile.weeklyStatuses?.map { it.rawValue },
            weeklyTotalMinutes = profile.weeklyTotalMinutes,
            monthlyTotalMinutes = profile.monthlyTotalMinutes,
            monthlyAchievedDays = profile.monthlyAchievedDays,
            // 猫=従来 rawValue("orange")/犬="dog:shiba"。旧クライアントは犬を既定猫にフォールバック(列追加不要)。
            myCatBreed = profile.myPet?.friendBreedString,
            // 種目詳細の共有(opt-in 時のみ非 null)。OFF なら null を書いて列をクリア(=共有停止)。iOS パリティ。
            todayExerciseDetails = profile.todayExerciseDetails?.map {
                SharedExerciseDetailRow(name = it.name, durationMinutes = it.durationMinutes, reps = it.reps, sets = it.sets)
            },
        )
        client.from("profiles").upsert(row) { onConflict = "user_id" }
    }

    // ================= 友達紹介(リファラル)=================

    override suspend fun submitInviteCode(code: String) {
        val uid = ensureUid()
        val target = code.uppercase()
        val me = profileRow(uid)
        if (me?.friendCode == target) throw FriendsError.CannotAddSelf
        val referrer = profileRowByCode(target) ?: throw FriendsError.CodeNotFound
        if (referrer.userId == uid) throw FriendsError.CannotAddSelf
        val existing = client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>()
        if (existing.isNotEmpty()) throw FriendsError.DuplicateRequest
        client.from("referrals").insert(ReferralInsert(referrerUserId = referrer.userId, refereeUserId = uid))
        val (a, b) = orderedPair(uid, referrer.userId)
        client.from("friendships").upsert(FriendshipRow(userA = a, userB = b, status = "active")) { onConflict = "user_a,user_b" }
    }

    override suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? {
        if (!hasFirstRecord) return null
        val uid = ensureUid()
        val row = client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>().firstOrNull() ?: return null
        if (row.status != "pending") return null
        val nowIso = java.time.OffsetDateTime.now(java.time.ZoneOffset.UTC)
            .format(java.time.format.DateTimeFormatter.ISO_OFFSET_DATE_TIME)
        client.from("referrals").update(ReferralConfirmUpdate(status = "confirmed", confirmedAt = nowIso)) {
            filter { eq("referee_user_id", uid) }
        }
        val referrerName = profileRow(row.referrerUserId)?.displayName ?: "ともだち"
        return ReferralConfirmation(id = uid, friendDisplayName = referrerName, role = ReferralConfirmation.Role.REFEREE)
    }

    override suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> {
        val uid = client.auth.currentUserOrNull()?.id ?: return emptyList()
        val rows = client.from("referrals").select {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed"); eq("seen_by_referrer", false) }
        }.decodeList<ReferralRow>()
        if (rows.isEmpty()) return emptyList()
        val refereeIds = rows.map { it.refereeUserId }
        val byId = client.from("profiles").select { filter { isIn("user_id", refereeIds) } }
            .decodeList<ProfileRow>().associateBy { it.userId }
        // 取得した分だけを seen=true にする(referee_user_id で限定)。SELECT〜UPDATE の間に別の
        // confirmed が届いても「返していない行」を seen にして祝祭を取りこぼさない(iOS パリティ・select/update レース)。
        client.from("referrals").update(ReferralSeenUpdate(seenByReferrer = true)) {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed"); eq("seen_by_referrer", false); isIn("referee_user_id", refereeIds) }
        }
        return rows.map { r ->
            ReferralConfirmation(id = r.refereeUserId, friendDisplayName = byId[r.refereeUserId]?.displayName ?: "ともだち", role = ReferralConfirmation.Role.REFERRER)
        }
    }

    override suspend fun referralSummary(): ReferralSummary {
        val uid = client.auth.currentUserOrNull()?.id ?: return ReferralSummary.EMPTY
        val now = java.time.Instant.now()
        val asReferrer = client.from("referrals").select {
            filter { eq("referrer_user_id", uid); eq("status", "confirmed") }
        }.decodeList<ReferralRow>()
        val stars = asReferrer.size
        var bonus = asReferrer.count { com.goexercise.app.domain.friends.ReferralClock.isInMonth(it.confirmedAt, now) }
        val asReferee = client.from("referrals").select {
            filter { eq("referee_user_id", uid); eq("status", "confirmed") }; limit(1)
        }.decodeList<ReferralRow>().firstOrNull()
        if (asReferee != null && com.goexercise.app.domain.friends.ReferralClock.isInMonth(asReferee.confirmedAt, now)) bonus++
        return ReferralSummary(starBadges = stars, freezeBonusThisMonth = bonus)
    }

    override suspend fun hasReferrer(): Boolean {
        val uid = client.auth.currentUserOrNull()?.id ?: return false
        return client.from("referrals").select {
            filter { eq("referee_user_id", uid) }; limit(1)
        }.decodeList<ReferralRow>().isNotEmpty()
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
            // 連携済みプロバイダを **全部** 取得する(anonymous 除外・重複は順序保持で除去)。
            // 旧実装は firstOrNull で1つだけ拾っていたため、Apple/Google 両方連携時に
            // 並び順次第で「Apple なのに Google でバックアップ中」と誤表示していた(iOS 1.3 パリティ)。
            val providers = user.identities.orEmpty()
                .map { it.provider }
                .filter { it != "anonymous" }
                .distinct()
            AccountBackupStatus(isBackedUp = user.isAnonymous != true, providerNames = providers)
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
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
        return finishOrRollback()
    }

    /** 認可成立後の profile ロード等で失敗したら、半端な切替状態を残さずローカルサインアウトで巻き戻す。
     *  これが無いと、後続の ensureUid(自動既定名)が新 uid 上に他人の既存プロフィールを上書きしうる(iOS の
     *  signOut(scope:.local) ロールバックと対称)。 */
    private suspend fun finishOrRollback(): RestoreOutcome =
        try {
            finishIdentitySwitch()
        } catch (e: Exception) {
            runCatching { client.auth.signOut(SignOutScope.LOCAL) }
            throw mapLinkError(e)
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
        } catch (e: Exception) {
            throw mapLinkError(e)
        }
        return finishOrRollback()
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
        // 二段構えの手順と fail-closed 判断は AccountDeletionFlow + DeleteAccountDecision に集約(回帰テストで担保)。
        // Stage1: Edge Function `delete-account`(service_role で auth ごと cascade 削除 + 全セッション失効)。
        // 404(未デプロイ)/ネット断/不確定のみ Stage2 へ。401/405/500 等(EF 到達後の失敗)は **fail closed**
        // (success 誤報告で auth 行/refresh token が生き残り復活するのを防ぐ)。
        AccountDeletionFlow.deleteAccount(
            invokeEdgeFunction = {
                // supabase-kt は非2xx を typed RestException で投げる前提。例外を status へ写像し、
                // fail-closed 相当(401/405/500 等)は throw して伝播(success 誤報告防止)。
                try {
                    client.functions.invoke("delete-account").status.value
                } catch (e: NotFoundRestException) {
                    404 // EF 未デプロイ → Stage2 フォールバック
                } catch (e: HttpRequestException) {
                    -1 // ネット断/到達不可 → Stage2 フォールバック(RLS も落ちれば throw され再試行可)
                } catch (e: java.io.IOException) {
                    -1
                } catch (e: Exception) {
                    throw AccountLinkError.BackendUnavailable // 401/405/500 等 → fail closed(伝播)
                }
            },
            // Success: EF が cascade 削除済 → ローカル signOut のみ(クライアント削除はしない)。
            signOutLocal = {
                backup = AccountBackupStatus.Anonymous
                client.auth.signOut(SignOutScope.LOCAL)
            },
            // Fallback Stage2: クライアント RLS で本人 uid のデータのみ削除。失敗は伝播(再試行=復活防止)。
            // user_records は体重・体調を含む機微データ。EF 不達時もサーバへ残留させない(iOS 監査是正と対称)。
            deleteOwnedData = { deleteOwnedRows(uid, bestEffort = false) },
            signOutGlobal = {
                backup = AccountBackupStatus.Anonymous
                client.auth.signOut(SignOutScope.GLOBAL) // best-effort(token 失効は EF の役目)
            },
            failClosed = { AccountLinkError.BackendUnavailable }, // 復活防止(success 誤報告しない)
        )
    }

    /**
     * 本人スコープの機微行を6テーブルから削除(cheers / friend_requests / friendships / referrals /
     * user_records / profiles)。signOut「忘れる」と deleteAccount Stage2 フォールバックで共有。
     * @param bestEffort true=各テーブル独立 best-effort(一部失敗でも残りを試行=「忘れる」を可能な限り完遂)/
     *   false=最初の失敗を伝播(削除未完了なら呼び出し側で再試行=復活防止)。
     */
    private suspend fun deleteOwnedRows(uid: String, bestEffort: Boolean) {
        suspend fun step(block: suspend () -> Unit) {
            if (bestEffort) runCatching { block() } else block()
        }
        step { client.from("cheers").delete { filter { or { eq("from_user", uid); eq("to_user", uid) } } } }
        step { client.from("friend_requests").delete { filter { or { eq("from_user", uid); eq("to_user", uid) } } } }
        step { client.from("friendships").delete { filter { or { eq("user_a", uid); eq("user_b", uid) } } } }
        step { client.from("referrals").delete { filter { or { eq("referrer_user_id", uid); eq("referee_user_id", uid) } } } }
        step { client.from("user_records").delete { filter { eq("user_id", uid) } } }
        step { client.from("profiles").delete { filter { eq("user_id", uid) } } }
    }

    // ================= 記録のクラウドバックアップ(user_records)=================
    // 体重・体調を含む機微データ。RLS で本人のみ読み書き可(profiles と違い SELECT も本人限定)。
    // payload は jsonb。クライアント間契約(キー名/日付形式)は RecordSyncCoordinator が正本。

    override suspend fun backupUpsert(records: List<BackupRecord>) {
        if (records.isEmpty()) return
        val uid = ensureUid()
        val rows = records.map { r ->
            UserRecordRow(
                userId = uid, recordId = r.id, kind = r.kind,
                payload = r.payload,
                updatedAt = backupTimestamp(r.updatedAt),
                deleted = r.deleted,
            )
        }
        client.from("user_records").upsert(rows) { onConflict = "user_id,record_id" }
    }

    override suspend fun backupFetchAll(): List<BackupRecord> {
        // 未サインインで匿名アカウントを勝手に作らない(opt-in 厳守。iOS signedInSessionOrNil→[] と同型)。
        val uid = client.auth.currentUserOrNull()?.id ?: return emptyList()
        val rows = client.from("user_records").select { filter { eq("user_id", uid) } }
            .decodeList<UserRecordRow>()
        return rows.map { row ->
            BackupRecord(
                id = row.recordId, kind = row.kind, payload = row.payload,
                updatedAt = com.goexercise.app.domain.friends.ReferralClock.parseTimestamp(row.updatedAt)
                    ?: java.time.Instant.now(),
                deleted = row.deleted,
            )
        }
    }

    override suspend fun backupMarkDeleted(recordIds: List<String>) {
        if (recordIds.isEmpty()) return
        val uid = ensureUid()
        client.from("user_records").update(
            UserRecordTombstoneUpdate(
                deleted = true,
                payload = kotlinx.serialization.json.JsonObject(emptyMap()),
                updatedAt = backupTimestamp(java.time.Instant.now()),
            ),
        ) {
            filter { eq("user_id", uid); isIn("record_id", recordIds) }
        }
    }

    override suspend fun backupWipeAll() {
        val uid = client.auth.currentUserOrNull()?.id ?: return
        client.from("user_records").delete { filter { eq("user_id", uid) } }
    }

    /** ISO8601(秒精度・UTC)。iOS ISO8601DateFormatter 既定と同形("2026-06-11T05:00:00Z")。 */
    private fun backupTimestamp(instant: java.time.Instant): String =
        java.time.format.DateTimeFormatter.ISO_INSTANT.format(instant.truncatedTo(java.time.temporal.ChronoUnit.SECONDS))

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
