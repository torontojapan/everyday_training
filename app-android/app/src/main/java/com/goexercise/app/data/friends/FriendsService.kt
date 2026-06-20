package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.ReceivedCheer
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.ReferralConfirmation
import com.goexercise.app.domain.friends.ReferralSummary
import kotlinx.serialization.EncodeDefault
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Supabase `profiles` 行。snake_case を @SerialName で iOS スキーマと一致。
 * `weekly_achievements`(bool×7, 月→日)と `my_cat_breed` も decode/encode する
 * (実通信 2026-06-04 で列の実在を curl 確認済。iOS ProfileRow と完全一致)。
 */
@Serializable
data class ProfileRow(
    @SerialName("user_id") val userId: String,
    @SerialName("friend_code") val friendCode: String,
    @SerialName("username") val username: String = "",
    @SerialName("display_name") val displayName: String = "あなた",
    @SerialName("current_streak") val currentStreak: Int = 0,
    @SerialName("total_achieved_days") val totalAchievedDays: Int = 0,
    @SerialName("today_achieved") val todayAchieved: Boolean = false,
    @SerialName("today_category_name") val todayCategoryName: String? = null,
    @SerialName("decoration_tier") val decorationTier: Int = 0,
    @SerialName("weekly_achievements") val weeklyAchievements: List<Boolean>? = null,
    /** 日ごとの状態(DailyStatus.rawValue 文字列)の 7 要素配列。jsonb 列。iOS 1.3 パリティ。 */
    @SerialName("weekly_statuses") val weeklyStatuses: List<String>? = null,
    @SerialName("weekly_total_minutes") val weeklyTotalMinutes: Int? = null,
    @SerialName("monthly_total_minutes") val monthlyTotalMinutes: Int? = null,
    @SerialName("monthly_achieved_days") val monthlyAchievedDays: Int? = null,
    @SerialName("my_cat_breed") val myCatBreed: String? = null,
    /** プロフィール最終更新(timestamptz)。友達詳細「最終更新 N前」。iOS lastUpdated 相当。
     *  **読み取り専用**: upsert では送らない(iOS ProfileWrite は updated_at を含めない)。
     *  encodeDefaults=true のため明示 null を送ると NOT NULL 列(DB default now())を上書きして 23502 になる
     *  → @EncodeDefault(NEVER) で null 時はエンコード除外し、DB の default/trigger に委ねる。 */
    @EncodeDefault(EncodeDefault.Mode.NEVER)
    @SerialName("updated_at") val updatedAt: String? = null,
    /** 今日の種目別詳細(jsonb 配列)。iOS `today_exercise_details`(opt-in 共有・既定 OFF)。
     *  **読み取り専用**: Android は自分の詳細を publish しない(共有 opt-in トグル未導入のため・既定 OFF の iOS と非対称にならない)。
     *  書き込み時は null(= 自分の行は詳細なし)。各ユーザーは自分の行のみ書くため他者の値を消さない。 */
    @SerialName("today_exercise_details") val todayExerciseDetails: List<SharedExerciseDetailRow>? = null,
)

/** `today_exercise_details` jsonb 要素。iOS `SharedExerciseDetail` の Codable キー(プロパティ名)と一致。 */
@Serializable
data class SharedExerciseDetailRow(
    @SerialName("id") val id: String? = null,
    @SerialName("name") val name: String,
    @SerialName("durationMinutes") val durationMinutes: Int? = null,
    @SerialName("reps") val reps: Int? = null,
    @SerialName("sets") val sets: Int? = null,
)

@Serializable
data class FriendshipRow(
    @SerialName("user_a") val userA: String,
    @SerialName("user_b") val userB: String,
    @SerialName("status") val status: String = "active",
)

@Serializable
data class RequestRow(
    @SerialName("id") val id: String,
    @SerialName("from_user") val fromUser: String,
    @SerialName("to_user") val toUser: String,
    @SerialName("status") val status: String = "pending",
)

