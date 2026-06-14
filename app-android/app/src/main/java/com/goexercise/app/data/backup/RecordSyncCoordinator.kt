package com.goexercise.app.data.backup

import com.goexercise.app.data.friends.BackupRecord
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.data.local.WeightDao
import com.goexercise.app.data.local.WeightEntryEntity
import com.goexercise.app.data.local.WorkoutDao
import com.goexercise.app.data.local.WorkoutRecordEntity
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.domain.friends.ReferralClock
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.sync.Mutex
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.put
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

/**
 * 記録(運動・体重・体調・フリーズ救済日)のクラウドバックアップ/復元コーディネータ。
 * iOS `RecordSyncCoordinator` の移植。Duolingo 型: 本人アカウント(匿名+Apple/Google連携)に
 * 紐付け、OS 跨ぎの機種変更でも復元できる。
 *
 * 設計(iOS と同一):
 * - **オプトイン(既定 OFF)**。ON の間、起動時とバックグラウンド移行時に同期。
 * - push: `updatedAt > lastSyncAt` のレコード(+ 救済日は全件=少量)を upsert(冪等)。
 * - pull: 本人の全行を取得し、ローカルに無い id を挿入 / tombstone(deleted)はローカル削除 /
 *   既存 id は updatedAt の新しい方を採用(LWW)。
 * - 削除伝播: 各 Repository の削除時に [RecordBackupStore.noteDeletion] でキューイングし、
 *   次回同期でサーバへ論理削除を書く。「すべての記録を削除」は wipe でサーバも物理全削除。
 * - watermark は同期**開始**時刻(終了時刻だと同期中の変更が永久に push されない。Codex P1)。
 * - tombstone は peek→送信成功後 clear(先に消すと送信失敗で削除がリモートに残る。Codex P1)。
 *
 * ★ payload のクロスOS契約(iOS RecordSyncCoordinator 冒頭と同一。変更時は両OS同時に):
 *  - workout:   {"date": ISO8601, "category": rawValue, "exercises": [ExerciseItem JSON],
 *                "memo": String?, "createdAt": ISO8601, "updatedAt": ISO8601}
 *  - weight:    {"date": ISO8601, "kg": Double, "memo": String?, "createdAt": ISO8601, "updatedAt": ISO8601}
 *  - menstrual: {"date": ISO8601, "createdAt": ISO8601}
 *  - rescued_day: {"day": "yyyy-MM-dd"}   (record_id = "rescued-yyyy-MM-dd")
 *  日付は ISO8601(秒精度・UTC)。day はローカル暦日文字列。workout/menstrual の date は
 *  端末ローカルの 0 時を指す instant(iOS の startOfDay と同じ意味)。
 */
