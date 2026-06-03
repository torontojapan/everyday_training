package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import com.goexercise.app.domain.friends.FriendCode
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/** Supabase `profiles` 行。snake_case を @SerialName で iOS スキーマと一致。 */
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
