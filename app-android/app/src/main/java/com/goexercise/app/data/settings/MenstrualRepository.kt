package com.goexercise.app.data.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.goexercise.app.data.backup.RecordBackupStore
import com.goexercise.app.data.security.FieldCipher
import com.goexercise.app.data.security.StringCipher
import dagger.Binds
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 生理日1件。iOS SwiftData `MenstrualEntry` 相当(クラウドバックアップの record_id に
 * UUID が必要なため、日付の Set から id 付きエントリへ拡張した)。
 * createdAt は同期の push 差分判定に使う(iOS は createdAt > lastSync で push)。
 */
@Serializable
data class MenstrualEntryRecord(
    val id: String,
    val epochDay: Long,
    val createdAtEpochMs: Long,
) {
    val date: LocalDate get() = LocalDate.ofEpochDay(epochDay)
}

/** 月経日マーキングの永続化(premium 周期オーバーレイ用)。iOS `MenstrualStore` 相当。 */
interface MenstrualRepository {
    val periodDays: Flow<Set<LocalDate>>
    suspend fun toggle(date: LocalDate)
    /** 全削除(データ全削除導線)。 */
    suspend fun clearAll()

    // ---- クラウドバックアップ同期用(RecordSyncCoordinator 専用。tombstone を積まない)----
    /** 全エントリ(id 付き)。push のエンコード元。 */
    suspend fun entriesOnce(): List<MenstrualEntryRecord>
    /** pull: リモート行の取り込み。同一 id が既にあれば no-op(iOS の guard と同じ)。 */
    suspend fun applyRemoteInsert(id: String, date: LocalDate, createdAtEpochMs: Long)
    /** pull: tombstone の適用。id 指定でローカル削除(削除キューには積まない)。 */
    suspend fun applyRemoteDelete(id: String)
}

/**
 * DataStore 実装。v2 は id 付きエントリの JSON リスト。旧形式(epochDay の Set)は
 * **決定的 UUID**(nameUUIDFromBytes)で読出し時にマージし、次の書込みで v2 へ統合する
 * (決定的なので未統合のまま複数回読んでも id がブレない)。
 */
class MenstrualRepositoryImpl @Inject constructor(
    private val dataStore: DataStore<Preferences>,
    private val backupStore: RecordBackupStore,
    private val json: Json,
    private val clock: java.time.Clock,
    @MenstrualCipher private val cipher: StringCipher,
) : MenstrualRepository {

    private val legacyKey = stringSetPreferencesKey("menstrual_period_epoch_days")
    private val entriesKey = stringPreferencesKey("menstrual_entries_v2")
    private val serializer = ListSerializer(MenstrualEntryRecord.serializer())

    override val periodDays: Flow<Set<LocalDate>> = dataStore.data.map { prefs ->
        mergedEntries(prefs).map { it.date }.toSet()
    }

    override suspend fun entriesOnce(): List<MenstrualEntryRecord> =
        mergedEntries(dataStore.data.first())

    override suspend fun toggle(date: LocalDate) {
        val day = date.toEpochDay()
        var removedIds: List<String> = emptyList()
        dataStore.edit { prefs ->
            val current = mergedEntries(prefs)
            val hit = current.filter { it.epochDay == day }
            val next = if (hit.isNotEmpty()) {
                removedIds = hit.map { it.id }
                current.filterNot { it.epochDay == day }
            } else {
                current + MenstrualEntryRecord(
                    id = UUID.randomUUID().toString(),
                    epochDay = day,
                    createdAtEpochMs = clock.millis(),
                )
            }
            write(prefs, next)
        }
        // OFF にした日はクラウドの tombstone キューへ(iOS MenstrualStore と同じフック位置)。
        removedIds.forEach { backupStore.noteDeletion(it.lowercase()) }
    }

    override suspend fun clearAll() {
        dataStore.edit { prefs ->
            prefs.remove(legacyKey)
            prefs.remove(entriesKey)
        }
    }

    override suspend fun applyRemoteInsert(id: String, date: LocalDate, createdAtEpochMs: Long) {
        dataStore.edit { prefs ->
            val current = mergedEntries(prefs)
            if (current.any { it.id.equals(id, ignoreCase = true) }) return@edit
            write(prefs, current + MenstrualEntryRecord(id.lowercase(), date.toEpochDay(), createdAtEpochMs))
        }
    }

    override suspend fun applyRemoteDelete(id: String) {
        dataStore.edit { prefs ->
            val current = mergedEntries(prefs)
            val next = current.filterNot { it.id.equals(id, ignoreCase = true) }
            if (next.size != current.size) write(prefs, next)
        }
    }

    /** v2 エントリ + 未統合の旧 Set(決定的 UUID 付与)のマージビュー。 */
    private fun mergedEntries(prefs: Preferences): List<MenstrualEntryRecord> {
        val v2 = prefs[entriesKey]?.let { stored ->
            // 暗号化済み(2026-06-22 以降)を優先で復号。失敗したら旧平文 JSON とみなして直接 parse
            // (初回起動の後方互換)。次の write で暗号化形式へ統合される。
            val jsonStr = cipher.decryptOrNull(stored) ?: stored
            runCatching { json.decodeFromString(serializer, jsonStr) }.getOrDefault(emptyList())
        } ?: emptyList()
        val v2Days = v2.map { it.epochDay }.toSet()
        val legacy = (prefs[legacyKey] ?: emptySet())
            .mapNotNull { it.toLongOrNull() }
            .filterNot { it in v2Days }
            .map { day -> MenstrualEntryRecord(legacyId(day), day, legacyCreatedAt(day)) }
        return v2 + legacy
    }

    /** v2 へ書き戻し、旧キーは破棄(以後は v2 が単一の正)。値は保存時暗号化する。 */
    private fun write(prefs: androidx.datastore.preferences.core.MutablePreferences, entries: List<MenstrualEntryRecord>) {
        prefs[entriesKey] = cipher.encrypt(json.encodeToString(serializer, entries))
        prefs.remove(legacyKey)
    }

    companion object {
        /** 旧形式の日付に与える決定的 UUID(v3)。再読込・再端末でも同じ id になり同期が収束する。 */
        fun legacyId(epochDay: Long): String =
            UUID.nameUUIDFromBytes("goexercise-menstrual-$epochDay".toByteArray(Charsets.UTF_8)).toString()

        /** 旧形式の createdAt は当日 0 時(UTC)に固定(決定的。push 差分は初回全量なので十分)。 */
        fun legacyCreatedAt(epochDay: Long): Long =
            LocalDate.ofEpochDay(epochDay).atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }
}

/** 生理(reproductive health)データ専用の FieldCipher を区別する Hilt 修飾子。 */
@javax.inject.Qualifier
@Retention(AnnotationRetention.BINARY)
annotation class MenstrualCipher

@Module
@InstallIn(SingletonComponent::class)
abstract class MenstrualModule {
    @Binds
    @Singleton
    abstract fun bindMenstrualRepository(impl: MenstrualRepositoryImpl): MenstrualRepository

    companion object {
        /**
         * 生理データ用の AES-256 鍵を Keystore 連動ストアに保持し、それで FieldCipher を生成。
         * DB パスフレーズとは別ファイル/別鍵名で分離(用途ごと独立)。
         */
        @Provides
        @Singleton
        @MenstrualCipher
        fun provideMenstrualCipher(@ApplicationContext context: Context): StringCipher =
            FieldCipher.create(context, prefsFile = "secure_health_keys", keyName = "menstrual_aes_key")
    }
}