@Serializable
data class RequestWrite(
    @SerialName("from_user") val fromUser: String,
    @SerialName("to_user") val toUser: String,
    @SerialName("status") val status: String = "pending",
)

@Serializable
data class CheerWrite(
    @SerialName("from_user") val fromUser: String,
    @SerialName("to_user") val toUser: String,
    @SerialName("kind") val kind: String,
    /** 任意の一言コメント(message 列。null なら従来どおりコメント無し)。 */
    @SerialName("message") val message: String? = null,
)

/** cheers 行の読み取り用(受信表示)。 */
@Serializable
data class CheerRow(
    @SerialName("id") val id: String,
    @SerialName("from_user") val fromUser: String,
    @SerialName("kind") val kind: String,
    @SerialName("message") val message: String? = null,
    @SerialName("created_at") val createdAt: String,
)

@Serializable
data class ReferralRow(
    @SerialName("referrer_user_id") val referrerUserId: String,
    @SerialName("referee_user_id") val refereeUserId: String,
    @SerialName("status") val status: String = "pending",
    @SerialName("confirmed_at") val confirmedAt: String? = null,
    @SerialName("seen_by_referrer") val seenByReferrer: Boolean = false,
)

@Serializable
data class ReferralInsert(
    @SerialName("referrer_user_id") val referrerUserId: String,
    @SerialName("referee_user_id") val refereeUserId: String,
)

@Serializable
data class ReferralConfirmUpdate(
    @SerialName("status") val status: String,
    @SerialName("confirmed_at") val confirmedAt: String,
)

@Serializable
data class ReferralSeenUpdate(
    @SerialName("seen_by_referrer") val seenByReferrer: Boolean,
)

/**
 * Supabase `user_records` 行(記録のクラウドバックアップ)。iOS `UserRecordRow` と同形。
 * payload は kind ごとの JSON(サーバは解釈しない同期ストア)。スキーマ正本 = supabase/schema.sql。
 */
@Serializable
data class UserRecordRow(
    @SerialName("user_id") val userId: String,
    @SerialName("record_id") val recordId: String,
    @SerialName("kind") val kind: String,
    @SerialName("payload") val payload: kotlinx.serialization.json.JsonObject,
    @SerialName("updated_at") val updatedAt: String,
    @SerialName("deleted") val deleted: Boolean = false,
)

/** 論理削除(tombstone)更新。payload は空に軽量化(iOS UserRecordTombstone と同形)。 */
@Serializable
data class UserRecordTombstoneUpdate(
    @SerialName("deleted") val deleted: Boolean,
    @SerialName("payload") val payload: kotlinx.serialization.json.JsonObject,
    @SerialName("updated_at") val updatedAt: String,
)

/**
 * クラウドバックアップ1行ぶんのニュートラル DTO。iOS `BackupRecord` の移植。
 * payload のクロスOS契約(キー名/日付形式)は RecordSyncCoordinator が正本。
 */
data class BackupRecord(
    /** record_id(workout/weight/menstrual は UUID 文字列, rescued_day は "rescued-YYYY-MM-DD")。 */
    val id: String,
    /** workout / weight / menstrual / rescued_day */
    val kind: String,
    val payload: kotlinx.serialization.json.JsonObject,
    val updatedAt: java.time.Instant,
    val deleted: Boolean,
)

