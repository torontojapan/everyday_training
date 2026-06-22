package com.goexercise.app.data.security

import android.content.Context
import io.github.jan.supabase.auth.SessionManager
import io.github.jan.supabase.auth.user.UserSession
import kotlinx.serialization.json.Json

/**
 * Supabase の access / refresh JWT を **暗号化** SharedPreferences に保存する SessionManager
 * (2026-06-22 セキュリティ強化)。
 *
 * supabase-kt 3.6.0 既定の SettingsSessionManager は平文 SharedPreferences に UserSession の JSON を
 * 置く。ここでは同じ JSON を Keystore 連動の EncryptedSharedPreferences(AES-256-GCM)に保存し、
 * 保存時暗号化を満たす。
 *
 * 実装した supabase-kt 3.6.0 SessionManager インターフェース(auth-kt.aar を javap で確認):
 *   - suspend fun saveSession(session: UserSession)
 *   - suspend fun loadSession(): UserSession        // ★非null。SDK 純正 SettingsSessionManager は
 *                                                   //   未保存時 IllegalStateException を投げ、呼び出し元
 *                                                   //   (AuthImpl が loadSession を直接呼ぶ)が捕捉する契約。
 *                                                   //   ここも同じく未保存/復号失敗時は throw する。
 *   - suspend fun deleteSession()
 *   （loadSessionOrNull は default 実装があり SDK は loadSession を直接呼ぶため override 不要）
 *
 * UserSession は @Serializable なので UserSession.serializer() で JSON 化する。
 */
class EncryptedSessionManager(
    context: Context,
    private val json: Json = Json { ignoreUnknownKeys = true },
) : SessionManager {

    private val prefs = SecurePreferencesFactory.create(context, PREFS_FILE)

    override suspend fun saveSession(session: UserSession) {
        val encoded = json.encodeToString(UserSession.serializer(), session)
        prefs.edit().putString(KEY_SESSION, encoded).apply()
    }

    override suspend fun loadSession(): UserSession {
        // SettingsSessionManager と同契約: 未保存時は IllegalStateException を投げる(SDK 側で捕捉)。
        val raw = prefs.getString(KEY_SESSION, null)
            ?: error("No Supabase session stored")
        return json.decodeFromString(UserSession.serializer(), raw)
    }

    override suspend fun deleteSession() {
        prefs.edit().remove(KEY_SESSION).apply()
    }

    companion object {
        private const val PREFS_FILE = "secure_supabase_session"
        private const val KEY_SESSION = "user_session_json"
    }
}
