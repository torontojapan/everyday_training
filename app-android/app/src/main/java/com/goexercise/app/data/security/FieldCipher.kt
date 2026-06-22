package com.goexercise.app.data.security

import android.content.Context
import android.util.Base64
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * 文字列の保存時暗号化を表す最小インターフェース。本番は [FieldCipher]、JVM 単体テストでは
 * Android Keystore が無いため [IdentityStringCipher](素通し)を注入できるよう抽象化する。
 */
interface StringCipher {
    fun encrypt(plaintext: String): String
    /** 復号不能(改竄/鍵不一致/不正形式)なら null。 */
    fun decryptOrNull(encoded: String): String?
}

/** 暗号化しない素通し実装(テスト専用。本番では使わない)。 */
object IdentityStringCipher : StringCipher {
    override fun encrypt(plaintext: String): String = plaintext
    override fun decryptOrNull(encoded: String): String? = encoded
}

/**
 * 個別フィールド(文字列)を保存時暗号化する汎用ヘルパ(2026-06-22 セキュリティ強化)。
 *
 * 用途: 既存の共有 DataStore("settings")の値ひとつだけを暗号化したいケース。ストア全体を
 * 暗号化シリアライザで包むと他リポジトリ(設定・通知・rescue 等)へ波及するため、影響範囲を
 * 最小化する目的でフィールド単位の暗号化を採る。
 *
 * 鍵管理: AES-256 鍵を Keystore 連動の EncryptedSharedPreferences に Base64 で保管(初回生成)。
 * 鍵自体は MasterKey(Keystore)で暗号化されるため平文では残らない。
 *
 * 暗号: AES/GCM/NoPadding。出力は Base64(IV[12] ‖ ciphertext+tag)。
 */
class FieldCipher private constructor(private val key: ByteArray) : StringCipher {

    /** 平文文字列 → Base64(IV ‖ 暗号文)。 */
    override fun encrypt(plaintext: String): String {
        val iv = ByteArray(IV_BYTES).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, iv))
        }
        val ct = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return Base64.encodeToString(iv + ct, Base64.NO_WRAP)
    }

    /**
     * Base64(IV ‖ 暗号文) → 平文。復号できない(改竄・鍵不一致・不正形式)場合は null を返す。
     * 呼び出し側はデータ喪失を避けるため null を「該当データなし」として安全に扱う。
     */
    override fun decryptOrNull(encoded: String): String? = runCatching {
        val all = Base64.decode(encoded, Base64.NO_WRAP)
        if (all.size <= IV_BYTES) return null
        val iv = all.copyOfRange(0, IV_BYTES)
        val ct = all.copyOfRange(IV_BYTES, all.size)
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(TAG_BITS, iv))
        }
        String(cipher.doFinal(ct), Charsets.UTF_8)
    }.getOrNull()

    companion object {
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val IV_BYTES = 12
        private const val TAG_BITS = 128
        private const val KEY_BYTES = 32

        /**
         * 指定名の暗号化ストアから AES 鍵を読み(無ければ生成し)、FieldCipher を返す。
         * @param keyName 同一暗号化ストア内で鍵を区別する名前(用途ごとに別鍵にできる)。
         */
        fun create(context: Context, prefsFile: String, keyName: String): FieldCipher {
            val prefs = SecurePreferencesFactory.create(context, prefsFile)
            val existing = prefs.getString(keyName, null)
            val key = existing?.let { runCatching { Base64.decode(it, Base64.NO_WRAP) }.getOrNull() }
                ?.takeIf { it.size == KEY_BYTES }
                ?: ByteArray(KEY_BYTES).also { SecureRandom().nextBytes(it) }.also { fresh ->
                    prefs.edit().putString(keyName, Base64.encodeToString(fresh, Base64.NO_WRAP)).apply()
                }
            return FieldCipher(key)
        }
    }
}