internal fun ProfileRow.toProfile(): FriendProfile = FriendProfile(
    friendCode = friendCode,
    username = username,
    displayName = displayName,
    currentStreak = currentStreak,
    totalAchievedDays = totalAchievedDays,
    todayAchieved = todayAchieved,
    todayCategoryName = todayCategoryName,
    decorationTier = decorationTier,
    weeklyAchievements = weeklyAchievements,
    // rawValue → DailyStatus(未知値は Future フォールバックで 7 要素長を保持。iOS 1.3 と同じ防御)。
    weeklyStatuses = weeklyStatuses?.map { com.goexercise.app.domain.DailyStatus.fromRaw(it) },
    weeklyTotalMinutes = weeklyTotalMinutes,
    monthlyTotalMinutes = monthlyTotalMinutes,
    monthlyAchievedDays = monthlyAchievedDays,
    // 未知/将来の breed は **null**(orange に潰さない)。iOS の `CatBreed(rawValue:)`=未知 nil と一致。
    // fromRaw(=Default) はローカル設定用で、サーバ decode には使わない。
    myCatBreed = myCatBreed?.let { raw -> com.goexercise.app.domain.CatBreed.entries.firstOrNull { it.rawValue == raw } },
    // 最終更新(timestamptz)。ISO(Z) / オフセット両対応で寛容にパース、失敗は null(UI は行を出さない)。
    lastUpdated = updatedAt?.let { s ->
        runCatching { java.time.Instant.parse(s) }
            .recoverCatching { java.time.OffsetDateTime.parse(s).toInstant() }
            .getOrNull()
    },
    // today_exercise_details(jsonb)→ 構造化詳細へデコード。summary は SharedExerciseDetail が iOS と
    // 同一形式で計算する。空配列は null 扱いにして「詳細は共有されていません」フォールバックへ寄せる。
    todayExerciseDetails = todayExerciseDetails
        ?.map { com.goexercise.app.domain.friends.SharedExerciseDetail(name = it.name, durationMinutes = it.durationMinutes, reps = it.reps, sets = it.sets) }
        ?.takeIf { it.isNotEmpty() },
    // connected_since は iOS も実 BE では nil(SupabaseFriendsService が connectedSince: nil で構築)。
    // よって Android も null のまま(「つながって」タイルは Mock seed でのみ表示。iOS と一致)。
)

/** friends 操作のエラー。iOS FriendsServiceError 相当。 */
sealed class FriendsError(message: String) : Exception(message) {
    data object NotSignedIn : FriendsError("サインインしていません")
    data object CannotAddSelf : FriendsError("自分は追加できません")
    data object CodeNotFound : FriendsError("その友達コードは見つかりません")
    data object AlreadyFriends : FriendsError("すでに友達です")
    data object DuplicateRequest : FriendsError("すでに申請済みです")
}

/**
 * 友達バックエンドの抽象(社交フロー)。iOS `FriendsService` の移植(連携 API は P1b-2 で別途)。
 * 実装は設定済みなら [SupabaseFriendsService]、未設定なら [MockFriendsService]。
 */
interface FriendsService {
    val isMock: Boolean
    suspend fun myProfile(): FriendProfile?
    suspend fun signIn(displayName: String, username: String)
    suspend fun signOut()
    suspend fun refreshFriends(): List<FriendProfile>
    suspend fun pendingRequests(): List<FriendRequest>
    /** ユーザー名(部分一致)で他ユーザーを検索する。iOS searchByUsername 相当。自分は除外。 */
    suspend fun searchByUsername(query: String): List<FriendProfile> = emptyList()
    suspend fun sendRequest(toCode: String)
    suspend fun acceptRequest(request: FriendRequest)
    suspend fun declineRequest(request: FriendRequest)
    suspend fun removeFriend(profile: FriendProfile)
    suspend fun sendCheer(kind: CheerKind, toCode: String, message: String? = null)
    suspend fun publishMyProfile(profile: FriendProfile)

    /** 自分宛ての未読応援(前回チェック以降)。既定は空。Supabase が watermark 付きで実装。 */
    suspend fun unseenReceivedCheers(): List<ReceivedCheer> = emptyList()

    // ---- 友達紹介(リファラル)。既定は安全側 no-op。実装は Supabase/Mock が override ----
    suspend fun submitInviteCode(code: String) { throw FriendsError.NotSignedIn }
    suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? = null
    suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> = emptyList()
    suspend fun referralSummary(): ReferralSummary = ReferralSummary.EMPTY
    suspend fun hasReferrer(): Boolean = false

