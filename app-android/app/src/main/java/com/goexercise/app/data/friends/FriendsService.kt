package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.FriendCode
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Supabase `profiles` テーブルの行(PoC スコープの最小カラム)。iOS の ProfileRow に対応。
 * カラム名は snake_case を @SerialName で一致させ、iOS と同一スキーマを共有する。
 */
@Serializable
data class ProfileRow(
    @SerialName("user_id") val userId: String,
    @SerialName("friend_code") val friendCode: String,
    @SerialName("username") val username: String = "",
    @SerialName("display_name") val displayName: String = "あなた",
    @SerialName("current_streak") val currentStreak: Int = 0,
    @SerialName("total_achieved_days") val totalAchievedDays: Int = 0,
)

/**
 * 友達バックエンドの抽象(P1b-1 PoC スコープ)。iOS `FriendsService`/`SupabaseFriendsService` に対応。
 * 実装は設定済みなら [SupabaseFriendsService]、未設定なら [MockFriendsService](iOS と同じ Mock フォールバック)。
 * 申請/承認/cheer/週間ランキング/連携の全フローは P1b-1 の残りで追加。
 */
interface FriendsService {
    val isMock: Boolean

    /** 匿名サインインして uid を返す(lazy: 能動操作時のみ呼ぶ)。 */
    suspend fun ensureSignedInUid(): String

    /** friend code から profiles 行を検索(存在確認/友達追加)。 */
    suspend fun findProfile(friendCode: String): ProfileRow?

    /** 衝突しない friend code をクライアント生成(iOS と同方式: 生成→UNIQUE 確認リトライ)。 */
    suspend fun generateUniqueCode(): String

    /** 自分のプロフィールを upsert。 */
    suspend fun upsertProfile(row: ProfileRow)
}

/**
 * Supabase 未設定時のフォールバック(iOS と同じ)。完全インメモリで UI/テストを回せる。
 */
class MockFriendsService : FriendsService {
    override val isMock: Boolean = true

    private var uid: String? = null
    private val profiles = mutableMapOf<String, ProfileRow>() // friendCode -> row

    override suspend fun ensureSignedInUid(): String =
        uid ?: java.util.UUID.randomUUID().toString().also { uid = it }

    override suspend fun findProfile(friendCode: String): ProfileRow? = profiles[friendCode]

    override suspend fun generateUniqueCode(): String {
        repeat(8) {
            val code = FriendCode.generate()
            if (!profiles.containsKey(code)) return code
        }
        return FriendCode.generate()
    }

    override suspend fun upsertProfile(row: ProfileRow) {
        profiles[row.friendCode] = row
    }
}
