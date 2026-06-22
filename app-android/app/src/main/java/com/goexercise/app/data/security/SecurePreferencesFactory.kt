package com.goexercise.app.data.security

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Keystore 連動の EncryptedSharedPreferences を生成する共通ファクトリ(2026-06-22 セキュリティ強化)。
 *
 * androidx.security:security-crypto は公式にはメンテナンスモードだが現役・標準であり、Android Keystore に
 * バインドした AES-256-GCM の鍵で値を暗号化する。鍵素材は Keystore(可能なら StrongBox/TEE)に格納され、
 * 端末外へ抽出されない。ここで作る暗号化ストアは以下の機微データの「保存時暗号化」に再利用する:
 *   - DB パスフレーズ(SQLCipher 用ランダム 32 byte)
 *   - 生理データ(reproductive health)暗号化鍵
 *   - Supabase セッション(access / refresh JWT)
 *
 * 注意: EncryptedSharedPreferences は同一ファイルに対する MasterKey 設定の不一致や Keystore 破損で
 * 復号に失敗し得る。各呼び出し側は復号失敗を「鍵喪失」として握りつぶさず、安全側(再生成 or 再ログイン)に倒す。
 */
object SecurePreferencesFactory {

    /** Keystore に置く AES-256-GCM のマスター鍵。EncryptedSharedPreferences の鍵暗号化に使う。 */
    private fun masterKey(context: Context): MasterKey =
        MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()

    /**
     * 指定名の暗号化 SharedPreferences を返す。ファイルは files/shared_prefs 配下に作られるが、
     * 値(と鍵名)は暗号化済みで、平文では読めない。
     */
    fun create(context: Context, fileName: String): SharedPreferences =
        EncryptedSharedPreferences.create(
            context.applicationContext,
            fileName,
            masterKey(context),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
}