    // ---- アカウント連携(#5 / Phase2。既定は未サポート=providerUnavailable, iOS 既定実装と同型)----
    // **Android は iOS の鏡像**: Google=native id_token(iOS の Apple 相当)/ Apple=web/PKCE(iOS の Google 相当)。
    /** 永続アカウント連携の状態(匿名でないか)。 */
    val backupStatus: AccountBackupStatus get() = AccountBackupStatus.Anonymous
    suspend fun refreshBackupStatus() {}
    /** 復元/切替の前に、現匿名セッションに失われると困るデータ(友達)があるか。 */
    suspend fun anonymousSessionHasData(): Boolean = false
    /** アカウント削除(審査 5.1.1(v))。 */
    suspend fun deleteAccount() { throw FriendsError.NotSignedIn }

    // Google = native id_token(Credential Manager)。uid 保持で連結 / 切替 / 復元。
    suspend fun linkGoogleIdToken(idToken: String) { throw AccountLinkError.ProviderUnavailable }
    suspend fun switchToGoogleIdToken(idToken: String) { throw AccountLinkError.ProviderUnavailable }
    suspend fun restoreWithGoogleIdToken(idToken: String): RestoreOutcome { throw AccountLinkError.ProviderUnavailable }

    // Apple = web/PKCE(Custom Tabs)。flow が認可 URL を開き callback を返す。
    suspend fun linkAppleWeb(flow: WebAuthFlow) { throw AccountLinkError.ProviderUnavailable }
    suspend fun switchToAppleWeb(flow: WebAuthFlow) { throw AccountLinkError.ProviderUnavailable }
    suspend fun restoreWithAppleWeb(flow: WebAuthFlow): RestoreOutcome { throw AccountLinkError.ProviderUnavailable }

    // ---- 記録のクラウドバックアップ(user_records, iOS/Android 共通スキーマ)----

    /** 変更行をまとめて upsert(PK = user_id × record_id で冪等)。 */
    suspend fun backupUpsert(records: List<BackupRecord>)
    /** 本人の全行(tombstone 含む)を取得。復元・同期のプル側。未サインインは空。 */
    suspend fun backupFetchAll(): List<BackupRecord>
    /** 指定 record_id を論理削除(deleted=true, payload 空)。他端末へ削除を伝播。 */
    suspend fun backupMarkDeleted(recordIds: List<String>)
    /** 本人の全行を物理削除(設定「すべての記録を削除」用)。 */
    suspend fun backupWipeAll()
}

/**
 * Supabase 未設定時のフォールバック(iOS MockFriendsService 相当)。完全インメモリ。
 * UI/スクショ/テストを実通信なしで回せるよう、デモ友達と受信申請をシードする。
 */
class MockFriendsService : FriendsService {
    override val isMock: Boolean = true

    private var me: FriendProfile? = null
    private val friends = mutableListOf<FriendProfile>()
    private val incoming = mutableListOf<FriendRequest>()
    private var backup = AccountBackupStatus.Anonymous

    // referee 視点: 自分が入力した紹介(あれば1件)。
    private var myReferral: MockReferral? = null
    // referrer 視点: 自分が紹介し confirmed になった件(seen フラグ付き)。
    private val inbound = mutableListOf<MockInbound>()
    private data class MockReferral(val referrerCode: String, var confirmed: Boolean, var confirmedAt: java.time.Instant?)
    private data class MockInbound(val refereeName: String, val at: java.time.Instant, var seen: Boolean)

    override suspend fun myProfile(): FriendProfile? = me

    override suspend fun signIn(displayName: String, username: String) {
        val name = displayName.trim().ifEmpty { "あなた" }
        me = FriendProfile(
            friendCode = FriendCode.generate(),
            username = username.trim(),
            displayName = name,
            currentStreak = 0,
            totalAchievedDays = 0,
            todayAchieved = false,
        )
        seedDemo()
    }

