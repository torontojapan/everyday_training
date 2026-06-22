package com.goexercise.app.data.security

import android.content.Context
import android.util.Base64
import java.security.SecureRandom

/**
 * SQLCipher 用の DB パスフレーズを管理する(2026-06-22 セキュリティ強化)。
 *
 * 初回起動でランダム 32 byte(256 bit)を生成し、Keystore 連動の EncryptedSharedPreferences に
 * Base64 で 1 度だけ保存する。以後の起動では同じ値を読み出して再利用する。
 * パスフレーズ自体が Keystore で暗号化されるため、平文では端末上に残らない。
 *
 * 返すのは生の ByteArray(SQLCipher SupportFactory が ByteArray を受け取り、使用後に内部でゼロ化する)。
 */
class DatabasePassphraseProvider(context: Context) {

    private val prefs = SecurePreferencesFactory.create(context, PREFS_FILE)

    /**
     * パスフレーズ(32 byte)を返す。未生成なら安全乱数で生成して保存する。
     * SupportFactory に渡すと内部で zeroize されるため、呼び出しごとに新しい配列を返す。
     */
    @Synchronized
    fun getOrCreatePassphrase(): ByteArray {
        val existing = prefs.getString(KEY_PASSPHRASE, null)
        if (existing != null) {
            val decoded = runCatching { Base64.decode(existing, Base64.NO_WRAP) }.getOrNull()
            if (decoded != null && decoded.size == PASSPHRASE_BYTES) return decoded
            // 破損・サイズ不正は新規生成へフォールバック(下で再生成)。既存暗号化 DB は復号不能になるが、
            // ここに来るのは Keystore/ストア破損の異常時のみ(平常運用では発生しない)。
        }
        val fresh = ByteArray(PASSPHRASE_BYTES).also { SecureRandom().nextBytes(it) }
        // commit()(同期・耐久書き込み)。apply() は非同期で、書き込み前のクラッシュと DB 作成が
        // 競合すると passphrase を失った暗号化 DB が残り得る。
        // ★耐久書き込みに失敗したら passphrase を返さず throw する。返してしまうと、その鍵で暗号化 DB を
        //   作った直後に次回起動で鍵を失い、その間のデータが復元不能になる(データ喪失 > 一過性クラッシュ。
        //   commit 失敗はディスク満杯/Keystore 異常の劣化端末のみで、健全端末では起きない。GPT-5.5 監査)。
        check(
            prefs.edit()
                .putString(KEY_PASSPHRASE, Base64.encodeToString(fresh, Base64.NO_WRAP))
                .commit(),
        ) { "could not durably persist DB passphrase" }
        return fresh
    }

    /**
     * **永続化せず**に新しいランダム 32 byte を生成して返す(移行用)。
     * 平文→暗号化の移行では、暗号化 DB の配置+検証が成功するまで passphrase を保存しない。
     * 早期に保存すると、移行完了前のクラッシュで hasPassphrase()=true になり、次回起動が平文 DB を
     * SQLCipher で開こうとして起動不能ループになる(GPT-5.5 監査)。成功後に [persistPassphrase] で確定する。
     */
    fun newEphemeralPassphrase(): ByteArray =
        ByteArray(PASSPHRASE_BYTES).also { SecureRandom().nextBytes(it) }

    /**
     * 指定の passphrase を暗号化ストアへ確定保存する(移行の最終検証成功後に呼ぶ)。
     * **commit()(同期・耐久)** を使い、戻り値で耐久書き込みの成否を返す。呼び出し側はこれが true に
     * なってから backup を消すこと(false や非同期 flush 前のクラッシュで passphrase を失った暗号化 DB が
     * 残るのを防ぐ。GPT-5.5 監査)。
     */
    @Synchronized
    fun persistPassphrase(passphrase: ByteArray): Boolean =
        prefs.edit()
            .putString(KEY_PASSPHRASE, Base64.encodeToString(passphrase, Base64.NO_WRAP))
            .commit()

    /** パスフレーズが既に保存済みか(= 暗号化 DB を一度でも開いたことがあるか)の判定に使う。 */
    fun hasPassphrase(): Boolean = prefs.getString(KEY_PASSPHRASE, null) != null

    /**
     * 保存済みパスフレーズを破棄する。平文→暗号化の移行に失敗して原本(平文)を残したときに、
     * 次回起動で再び移行を試みられるよう状態を巻き戻すために使う。
     */
    @Synchronized
    fun clearPassphrase(): Boolean =
        prefs.edit().remove(KEY_PASSPHRASE).commit() // 同期・耐久。戻り値で巻き戻しの耐久成否を返す。

    companion object {
        private const val PREFS_FILE = "secure_db_keys"
        private const val KEY_PASSPHRASE = "sqlcipher_passphrase_b64"
        private const val PASSPHRASE_BYTES = 32
    }
}
