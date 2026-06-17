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
    /**
     * 連携済みプロバイダ名の一覧(例: ["apple", "google"])。表示用。
     * **複数連携時に1つだけ拾うと並び順依存で誤表示になる**(Apple なのに Google 等)ため、
     * 全プロバイダを保持して表示側で結合する(iOS 1.3 パリティ)。
     */
    val providerNames: List<String> = emptyList(),
) {
    /** 後方互換アクセサ: 単一プロバイダ前提だった旧コード/テスト用(先頭を返す)。 */
    val providerName: String? get() = providerNames.firstOrNull()

    /** 単一プロバイダ指定の後方互換コンストラクタ。 */
    constructor(isBackedUp: Boolean, providerName: String?) :
        this(isBackedUp, providerName?.let { listOf(it) } ?: emptyList())

    /**
     * 設定「アカウントとバックアップ」の状態文言。連携済みプロバイダを **全部** 列挙する
     * (Apple/Google 両方連携なら「Apple・Google アカウントでバックアップ中」)。
     * 1つだけ拾うと並び順依存で誤表示(Apple なのに Google 等)になるため。
     */
    val backupStatusText: String
        get() {
            val names = providerNames.map { providerDisplayName(it) }
            return if (names.isEmpty()) "アカウントでバックアップ中"
            else "${names.joinToString("・")} アカウントでバックアップ中"
        }

    /** 連携済みプロバイダの表示名を「・」で結合(未連携は null)。設定の「✓ X で連携済み」用。 */
    val linkedProvidersDisplay: String?
        get() = providerNames.takeIf { it.isNotEmpty() }?.joinToString("・") { providerDisplayName(it) }

    companion object {
        val Anonymous = AccountBackupStatus(isBackedUp = false, providerNames = emptyList())

        fun providerDisplayName(provider: String): String = when (provider) {
            "apple" -> "Apple"
            "google" -> "Google"
            else -> provider.replaceFirstChar { it.uppercase() }
        }
    }
}