    override suspend fun signOut() {
        me = null
        friends.clear()
        incoming.clear()
        backup = AccountBackupStatus.Anonymous
        myReferral = null
        inbound.clear()
        backupRows.clear()
    }

    override suspend fun refreshFriends(): List<FriendProfile> = friends.toList()

    override suspend fun searchByUsername(query: String): List<FriendProfile> {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return emptyList()
        // デモ: 検索用の見知らぬユーザー数名 + 既存友達から username/displayName 部分一致。
        val pool = friends + listOf(
            FriendProfile("SAKURA", "sakura_run", "さくら", currentStreak = 8, totalAchievedDays = 30, todayAchieved = true),
            FriendProfile("REN001", "ren_fit", "れん", currentStreak = 21, totalAchievedDays = 60, todayAchieved = false),
        )
        return pool.filter { it.username.lowercase().contains(q) || it.displayName.lowercase().contains(q) }
    }

    override suspend fun pendingRequests(): List<FriendRequest> = incoming.toList()

    override suspend fun sendRequest(toCode: String) {
        val target = toCode.uppercase()
        if (me?.friendCode == target) throw FriendsError.CannotAddSelf
        if (friends.any { it.friendCode == target }) throw FriendsError.AlreadyFriends
        // Mock: 申請相手が存在しないので、デモとして即フレンド化(UI 動作確認用)。
        friends.add(
            FriendProfile(friendCode = target, username = "user_$target", displayName = "新しい友達", currentStreak = 1, totalAchievedDays = 1, todayAchieved = true),
        )
    }

    override suspend fun acceptRequest(request: FriendRequest) {
        incoming.removeAll { it.id == request.id }
        friends.add(request.fromProfile)
    }

    override suspend fun declineRequest(request: FriendRequest) {
        incoming.removeAll { it.id == request.id }
    }

    override suspend fun removeFriend(profile: FriendProfile) {
        friends.removeAll { it.friendCode == profile.friendCode }
    }

    override suspend fun sendCheer(kind: CheerKind, toCode: String, message: String?) {
        /* Mock: no-op(送信したことにする) */
    }

    override suspend fun publishMyProfile(profile: FriendProfile) {
        me = profile
    }

    override suspend fun submitInviteCode(code: String) {
        val meNow = me ?: throw FriendsError.NotSignedIn
        val upper = code.uppercase()
        if (upper == meNow.friendCode) throw FriendsError.CannotAddSelf
        if (myReferral != null) throw FriendsError.DuplicateRequest
        val referrer = friends.firstOrNull { it.friendCode == upper }
            ?: incoming.firstOrNull { it.fromProfile.friendCode == upper }?.fromProfile
            ?: FriendProfile(friendCode = upper, username = "user_$upper", displayName = "紹介者", currentStreak = 1, totalAchievedDays = 1, todayAchieved = true)
        myReferral = MockReferral(referrer.friendCode, confirmed = false, confirmedAt = null)
        if (friends.none { it.friendCode == referrer.friendCode }) friends.add(referrer)
        incoming.removeAll { it.fromProfile.friendCode == referrer.friendCode }
    }

    override suspend fun confirmReferralIfEligible(hasFirstRecord: Boolean): ReferralConfirmation? {
        val r = myReferral ?: return null
        if (!hasFirstRecord || r.confirmed) return null
        r.confirmed = true; r.confirmedAt = java.time.Instant.now()
        val name = friends.firstOrNull { it.friendCode == r.referrerCode }?.displayName ?: "ともだち"
        return ReferralConfirmation(id = me?.friendCode ?: "me", friendDisplayName = name, role = ReferralConfirmation.Role.REFEREE)
    }

    override suspend fun unseenReferrerConfirmations(): List<ReferralConfirmation> {
        val unseen = inbound.filter { !it.seen }
        unseen.forEach { it.seen = true }
        return unseen.mapIndexed { i, c -> ReferralConfirmation(id = "ref-$i", friendDisplayName = c.refereeName, role = ReferralConfirmation.Role.REFERRER) }
    }

