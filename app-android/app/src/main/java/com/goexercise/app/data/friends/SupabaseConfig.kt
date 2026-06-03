package com.goexercise.app.data.friends

import com.goexercise.app.BuildConfig

/**
 * Supabase 接続情報。値は local.properties(gitignore) → BuildConfig 経由で注入
 * (iOS の Secrets.xcconfig → Info.plist 相当)。空の間は isConfigured=false で friends は Mock。
 * iOS と**同一プロジェクト**を指すこと(friend code 名前空間共有 = Apple↔Android 相互フレンド)。
 */
object SupabaseConfig {
    val host: String get() = BuildConfig.SUPABASE_HOST.trim()
    val anonKey: String get() = BuildConfig.SUPABASE_ANON_KEY.trim()
    val url: String? get() = host.ifBlank { null }?.let { "https://$it" }
    val isConfigured: Boolean get() = url != null && anonKey.isNotBlank()

    // ---- アカウント連携(#5 / Phase2。config-gated)----
    // iOS SupabaseConfig.appleLinkEnabled / googleLinkEnabled / isAccountLinkingEnabled 相当。
    /** Apple 連携(web/PKCE)を有効にするか。既定 false。 */
    val appleLinkEnabled: Boolean get() = BuildConfig.FRIENDS_APPLE_LINK_ENABLED
    /** Google 連携(native id_token)を有効にするか。既定 false。 */
    val googleLinkEnabled: Boolean get() = BuildConfig.FRIENDS_GOOGLE_LINK_ENABLED
    /** いずれかの連携が有効か(バックアップ/復元/削除 UI の表示ゲート)。 */
    val isAccountLinkingEnabled: Boolean get() = appleLinkEnabled || googleLinkEnabled
    /** Google native(Credential Manager)用 Web Client ID。 */
    val googleWebClientId: String get() = BuildConfig.GOOGLE_WEB_CLIENT_ID.trim()

    /**
     * Apple web/PKCE OAuth のコールバック先。iOS と同じ `goexercise://auth-callback`。
     * **キー所有者作業(#10)**: Supabase の "Redirect URLs" 許可リストに登録する。Apple web の
     * callback は通常の deep link(§11 ルート)に流さず、ここで code を抽出して exchange する。
     */
    const val googleRedirectUrl: String = "goexercise://auth-callback"
}
