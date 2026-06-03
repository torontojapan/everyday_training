package com.goexercise.app.presentation.friends

import android.content.Context
import com.goexercise.app.data.friends.WebAuthFlow

/**
 * 連携の認証取得を抽象化する(plan §6)。**Android は iOS の鏡像**:
 * - Google = **native id_token**(Credential Manager)→ [requestGoogleIdToken]
 * - Apple = **web/PKCE**(Custom Tabs)→ [appleWebFlow]
 *
 * iOS では View が `AppleSignInCoordinator` / `GoogleSignInCoordinator` を Service へ渡す。
 * Android も画面側がこの coordinator から id_token / WebAuthFlow を取り出して VM へ渡す。
 *
 * dev/screenshot は [MockAccountAuthCoordinator]。**実 Credential Manager / Custom Tabs 実装は #10**
 * (Web Client ID + Supabase の redirect 許可リスト + Edge Function + 実機 E2E に依存。plan §13 で
 * P1b-2 は「並列消化できない独立フェーズ」とされ、Supabase コンソール設定と束ねる)。
 */
interface AccountAuthCoordinator {
    /** Google native id_token を取得。ユーザーキャンセルは [com.goexercise.app.data.friends.AccountLinkError.Cancelled]。 */
    suspend fun requestGoogleIdToken(context: Context): String

    /** Apple web/PKCE の認可フロー(認可 URL を Custom Tabs で開き callback URL を返す)。 */
    fun appleWebFlow(context: Context): WebAuthFlow
}

/**
 * dev/screenshot 用の偽 coordinator。実通信なしで連携 UI/VM フローを通す。
 * Google は固定の偽 id_token、Apple web flow は成功 callback を即返す。
 * [MockFriendsService] 側が token/callback を解釈して backup 済みに遷移する。
 */
class MockAccountAuthCoordinator : AccountAuthCoordinator {
    override suspend fun requestGoogleIdToken(context: Context): String = "mock-google-id-token"

    override fun appleWebFlow(context: Context): WebAuthFlow =
        { _: String -> "goexercise://auth-callback?code=mock-auth-code" }
}
