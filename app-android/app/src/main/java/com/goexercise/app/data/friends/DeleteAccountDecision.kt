package com.goexercise.app.data.friends

/**
 * アカウント削除の Edge Function 応答ステータス → 次アクションの決定(純粋関数・anti-resurrection 中核)。
 * iOS の deleteAccount fail-closed 設計と対称。
 *
 * - Success(2xx): EF が auth ごと cascade 削除 + 全セッション失効に成功 → ローカル signOut で完了。
 * - Fallback(404=未デプロイ / -1=ネット断・不確定): クライアント RLS で本人データを削除する第2段へ。
 * - FailClosed(401/405/500 等、EF に到達した上での失敗): **success と誤報告しない**。auth 行/refresh
 *   token が生き残ると「復活(resurrection)」するため、例外を投げて再試行させる。
 */
enum class DeleteAccountDecision {
    Success, Fallback, FailClosed;

    companion object {
        /** status: HTTP ステータス。-1=ネット断/不確定(呼び出し側が割り当てる)。 */
        fun fromStatus(status: Int): DeleteAccountDecision = when {
            status in 200..299 -> Success
            status == 404 || status == -1 -> Fallback
            else -> FailClosed
        }
    }
}
