package com.goexercise.app.data.friends

/**
 * anti-resurrection: `signOut` / `deleteAccount` の**手順と fail-closed 判断**を Supabase 副作用から
 * 分離し、ネットワーク経路を単体テスト可能にする。実際の削除 / サインアウト / Edge Function 呼び出しは
 * suspend ラムダで注入する(本番 = [SupabaseFriendsService]、テスト = fake ラムダ + 呼び出し記録)。
 * status → 次アクションの判断中核は [DeleteAccountDecision]。iOS の fail-closed 設計と対称。
 */
internal object AccountDeletionFlow {

    /** signOut 判断に必要な最小セッション情報。 */
    data class SessionUser(val isAnonymous: Boolean)

    /**
     * signOut: **匿名のときだけ**本人データを削除してから signOut(連携済み=バックアップは保持し別端末で復旧可)。
     * 削除は best-effort([deleteOwnedData] が失敗しても [signOut] へ必ず到達)。
     * `user == null`(未サインイン)や連携済みでは [deleteOwnedData] を呼ばない。
     */
    suspend fun signOut(
        user: SessionUser?,
        deleteOwnedData: suspend () -> Unit,
        signOut: suspend () -> Unit,
    ) {
        if (user?.isAnonymous == true) {
            runCatching { deleteOwnedData() } // 一部失敗でも signOut へ到達(best-effort)
        }
        signOut()
    }

    /**
     * deleteAccount: Edge Function を呼び status を [DeleteAccountDecision] で判断。
     * - Success(2xx): [signOutLocal] のみ(EF が auth cascade 削除 + 全 token 失効済)。クライアント削除はしない。
     * - Fallback(404 未デプロイ / -1 ネット断): [deleteOwnedData](RLS で本人データ削除)→ [signOutGlobal]。
     *   [deleteOwnedData] の失敗は **伝播**(signOutGlobal に進まず例外 → 再試行 = 復活防止)。
     * - FailClosed(401/405/500 等): [failClosed] を投げる(success 誤報告で auth 行 / refresh token が
     *   生き残り「復活」するのを防ぐ)。**削除もサインアウトもしない**。
     *
     * 注: [invokeEdgeFunction] 自身が例外を投げた場合(EF 到達後の失敗を呼び出し側が fail-closed として
     * 変換する場合)も、そのまま伝播して success 誤報告を防ぐ。
     */
    suspend fun deleteAccount(
        invokeEdgeFunction: suspend () -> Int,
        signOutLocal: suspend () -> Unit,
        deleteOwnedData: suspend () -> Unit,
        signOutGlobal: suspend () -> Unit,
        failClosed: () -> Throwable,
    ) {
        when (DeleteAccountDecision.fromStatus(invokeEdgeFunction())) {
            DeleteAccountDecision.Success -> { runCatching { signOutLocal() }; return }
            DeleteAccountDecision.Fallback -> Unit
            DeleteAccountDecision.FailClosed -> throw failClosed()
        }
        deleteOwnedData()               // 失敗は伝播 → 再試行(anti-resurrection)
        runCatching { signOutGlobal() } // token 失効は EF の役目 = best-effort
    }
}
