package com.goexercise.app.data.security

import android.content.Context
import android.util.Log
import net.zetetic.database.sqlcipher.SQLiteDatabase
import java.io.File

/**
 * 旧来の **平文** goexercise.db を SQLCipher 暗号化 DB へ一度だけ移行する(2026-06-22 セキュリティ強化)。
 *
 * 背景: Android は未リリースだが、dev/beta インストールには平文の goexercise.db が既に存在し得る。
 * SQLCipher はパスフレーズ付きで平文 DB を開けないため、Room を SupportOpenHelperFactory で開く **前に**
 * ここで変換する。
 *
 * 検出条件: DB ファイルが存在し、かつパスフレーズが未保存(= この暗号化対応より前に作られた平文 DB)。
 *
 * 変換手順(SQLCipher 標準の sqlcipher_export パターン):
 *   1. 平文 DB を key 無し("")で開く。
 *   2. ATTACH した一時ファイルへ新パスフレーズで暗号化エクスポート(sqlcipher_export)。
 *   3. user_version を引き継ぎ(Room の migration 連続性のため)、暗号化ファイルで元ファイルを置換。
 *
 * 安全策(データ損失の回避):
 *   - 変換成功まで元の平文ファイルは消さない。途中失敗時は一時ファイルだけ削除し、平文のまま残す
 *     → 次回起動で再試行できる(冪等)。さらに保存したパスフレーズも巻き戻す(次回 hasPassphrase()=false)。
 *   - 変換ロジックが万一例外を投げても呼び出し側(DatabaseModule)で握り、起動はクラッシュさせない。
 *
 * ライブラリ: net.zetetic:sqlcipher-android。クラスは net.zetetic.database.sqlcipher.* パッケージ
 * (旧 android-database-sqlcipher の net.sqlcipher.* とは別)。ネイティブは System.loadLibrary("sqlcipher")。
 */
object PlaintextDbMigrator {

    private const val TAG = "PlaintextDbMigrator"

    /**
     * 移行結果。呼び出し側(DatabaseModule)が「SQLCipher で開いて良いか」を判断するために使う。
     *  - ENCRYPTED_READY: 暗号化済み or DB 不在 or 移行成功 → SupportOpenHelperFactory(passphrase) で開いてよい。
     *  - PLAINTEXT_FALLBACK: 平文 DB が残存し移行に失敗 → SQLCipher で開くと "file is not a database" で
     *    起動不能ループになるため、今回は **平文のまま** 開いてデータと起動を守り、次回起動で再移行する。
     */
    enum class Result { ENCRYPTED_READY, PLAINTEXT_FALLBACK }

    @Volatile
    private var nativeLoaded = false

    /** SQLCipher ネイティブを 1 度だけロード(SupportOpenHelperFactory 利用前にも必須)。 */
    @Synchronized
    fun ensureNativeLoaded() {
        if (nativeLoaded) return
        System.loadLibrary("sqlcipher")
        nativeLoaded = true
    }