    override suspend fun referralSummary(): ReferralSummary {
        val now = java.time.Instant.now()
        fun sameMonth(t: java.time.Instant): Boolean {
            // ローカル暦で判定(allowance の月境界と一致。ReferralClock と同じ理由)。
            val a = t.atZone(java.time.ZoneId.systemDefault()); val b = now.atZone(java.time.ZoneId.systemDefault())
            return a.year == b.year && a.monthValue == b.monthValue
        }
        val stars = inbound.size
        var bonus = inbound.count { sameMonth(it.at) }
        myReferral?.let { if (it.confirmed && it.confirmedAt?.let(::sameMonth) == true) bonus++ }
        return ReferralSummary(starBadges = stars, freezeBonusThisMonth = bonus)
    }

    override suspend fun hasReferrer(): Boolean = myReferral != null

    /** テスト用: 紹介者として誰かを紹介し confirmed になった状態を注入する。 */
    fun seedInboundConfirmation(refereeName: String, at: java.time.Instant = java.time.Instant.now(), seen: Boolean = false) {
        inbound.add(MockInbound(refereeName, at, seen))
    }

    // ---- アカウント連携シミュレーション(dev/screenshot 用。iOS Mock は providerUnavailable 既定だが、
    // Android は連携 UI/VM フローを実通信なしで通せるよう簡易シミュレートする)----
    override val backupStatus: AccountBackupStatus get() = backup

    override suspend fun refreshBackupStatus() { /* backup は同期的に最新 */ }

    override suspend fun anonymousSessionHasData(): Boolean = friends.isNotEmpty() && !backup.isBackedUp

    override suspend fun deleteAccount() {
        me = null
        friends.clear()
        incoming.clear()
        backup = AccountBackupStatus.Anonymous
        myReferral = null
        inbound.clear()
        backupRows.clear()
    }

    override suspend fun linkGoogleIdToken(idToken: String) {
        if (idToken.contains("collide")) throw AccountLinkError.AlreadyLinkedToAnotherAccount
        backup = AccountBackupStatus(isBackedUp = true, providerName = "google")
    }

    override suspend fun switchToGoogleIdToken(idToken: String) {
        // 切替: 現データ破棄 → 既存アカウントをロード(Mock は profile を保持し backup 済みにする)。
        ensureMockProfile("google")
    }

    override suspend fun restoreWithGoogleIdToken(idToken: String): RestoreOutcome =
        restoreMock(provider = "google", asNew = idToken.contains("new"))

    override suspend fun linkAppleWeb(flow: WebAuthFlow) {
        consumeMockCallback(flow)
        backup = AccountBackupStatus(isBackedUp = true, providerName = "apple")
    }

    override suspend fun switchToAppleWeb(flow: WebAuthFlow) {
        consumeMockCallback(flow)
        ensureMockProfile("apple")
    }

    override suspend fun restoreWithAppleWeb(flow: WebAuthFlow): RestoreOutcome {
        val asNew = consumeMockCallback(flow).contains("new")
        return restoreMock(provider = "apple", asNew = asNew)
    }

    /** Mock の web flow callback を解釈し、衝突/キャンセルを例外に写像する(iOS mapPKCECallback 相当の簡易版)。 */
    private suspend fun consumeMockCallback(flow: WebAuthFlow): String {
        val cb = flow("https://mock.supabase.co/authorize?provider=apple")
        when {
            cb.contains("identity_already_exists") -> throw AccountLinkError.AlreadyLinkedToAnotherAccount
            cb.contains("access_denied") -> throw AccountLinkError.Cancelled
            cb.contains("provider_disabled") -> throw AccountLinkError.ProviderUnavailable
        }
        return cb
    }

    private fun ensureMockProfile(provider: String) {
        if (me == null) {
            me = FriendProfile(friendCode = FriendCode.generate(), username = "you", displayName = "あなた", currentStreak = 0, totalAchievedDays = 0, todayAchieved = false)
        }
        backup = AccountBackupStatus(isBackedUp = true, providerName = provider)
    }