@Singleton
class RecordSyncCoordinator @Inject constructor(
    private val service: FriendsService,
    private val store: RecordBackupStore,
    private val workoutDao: WorkoutDao,
    private val weightDao: WeightDao,
    private val menstrual: MenstrualRepository,
    private val rescue: RescueTicketRepository,
    private val json: Json,
    private val clock: Clock,
) {
    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    /** オプトイン状態(設定トグルにバインド)。 */
    val isEnabled = store.enabled

    private val syncMutex = Mutex()

    /** バックアップを ON にする。未サインインなら匿名アカウントを発行してから全量同期。 */
    suspend fun enableBackup() {
        _lastError.value = null
        try {
            if (service.myProfile() == null) {
                service.signIn(displayName = "ねこの友", username = generatedUsername())
            }
            store.setEnabled(true)
            syncNow()
        } catch (e: Exception) {
            _lastError.value = "バックアップを開始できませんでした。通信環境を確認してください。"
        }
    }

    /** OFF: 同期を止めるだけ(クラウド上の既存バックアップは残す。全消去は「すべての記録を削除」)。 */
    suspend fun disableBackup() {
        store.setEnabled(false)
    }

    /**
     * サインイン復元(アカウント切替)直後に呼ぶ。リモートにバックアップがあれば
     * 取り込み、自動で ON にする(機種変更フローを1タップ少なく。iOS と同じ)。
     * 同期 mutex 下で実行し、進行中の syncNow と適用が交錯しないようにする。
     */
    suspend fun restoreAfterSignIn() {
        if (service.myProfile() == null) return
        var imported = false
        syncMutex.lock()
        try {
            val rows = service.backupFetchAll()
            if (rows.isEmpty()) return
            apply(rows)
            store.setEnabled(true)
            imported = true
            // ここで watermark(lastSyncAt)は**打たない**。切替前から端末にあったローカル限定の
            // 記録が updatedAt <= stamp で永久に push されなくなる(Codex R4)。直後の全量同期に委ねる。
        } catch (e: Exception) {
            _lastError.value = "バックアップの復元に失敗しました。"
        } finally {
            syncMutex.unlock()
        }
        // 全量同期: resetForIdentityChange 済みで lastSync=null のため、ローカル全件 push(冪等
        // upsert)→ pull → 開始時刻 stamp。切替前からのローカル記録も確実にクラウドへ載せる。
        if (imported) syncNow()
    }

    /** 通常同期(起動時/バックグラウンド移行時/手動)。 */
    suspend fun syncNow() {
        if (!store.isEnabled()) return
        if (!syncMutex.tryLock()) return // 多重同期ガード(iOS isSyncing と同じ)
        _isSyncing.value = true
        try {
            val startCode = service.myProfile()?.friendCode ?: return
            _lastError.value = null
            val syncStart = clock.instant()
            // 1) 削除キューを伝播(wipe は物理全削除)。peek→成功後に clear。
            val pending = store.peekPending()
            if (pending.wipe || pending.ids.isNotEmpty()) {
                // 破壊的操作の直前にアカウント不変を再検証する。同期中(await の網羅外)に
                // アカウント切替が完了していると、旧アカウント宛の wipe/削除を**新アカウント**に
                // 適用してしまう(Codex 指摘の in-flight 口座跨ぎ)。変わっていたら同期ごと中止
                // (キューは resetForIdentityChange が破棄済みのはず。残っていても次回 peek で安全)。
                if (identityChanged(startCode)) return
                if (pending.wipe) {
                    service.backupWipeAll()
                } else {
                    service.backupMarkDeleted(pending.ids.toList())
                }
            }
            store.clearPending(pending.ids, pending.wipe)
            // 2) pull → マージ適用を **push より先に** 行う。push を先にすると、自端末の古い編集
            //    (updatedAt > lastSync だが他端末の編集より古い)が無条件 upsert で新しいリモート行を
            //    潰し、LWW の比較機会が失われる(Codex R5: 新しい編集の喪失)。pull で remote-newer を
            //    取り込んでから push すれば、古い側はローカルで上書きされ、push は最新内容の冪等 echo になる。
            apply(service.backupFetchAll())
            // 3) push(lastSync 以降の変更 + 救済日全件)。直前にも identity を再検証し、切替後に
            //    旧アカウントの記録(体重・体調を含む機微データ)を新アカウントへ upsert する流出を防ぐ。
            if (identityChanged(startCode)) return
            service.backupUpsert(changedRecords(since = store.lastSyncAt.first()))
            store.stampSynced(syncStart)
        } catch (e: Exception) {
            _lastError.value = "同期に失敗しました。通信環境を確認してください。"
        } finally {
            _isSyncing.value = false
            syncMutex.unlock()
        }
    }

    /**
     * アカウント切替/復元/サインアウト時に呼ぶ(口座跨ぎ事故防止。詳細は [RecordBackupStore])。
     * 同期 mutex を取得してから破棄する = 進行中の syncNow の完了を待ち、旧キューを読み込んだ
     * 同期と新アカウントの状態が交錯しないよう直列化する(Codex 指摘の是正)。
     */
    suspend fun resetForIdentityChange() {
        syncMutex.lock()
        try {
            store.resetForIdentityChange()
        } finally {
            syncMutex.unlock()
        }
    }

    /** 同期開始時とアカウントが変わったか(in-flight 切替の検出。fail closed = 不明なら変わった扱い)。 */
    private suspend fun identityChanged(startCode: String): Boolean =
        runCatching { service.myProfile()?.friendCode != startCode }.getOrDefault(true)

    // ---- push(エンコード)----

    private suspend fun changedRecords(since: Instant?): List<BackupRecord> {
        val sinceMs = since?.toEpochMilli()
        val out = mutableListOf<BackupRecord>()

        for (e in workoutDao.getAllOnce()) {
            if (sinceMs != null && e.updatedAtEpochMs <= sinceMs) continue
            val exercises = runCatching { json.parseToJsonElement(e.exercisesJson) }
                .getOrDefault(JsonArray(emptyList()))
            val payload = buildJsonObject {
                put("date", iso(localDayInstant(LocalDate.ofEpochDay(e.dateEpochDay))))
                put("category", e.categoryRaw)
                put("exercises", exercises)
                e.memo?.let { put("memo", it) }
                put("createdAt", iso(Instant.ofEpochMilli(e.createdAtEpochMs)))
                put("updatedAt", iso(Instant.ofEpochMilli(e.updatedAtEpochMs)))
            }
            out += BackupRecord(e.id.lowercase(), "workout", payload, Instant.ofEpochMilli(e.updatedAtEpochMs), deleted = false)
        }

        for (w in weightDao.getAllOnce()) {
            if (sinceMs != null && w.updatedAtEpochMs <= sinceMs) continue
            val payload = buildJsonObject {
                // recordedAtEpochMs は「UTC 解釈した壁時計値」(WeightMappers 参照)。クラウド契約は
                // 実 instant なので、端末ローカル時刻として解釈し直してから書く(Codex 指摘の是正)。
                put("date", iso(weightInstant(w.recordedAtEpochMs)))
                put("kg", w.weightKg)
                w.memo?.let { put("memo", it) }
                put("createdAt", iso(Instant.ofEpochMilli(w.createdAtEpochMs)))
                put("updatedAt", iso(Instant.ofEpochMilli(w.updatedAtEpochMs)))
            }
            out += BackupRecord(w.id.lowercase(), "weight", payload, Instant.ofEpochMilli(w.updatedAtEpochMs), deleted = false)
        }

        for (m in menstrual.entriesOnce()) {
            if (sinceMs != null && m.createdAtEpochMs <= sinceMs) continue
            val payload = buildJsonObject {
                put("date", iso(localDayInstant(m.date)))
                put("createdAt", iso(Instant.ofEpochMilli(m.createdAtEpochMs)))
            }
            out += BackupRecord(m.id.lowercase(), "menstrual", payload, Instant.ofEpochMilli(m.createdAtEpochMs), deleted = false)
        }

        // 救済日は少量(月≤5)なので毎回全件 upsert(冪等・削除は wipe 以外で起きない)
        for (day in rescue.rescuedDates.first()) {
            val key = day.toString() // ISO yyyy-MM-dd(ローカル暦日)
            val payload = buildJsonObject { put("day", key) }
            out += BackupRecord("rescued-$key", "rescued_day", payload, localDayInstant(day), deleted = false)
        }
        return out
    }

    // ---- pull(デコード/マージ)----

    private suspend fun apply(rows: List<BackupRecord>) {
        val localWorkouts = workoutDao.getAllOnce().associateBy { it.id.lowercase() }
        val localWeights = weightDao.getAllOnce().associateBy { it.id.lowercase() }
        val importedRescued = mutableSetOf<LocalDate>()

        for (row in rows) {
            val id = row.id.lowercase()
            when (row.kind) {
                "workout" -> {
                    if (row.deleted) {
                        localWorkouts[id]?.let { workoutDao.deleteById(it.id) }
                        continue
                    }
                    val p = row.payload
                    val date = parseIso(p.str("date")) ?: continue
                    val category = p.str("category") ?: continue
                    val exercisesJson = (p["exercises"] as? JsonArray)?.toString() ?: "[]"
                    val createdAt = parseIso(p.str("createdAt")) ?: date
                    val updatedAt = parseIso(p.str("updatedAt")) ?: date
                    val local = localWorkouts[id]
                    if (local != null) {
                        // LWW: リモートの方が新しければ取り込む(別端末での編集を反映。+1s は時計ブレ吸収、iOS と同値)
                        if (updatedAt > Instant.ofEpochMilli(local.updatedAtEpochMs).plusSeconds(1)) {
                            workoutDao.upsert(
                                local.copy(
                                    dateEpochDay = toLocalDate(date).toEpochDay(),
                                    categoryRaw = category,
                                    exercisesJson = exercisesJson,
                                    memo = p.str("memo"),
                                    updatedAtEpochMs = updatedAt.toEpochMilli(),
                                ),
                            )
                        }
                    } else if (isUuid(id)) {
                        workoutDao.upsert(
                            WorkoutRecordEntity(
                                id = id,
                                dateEpochDay = toLocalDate(date).toEpochDay(),
                                categoryRaw = category,
                                exercisesJson = exercisesJson,
                                memo = p.str("memo"),
                                createdAtEpochMs = createdAt.toEpochMilli(),
                                updatedAtEpochMs = updatedAt.toEpochMilli(),
                            ),
                        )
                    }
                }
                "weight" -> {
                    if (row.deleted) {
                        localWeights[id]?.let { weightDao.deleteById(it.id) }
                        continue
                    }
                    val p = row.payload
                    val date = parseIso(p.str("date")) ?: continue
                    val kg = p.dbl("kg") ?: continue
                    val createdAt = parseIso(p.str("createdAt")) ?: date
                    val updatedAt = parseIso(p.str("updatedAt")) ?: date
                    val local = localWeights[id]
                    if (local != null) {
                        if (updatedAt > Instant.ofEpochMilli(local.updatedAtEpochMs).plusSeconds(1)) {
                            weightDao.upsert(
                                local.copy(
                                    recordedAtEpochMs = weightEntityMs(date),
                                    weightKg = kg,
                                    memo = p.str("memo"),
                                    updatedAtEpochMs = updatedAt.toEpochMilli(),
                                ),
                            )
                        }
                    } else if (isUuid(id)) {
                        weightDao.upsert(
                            WeightEntryEntity(
                                id = id,
                                recordedAtEpochMs = weightEntityMs(date),
                                weightKg = kg,
                                memo = p.str("memo"),
                                createdAtEpochMs = createdAt.toEpochMilli(),
                                updatedAtEpochMs = updatedAt.toEpochMilli(),
                            ),
                        )
                    }
                }
                "menstrual" -> {
                    if (row.deleted) {
                        menstrual.applyRemoteDelete(id)
                        continue
                    }
                    if (!isUuid(id)) continue
                    val p = row.payload
                    val date = parseIso(p.str("date")) ?: continue
                    val createdAt = parseIso(p.str("createdAt")) ?: date
                    menstrual.applyRemoteInsert(id, toLocalDate(date), createdAt.toEpochMilli())
                }
                "rescued_day" -> {
                    if (row.deleted) continue
                    val day = row.payload.str("day")?.let { runCatching { LocalDate.parse(it) }.getOrNull() } ?: continue
                    importedRescued.add(day)
                }
            }
        }
        if (importedRescued.isNotEmpty()) rescue.importRescuedDays(importedRescued)
    }

    // ---- Helpers ----

    /** ISO8601(秒精度・UTC)。iOS ISO8601DateFormatter 既定と同形。 */
    private fun iso(instant: Instant): String =
        DateTimeFormatter.ISO_INSTANT.format(instant.truncatedTo(ChronoUnit.SECONDS))

    private fun parseIso(s: String?): Instant? = s?.let { ReferralClock.parseTimestamp(it) }

    /** 端末ローカルの 0 時を指す instant(iOS calendar.startOfDay と同じ意味)。 */
    private fun localDayInstant(day: LocalDate): Instant = day.atStartOfDay(clock.zone).toInstant()

    /** weight entity の「UTC 解釈した壁時計値」→ 実 instant(端末ローカル時刻として解釈)。 */
    private fun weightInstant(entityMs: Long): Instant =
        java.time.LocalDateTime.ofInstant(Instant.ofEpochMilli(entityMs), java.time.ZoneOffset.UTC)
            .atZone(clock.zone).toInstant()

    /** 実 instant → weight entity の「UTC 解釈した壁時計値」(ローカル壁時計に落としてから UTC 固定で格納)。 */
    private fun weightEntityMs(instant: Instant): Long =
        instant.atZone(clock.zone).toLocalDateTime().toInstant(java.time.ZoneOffset.UTC).toEpochMilli()

    private fun toLocalDate(instant: Instant): LocalDate = instant.atZone(clock.zone).toLocalDate()

    private fun isUuid(s: String): Boolean = runCatching { UUID.fromString(s) }.isSuccess

    private fun generatedUsername(): String =
        "neko" + UUID.randomUUID().toString().replace("-", "").take(6).lowercase()

    private fun JsonObject.str(key: String): String? =
        (this[key] as? kotlinx.serialization.json.JsonPrimitive)?.takeIf { it.isString }?.content

    private fun JsonObject.dbl(key: String): Double? =
        (this[key] as? kotlinx.serialization.json.JsonPrimitive)?.content?.toDoubleOrNull()
}