    /**
     * 必要なら平文→暗号化の移行を実施する。
     *
     * @return [Result.ENCRYPTED_READY] = SQLCipher で開いてよい(既に暗号化 / DB 無し / 移行成功)。
     *         [Result.PLAINTEXT_FALLBACK] = 平文が残り移行失敗 → 今回は平文で開く(次回再移行)。
     */
    fun migrateIfNeeded(
        context: Context,
        databaseName: String,
        passphraseProvider: DatabasePassphraseProvider,
    ): Result {
        ensureNativeLoaded()

        val dbFile = context.getDatabasePath(databaseName)
        val backup = File(dbFile.parentFile, "$databaseName.migrate-bak")

        // ★クラッシュ回復: .migrate-bak が残存 = 前回の移行が「原本退避後・置換完了前」に中断した痕跡。
        //   この時点では原本(平文)は backup にしか無いため、**まず backup を原本へ復元**し、暗号化が
        //   未完了だったものとしてパスフレーズも巻き戻してから通常フロー(再移行)に落とす。これをしないと
        //   下の hasPassphrase()=true で早期 return し、空の暗号化 DB を作って backup 内の唯一のデータを
        //   孤児化してしまう(GPT-5.5 監査)。backup は正常成功時には必ず削除されるので、存在 = 中断の証跡。
        if (backup.exists()) {
            // ★順序が重要: passphrase を **先に durable に消せたときだけ** 復元へ進む。復元(rename)後に消す
            // 順や、clear が耐久失敗したまま平文を置くと「平文 dbFile + 永続 passphrase」になり、次回
            // SQLCipher が平文を開いて起動不能になる(GPT-5.5 監査)。clear が耐久失敗(commit=false: 通常は
            // ディスク満杯/Keystore 異常の劣化端末のみ)なら復元を見送り、backup と現状をそのまま残して
            // 次回の健全な起動で再回復させる(データは backup に保持=喪失しない)。
            if (passphraseProvider.clearPassphrase()) {
                runCatching { if (dbFile.exists()) dbFile.delete() }
                deleteSidecars(dbFile)
                // 復元も **atomic rename 限定**(同一 FS)。途中状態(部分ファイル)が生じない。
                // 万一 rename が false なら backup を残し次回再試行に委ねる(データは backup に保持)。
                if (backup.renameTo(dbFile)) {
                    Log.w(TAG, "Recovered plaintext DB from interrupted migration backup; will re-migrate.")
                } else {
                    Log.e(TAG, "Recovery rename failed; leaving backup intact for next-launch retry.")
                }
            } else {
                Log.e(TAG, "Could not durably clear passphrase; deferring recovery (data preserved in backup).")
            }
        }

        // パスフレーズが既にある = 過去に暗号化 DB を作成済み(または初回でこれから作る)。
        // この場合、既存ファイルは暗号化済みとみなして触らない。
        if (passphraseProvider.hasPassphrase()) return Result.ENCRYPTED_READY
        // DB ファイルが無ければ移行対象なし(初回起動)。パスフレーズはこの後の Room オープン時に生成される。
        if (!dbFile.exists()) return Result.ENCRYPTED_READY

        // ここに到達 = 平文 DB が存在し、暗号化はまだ。一度だけ変換する。
        // passphrase は **まだ永続化しない**(移行の最終検証成功後に persistPassphrase で確定)。
        // 早期保存は移行未完了クラッシュで hasPassphrase()=true → 平文を SQLCipher で開く起動不能ループを招く。
        val passphrase = passphraseProvider.newEphemeralPassphrase()
        val encryptedTmp = File(dbFile.parentFile, "$databaseName.enc-tmp")
        if (encryptedTmp.exists()) encryptedTmp.delete()

        return try {
            // 平文 DB を key 無しで開く(空文字 = 暗号化なし)。
            val plaintext = SQLiteDatabase.openOrCreateDatabase(dbFile.absolutePath, "", null, null)
            val originalVersion = plaintext.version
            try {
                val keyLiteral = passphrase.toHexLiteral()
                plaintext.rawExecSQL(
                    "ATTACH DATABASE '${encryptedTmp.absolutePath.sqlEscape()}' AS encrypted KEY \"x'$keyLiteral'\";",
                )
                plaintext.rawExecSQL("SELECT sqlcipher_export('encrypted');")
                // user_version を引き継ぐ(Room の identity / migration 連続性を保つ)。
                plaintext.rawExecSQL("PRAGMA encrypted.user_version = $originalVersion;")
                plaintext.rawExecSQL("DETACH DATABASE encrypted;")
            } finally {
                plaintext.close()
            }

            // 暗号化ファイルが妥当に開けることを確認してから置換(壊れた書き出しで原本を失わない)。
            verifyEncrypted(encryptedTmp, passphrase)

            // ★原本を .bak へ退避(同一ディレクトリ内の **atomic rename 限定**)。copyTo フォールバックは
            // 使わない: 部分コピー中にクラッシュすると「不完全な backup + 無傷の原本」が残り、次回起動の
            // 回復が無傷の原本を消して不完全 backup を復元 = データ損失になる(GPT-5.5 監査)。同一 FS の
            // rename は atomic なので backup は常に完全。万一 rename が失敗したら原本に一切触れず移行を
            // 中止する(throw → 平文フォールバックで起動継続、原本は無傷のまま次回再試行)。
            // (backup は関数冒頭で定義済。冒頭のクラッシュ回復で残骸は処理済のため、ここでは存在しない想定。)
            if (backup.exists()) backup.delete()
            if (!dbFile.renameTo(backup)) {
                throw IllegalStateException("could not move plaintext DB to backup (rename failed); aborting migration")
            }
            // 原本の sidecars(-wal/-shm/-journal)は新しい暗号化 DB と無関係なので削除
            // (plaintext.close() で WAL は checkpoint 済 = backup 単体で復元に十分)。
            deleteSidecars(dbFile)
            try {
                // 暗号化ファイルの配置も **atomic rename 限定**(部分ファイルを作らない)。
                if (!encryptedTmp.renameTo(dbFile)) {
                    throw IllegalStateException("could not place encrypted DB (rename failed)")
                }
                // 配置後の最終ファイルが暗号化キーで開けることを最終確認。
                verifyEncrypted(dbFile, passphrase)
            } catch (place: Throwable) {
                // 配置/検証に失敗 → backup(完全)から原本(平文)を atomic rename で復元し、例外を再送出
                // (→ 平文フォールバックで起動継続)。rename が false なら backup を残し次回回復に委ねる。
                runCatching { if (dbFile.exists()) dbFile.delete() }
                runCatching { encryptedTmp.delete() }
                backup.renameTo(dbFile)
                throw place
            }
            // 配置+最終検証まで成功して初めて passphrase を **耐久(commit)** 保存する。
            // ★順序が重要: 耐久保存が成功してから backup を消す。commit が false(永続化失敗)の場合、
            // encrypted dbFile は passphrase 無しで二度と開けないため、backup(平文)を atomic 復元して
            // 平文フォールバックする(暗号化はあきらめてデータと起動を守る。次回再移行)。
            if (!passphraseProvider.persistPassphrase(passphrase)) {
                // 念のため pref を確実に消してから平文を復元(commit false でも値が見えると平文を暗号扱いし得る)。
                runCatching { passphraseProvider.clearPassphrase() }
                runCatching { if (dbFile.exists()) dbFile.delete() }
                backup.renameTo(dbFile) // 平文を復元
                Log.e(TAG, "Failed to durably persist passphrase; restored plaintext, will retry next launch.")
                return Result.PLAINTEXT_FALLBACK
            }
            backup.delete() // passphrase 耐久保存に成功 → backup 破棄。
            Log.i(TAG, "Migrated plaintext '$databaseName' to encrypted (version=$originalVersion).")
            Result.ENCRYPTED_READY
        } catch (t: Throwable) {
            // 変換失敗: 一時ファイルを掃除し、保存済みパスフレーズも巻き戻す(次回 hasPassphrase()=false で再試行)。
            // 平文の原本は残し、呼び出し側は今回 **平文のまま** 開く(SQLCipher で開くと起動不能ループになる)。
            runCatching { encryptedTmp.delete() }
            runCatching { passphraseProvider.clearPassphrase() }
            Log.e(TAG, "Failed to migrate plaintext DB; opening plaintext this launch, will retry next launch.", t)
            Result.PLAINTEXT_FALLBACK
        }
    }

    /** 暗号化ファイルが正しいパスフレーズで開けることを確認(失敗すれば例外)。 */
    private fun verifyEncrypted(file: File, passphrase: ByteArray) {
        val db = SQLiteDatabase.openOrCreateDatabase(file.absolutePath, passphrase, null, null)
        try {
            db.rawExecSQL("SELECT count(*) FROM sqlite_master;")
        } finally {
            db.close()
        }
    }

    /** メイン DB ファイルは残し、SQLite の同伴ファイル(-wal/-shm/-journal)のみ削除する。 */
    private fun deleteSidecars(dbFile: File) {
        File(dbFile.parentFile, "${dbFile.name}-wal").delete()
        File(dbFile.parentFile, "${dbFile.name}-shm").delete()
        File(dbFile.parentFile, "${dbFile.name}-journal").delete()
    }

    /** ByteArray を SQLCipher の `x'..'` リテラル用 16 進文字列へ。 */
    private fun ByteArray.toHexLiteral(): String =
        joinToString("") { "%02x".format(it) }

    /** ATTACH パス中のシングルクオートをエスケープ。 */
    private fun String.sqlEscape(): String = replace("'", "''")
}
