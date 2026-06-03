package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.CheerKind
import com.goexercise.app.domain.friends.FriendCode
import com.goexercise.app.domain.friends.FriendProfile
import com.goexercise.app.domain.friends.FriendRequest
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
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

    // ---- 連携 API 実在プローブ(P1b-2 で本実装) ----
    suspend fun signInWithGoogleIdToken(idTokenValue: String, rawNonce: String?) {
        client.auth.signInWith(IDToken) { idToken = idTokenValue; provider = Google; nonce = rawNonce }
    }

    suspend fun exchangeCode(authCode: String) {
        client.auth.exchangeCodeForSession(authCode)
    }
}
