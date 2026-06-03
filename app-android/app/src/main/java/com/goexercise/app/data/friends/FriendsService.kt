package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendCode
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Supabase `profiles` 行。snake_case を @SerialName で iOS スキーマと一致。
 *
 * TODO(#10 実通信PoC): `weekly_achievements`(週次達成 bool×7)を decode していないため、
 * 実バックエンドでは [FriendProfile.weeklyAchievements] が常に null となり、週間ランキングの
 * 達成日数(第3タイブレーク)が 0 固定になる。Mock では正しく算出される。サーバ列の有無を
 * 確認のうえ、存在すればここで decode + 書込み(publishMyProfile)に追加する。
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
    @SerialName("weekly_total_minutes") val weeklyTotalMinutes: Int? = null,
    @SerialName("monthly_total_minutes") val monthlyTotalMinutes: Int? = null,
    @SerialName("monthly_achieved_days") val monthlyAchievedDays: Int? = null,
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
    weeklyTotalMinutes = weeklyTotalMinutes,
    monthlyTotalMinutes = monthlyTotalMinutes,
    monthlyAchievedDays = monthlyAchievedDays,
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
    suspend fun sendRequest(toCode: String)
    suspend fun acceptRequest(request: FriendRequest)
    suspend fun declineRequest(request: FriendRequest)
    suspend fun removeFriend(profile: FriendProfile)
    suspend fun sendCheer(kind: CheerKind, toCode: String)
    suspend fun publishMyProfile(profile: FriendProfile)

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
    }

    override suspend fun refreshFriends(): List<FriendProfile> = friends.toList()

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

    override suspend fun sendCheer(kind: CheerKind, toCode: String) {
        /* Mock: no-op(送信したことにする) */
    }

    override suspend fun publishMyProfile(profile: FriendProfile) {
        me = profile
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
            friends.add(FriendProfile("ABC234", "haru", "はる", currentStreak = 12, totalAchievedDays = 40, todayAchieved = true, weeklyTotalMinutes = 120, weeklyAchievements = listOf(true, true, false, true, true, false, false)))
            friends.add(FriendProfile("XYZ789", "kenta", "けんた", currentStreak = 3, totalAchievedDays = 8, todayAchieved = false, weeklyTotalMinutes = 45, weeklyAchievements = listOf(true, false, false, true, false, false, false)))
        }
        if (incoming.isEmpty()) {
            incoming.add(FriendRequest(id = UUID.randomUUID().toString(), fromProfile = FriendProfile("REQ456", "mei", "めい", currentStreak = 5, totalAchievedDays = 15, todayAchieved = true)))
        }
    }
}
