package com.goexercise.app.data.backup

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import java.time.Instant
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 記録クラウドバックアップの永続状態。iOS の `recordBackup.*` UserDefaults キー +
 * `RecordSyncTombstones`(削除伝播キュー)の移植。DataStore(Preferences)に保存する。
 *
 * - enabled: オプトイン(既定 OFF)。ON の間だけ同期・削除キューイングする。
 * - lastSyncAt: push 差分の watermark。**同期開始時刻**で打つ(終了時刻だと await 中の
 *   変更が永久に push されない。iOS Codex P1 と同じ理由)。
 * - pendingDeletions / pendingWipe: 各 Repository の削除時に積み、次回同期でサーバへ
 *   論理削除(wipe は物理全削除)を書く。送信は peek→成功後 clear(失敗時はキュー温存)。
 */
@Singleton
class RecordBackupStore @Inject constructor(
    private val dataStore: DataStore<Preferences>,
) {
    private val enabledKey = booleanPreferencesKey("record_backup_enabled")
    private val lastSyncKey = longPreferencesKey("record_backup_last_sync_epoch_ms")
    private val deletionsKey = stringSetPreferencesKey("record_backup_pending_deletions")
    private val wipeKey = booleanPreferencesKey("record_backup_pending_wipe")

    val enabled: Flow<Boolean> = dataStore.data.map { it[enabledKey] ?: false }
    val lastSyncAt: Flow<Instant?> = dataStore.data.map { prefs -> prefs[lastSyncKey]?.let(Instant::ofEpochMilli) }

    suspend fun isEnabled(): Boolean = enabled.first()

    suspend fun setEnabled(on: Boolean) {
        dataStore.edit { it[enabledKey] = on }
    }

    suspend fun stampSynced(at: Instant) {
        dataStore.edit { it[lastSyncKey] = at.toEpochMilli() }
    }

    /** 削除をキューイング(バックアップ OFF 中は積まない。iOS RecordSyncTombstones.note と同じガード)。 */
    suspend fun noteDeletion(recordId: String) {
        dataStore.edit { prefs ->
            if (prefs[enabledKey] != true) return@edit
            prefs[deletionsKey] = (prefs[deletionsKey] ?: emptySet()) + recordId
        }
    }

    /** 全削除(wipe)を予約。個別キューは不要になるので破棄(iOS noteWipe と同じ)。 */
    suspend fun noteWipe() {
        dataStore.edit { prefs ->
            if (prefs[enabledKey] != true) return@edit
            prefs[wipeKey] = true
            prefs.remove(deletionsKey)
        }
    }

    /** 送信前に読むだけ(消さない)。送信成功後に [clearPending] で消す(失敗時にキューを失わない)。 */
    suspend fun peekPending(): Pending {
        val prefs = dataStore.data.first()
        return Pending(ids = prefs[deletionsKey] ?: emptySet(), wipe = prefs[wipeKey] ?: false)
    }

    /** 送信に成功した分だけ消す(送信中に note された新規 id は残す)。 */
    suspend fun clearPending(ids: Set<String>, wipe: Boolean) {
        dataStore.edit { prefs ->
            if (wipe) prefs.remove(wipeKey)
            if (ids.isNotEmpty()) {
                val remaining = (prefs[deletionsKey] ?: emptySet()) - ids
                if (remaining.isEmpty()) prefs.remove(deletionsKey) else prefs[deletionsKey] = remaining
            }
        }
    }

    /**
     * アカウント切替/復元時のリセット。前アカウント宛の削除キュー/wipe/同期時刻を破棄し、
     * A の「すべて削除」が B のバックアップを消す等の口座跨ぎ事故を防ぐ(iOS Codex P1)。
     * lastSync も破棄するので、次回同期は全量 push(冪等 upsert)で安全側。
     */
    suspend fun resetForIdentityChange() {
        dataStore.edit { prefs ->
            prefs.remove(deletionsKey)
            prefs.remove(wipeKey)
            prefs.remove(lastSyncKey)
        }
    }

    data class Pending(val ids: Set<String>, val wipe: Boolean)
}