    // ---- 記録バックアップ(in-memory モック。テスト/エミュ確認用。iOS Mock と同セマンティクス)----
    private val backupRows = mutableMapOf<String, BackupRecord>()

    override suspend fun backupUpsert(records: List<BackupRecord>) {
        if (me == null) throw FriendsError.NotSignedIn
        records.forEach { backupRows[it.id] = it }
    }

    override suspend fun backupFetchAll(): List<BackupRecord> {
        if (me == null) return emptyList()
        return backupRows.values.toList()
    }

    override suspend fun backupMarkDeleted(recordIds: List<String>) {
        if (me == null) throw FriendsError.NotSignedIn
        recordIds.forEach { id ->
            backupRows[id]?.let {
                backupRows[id] = it.copy(payload = kotlinx.serialization.json.JsonObject(emptyMap()), deleted = true)
            }
        }
    }

    override suspend fun backupWipeAll() {
        if (me == null) throw FriendsError.NotSignedIn
        backupRows.clear()
    }

    private fun restoreMock(provider: String, asNew: Boolean): RestoreOutcome {
        ensureMockProfile(provider)
        return if (asNew) {
            RestoreOutcome.Created
        } else {
            seedDemo() // 既存アカウントの友達/申請が「戻った」体で復元
            RestoreOutcome.Restored
        }
    }

    private fun seedDemo() {
        if (friends.isEmpty()) {
            friends.add(FriendProfile("ABC234", "haru", "はる", currentStreak = 12, totalAchievedDays = 40, todayAchieved = true, weeklyTotalMinutes = 120, weeklyAchievements = listOf(true, true, false, true, true, false, false), weeklyStatuses = listOf(com.goexercise.app.domain.DailyStatus.Achieved, com.goexercise.app.domain.DailyStatus.Rest, com.goexercise.app.domain.DailyStatus.Rescued, com.goexercise.app.domain.DailyStatus.Achieved, com.goexercise.app.domain.DailyStatus.TodayAchieved, com.goexercise.app.domain.DailyStatus.Future, com.goexercise.app.domain.DailyStatus.Future), myCatBreed = com.goexercise.app.domain.CatBreed.Black, todayCategoryName = "筋トレ", todayExerciseDetails = listOf(com.goexercise.app.domain.friends.SharedExerciseDetail("スクワット", reps = 20, sets = 3), com.goexercise.app.domain.friends.SharedExerciseDetail("ベンチプレス", durationMinutes = 20, reps = 10, sets = 3)), lastUpdated = java.time.Instant.now().minusSeconds(7200), connectedSince = java.time.Instant.now().minusSeconds(30L * 86400)))
            friends.add(FriendProfile("XYZ789", "kenta", "けんた", currentStreak = 3, totalAchievedDays = 8, todayAchieved = false, weeklyTotalMinutes = 45, weeklyAchievements = listOf(true, false, false, true, false, false, false), weeklyStatuses = listOf(com.goexercise.app.domain.DailyStatus.Achieved, com.goexercise.app.domain.DailyStatus.Missed, com.goexercise.app.domain.DailyStatus.Rest, com.goexercise.app.domain.DailyStatus.Achieved, com.goexercise.app.domain.DailyStatus.TodayPending, com.goexercise.app.domain.DailyStatus.Future, com.goexercise.app.domain.DailyStatus.Future), myCatBreed = com.goexercise.app.domain.CatBreed.Gray, lastUpdated = java.time.Instant.now().minusSeconds(86400), connectedSince = java.time.Instant.now().minusSeconds(7L * 86400)))
        }
        if (incoming.isEmpty()) {
            incoming.add(FriendRequest(id = UUID.randomUUID().toString(), fromProfile = FriendProfile("REQ456", "mei", "めい", currentStreak = 5, totalAchievedDays = 15, todayAchieved = true)))
        }
    }
}
