package com.goexercise.app.data.friends

/**
 * アカウント連携(機種変/再インストール復旧)の型。iOS `AccountLinking.swift` の移植。
 * 匿名 uid を保持したまま Apple/Google identity を連結し、復旧可能にする。連携は任意で、
 * 匿名のままでも全機能使える。**Android は iOS の鏡像**(plan §6): Google=native id_token /
 * Apple=web/PKCE(iOS は逆)。
 */
enum class FriendsLinkProvider(val displayName: String) {
    Apple("Apple"),
    Google("Google"),
}

/** アカウント連携の結果/エラー。iOS `AccountLinkError` 移植。 */
sealed class AccountLinkError(message: String) : Exception(message) {
    /** その Apple/Google ID が既に別アカウントに紐付く(identity_already_exists)。マージせず切替/中止の二択。 */
    data object AlreadyLinkedToAnotherAccount : AccountLinkError("このアカウントは既に別のデータに紐づいています。")
    /** サーバ側でそのプロバイダが未設定/無効(provider_disabled 等)。 */
    data object ProviderUnavailable : AccountLinkError("ただいまこの方法は利用できません。")
    /** ユーザーがキャンセルした。 */
    data object Cancelled : AccountLinkError("キャンセルされました。")
    /** バックエンド未接続。 */
    data object BackendUnavailable : AccountLinkError("友達機能につながれませんでした。")
    /** その他(やさしい固定文で表示し、生エラーは出さない)。 */
    data object Failed : AccountLinkError("バックアップに失敗しました。通信状況を確認してお試しください。")
}

/** 復元(restore)の成否内訳。iOS `RestoreOutcome` 移植。 */
enum class RestoreOutcome {
    /** 既存プロフィールが見つかりロードした(友達/コードが戻る)。 */
    Restored,
    /** 既存データ無し → 新規アカウントとして作成した(実質サインアップ)。 */
    Created,
}

/**
 * Apple web/PKCE の認可フロー。認可 URL を開き(Android は Custom Tabs)、`goexercise://auth-callback`
 * のコールバック URL を返す。View/coordinator が渡し、Service(Supabase)が前後で URL 生成と code 交換を行う。
 * iOS `WebAuthFlow`(typealias)の移植。Google は native id_token なので不要(経路が違う)。
 */
typealias WebAuthFlow = suspend (authUrl: String) -> String

/** 連携状態(UI 表示用)。iOS `AccountBackupStatus` 移植。 */
data class AccountBackupStatus(
    /** 永続アカウントに連携済み(= 匿名でない)。 */
    val isBackedUp: Boolean,
    /** 連携済みプロバイダ名(表示用、任意)。 */
    val providerName: String? = null,
) {
    companion object {
        val Anonymous = AccountBackupStatus(isBackedUp = false, providerName = null)
    }
}
