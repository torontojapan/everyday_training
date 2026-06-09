package com.goexercise.app.presentation.friends

import android.content.Context
import androidx.browser.customtabs.CustomTabsIntent
import androidx.core.net.toUri
import androidx.credentials.CredentialManager
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.exceptions.GetCredentialCancellationException
import com.goexercise.app.BuildConfig
import com.goexercise.app.data.friends.AccountLinkError
import com.goexercise.app.data.friends.WebAuthFlow
import com.google.android.libraries.identity.googleid.GetGoogleIdOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import kotlinx.coroutines.CompletableDeferred

/**
 * 実 [AccountAuthCoordinator](#10)。**Android は鏡像**:
 * - Google = native id_token → **Credential Manager**(Web Client ID = BuildConfig.GOOGLE_WEB_CLIENT_ID)
 * - Apple = web/PKCE → **Custom Tabs**(認可 URL を開き `goexercise://auth-callback` を待つ)
 *
 * **コンパイル = Credential Manager / googleid / Custom Tabs API 実在確認**。実フローには
 * ①Google Web Client ID ②Supabase の provider/redirect 設定 が必要(#10 キー所有者作業)。
 * Apple web callback は [MainActivity] が host=auth-callback を検出して [deliverCallback] する。
 */
class RealAccountAuthCoordinator : AccountAuthCoordinator {

    override suspend fun requestGoogleIdToken(context: Context): String {
        val webClientId = BuildConfig.GOOGLE_WEB_CLIENT_ID.trim()
        if (webClientId.isBlank()) throw AccountLinkError.ProviderUnavailable
        val option = GetGoogleIdOption.Builder()
            .setServerClientId(webClientId)
            .setFilterByAuthorizedAccounts(false)
            .setAutoSelectEnabled(false)
            .build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        try {
            val response = CredentialManager.create(context).getCredential(context, request)
            val cred = response.credential
            if (cred is CustomCredential && cred.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                return GoogleIdTokenCredential.createFrom(cred.data).idToken
            }
            throw AccountLinkError.Failed
        } catch (e: GetCredentialCancellationException) {
            throw AccountLinkError.Cancelled
        }
    }

    override fun appleWebFlow(context: Context): WebAuthFlow = { authUrl ->
        // 認可 URL を Custom Tabs で開き、redirect(goexercise://auth-callback)の URL を待つ。
        val deferred = CompletableDeferred<String>()
        synchronized(lock) {
            // 旧フローが残っていればキャンセル扱いで畳む(leak / 二重待ち回避)。
            pendingCallback?.completeExceptionally(AccountLinkError.Cancelled)
            pendingCallback = deferred
        }
        try {
            CustomTabsIntent.Builder().build().launchUrl(context, authUrl.toUri())
            deferred.await() // callback 配達 or キャンセルまで待機
        } finally {
            // コルーチン完了/キャンセル時、自分が現役なら掃除して static 参照を残さない。
            synchronized(lock) { if (pendingCallback === deferred) pendingCallback = null }
        }
    }

    companion object {
        private val lock = Any()

        /** 進行中の Apple web フロー。MainActivity が callback URL で完了する(同時 1 フロー想定)。 */
        @Volatile
        private var pendingCallback: CompletableDeferred<String>? = null

        /** auth-callback の deep link を受けたら呼ぶ(MainActivity から)。 */
        fun deliverCallback(url: String) {
            synchronized(lock) {
                pendingCallback?.complete(url)
                pendingCallback = null
            }
        }

        /**
         * 進行中フローが callback 未配達のまま画面復帰した = ユーザーが Custom Tab を閉じた、とみなして
         * キャンセル扱いで畳む(MainActivity.onResume から呼ぶ)。redirect で配達済みなら no-op。
         */
        fun cancelPendingIfUnfinished() {
            synchronized(lock) {
                pendingCallback?.completeExceptionally(AccountLinkError.Cancelled)
                pendingCallback = null
            }
        }
    }
}
