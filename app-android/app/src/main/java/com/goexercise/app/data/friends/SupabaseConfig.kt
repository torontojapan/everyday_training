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
}
