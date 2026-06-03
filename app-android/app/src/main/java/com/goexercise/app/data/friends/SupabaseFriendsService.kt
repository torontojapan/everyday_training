package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.FriendCode
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.postgrest.from

/**
 * Supabase 実装(P1b-1 PoC スコープ)。iOS `SupabaseFriendsService` に対応。
 * このファイルがコンパイルできること = supabase-kt 3.x の auth/postgrest API 実在確認
 * (Codex が「PoC で確定」とした signInAnonymously / select / upsert / signInWith(IDToken) /
 * exchangeCodeForSession 等)。実通信は anon key 設定 + 実機で別途。
 */
class SupabaseFriendsService(private val client: SupabaseClient) : FriendsService {

    override val isMock: Boolean = false

    override suspend fun ensureSignedInUid(): String {
        client.auth.currentUserOrNull()?.id?.let { return it }
        client.auth.signInAnonymously()
        return client.auth.currentUserOrNull()?.id ?: error("匿名サインイン後に uid を取得できません")
    }

    override suspend fun findProfile(friendCode: String): ProfileRow? =
        client.from("profiles")
            .select {
                filter { eq("friend_code", friendCode) }
                limit(1)
            }
            .decodeList<ProfileRow>()
            .firstOrNull()

    override suspend fun generateUniqueCode(): String {
        repeat(8) {
            val code = FriendCode.generate()
            if (findProfile(code) == null) return code
        }
        return FriendCode.generate()
    }

    override suspend fun upsertProfile(row: ProfileRow) {
        client.from("profiles").upsert(row) { onConflict = "user_id" }
    }

    // ---- 連携 API 実在プローブ(P1b-2 で本実装。ここではコンパイル=API 実在の確認のみ) ----

    /** Google native: ID token サインイン(iOS Apple native の鏡像)。 */
    suspend fun signInWithGoogleIdToken(idTokenValue: String, rawNonce: String?) {
        client.auth.signInWith(IDToken) {
            idToken = idTokenValue
            provider = Google
            nonce = rawNonce
        }
    }

    /** Apple web: PKCE コールバックの auth code をセッションに交換。 */
    suspend fun exchangeCode(authCode: String) {
        client.auth.exchangeCodeForSession(authCode)
    }
}
