package com.goexercise.app.data.backup

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import androidx.datastore.preferences.core.Preferences
import com.goexercise.app.data.friends.BackupRecord
import com.goexercise.app.data.friends.FriendsService
import com.goexercise.app.data.friends.MockFriendsService
import com.goexercise.app.data.local.WeightDao
import com.goexercise.app.data.local.WeightEntryEntity
import com.goexercise.app.data.local.WorkoutDao
import com.goexercise.app.data.local.WorkoutRecordEntity
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.MenstrualEntryRecord
import com.goexercise.app.data.settings.MenstrualRepository
import com.goexercise.app.data.settings.MenstrualRepositoryImpl
import com.goexercise.app.data.security.IdentityStringCipher
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * RecordSyncCoordinator の同期セマンティクス検証。クロスOS payload 契約
 * (iOS RecordSyncCoordinator 冒頭)と Codex 監査 4 件(口座跨ぎ wipe / tombstone 喪失 /
 * 同期中変更 / 削除 fallback)の Android 側パリティを固定する。
 */
class RecordSyncCoordinatorTest {

    @get:Rule
    val tmp = TemporaryFolder()

    // 2026-06-11 12:00 JST(= 03:00 UTC)固定。ローカル暦日は 2026-06-11。
    private val zone = ZoneId.of("Asia/Tokyo")
    private val now = Instant.parse("2026-06-11T03:00:00Z")
    private val clock = Clock.fixed(now, zone)
    private val json = Json { ignoreUnknownKeys = true; coerceInputValues = true; encodeDefaults = true }

    private fun newDataStore(): DataStore<Preferences> =
        PreferenceDataStoreFactory.create(
            scope = CoroutineScope(SupervisorJob() + Dispatchers.IO),
            produceFile = { tmp.newFile("ds-${System.nanoTime()}.preferences_pb") },
        )

    private class Env(
        val service: RecordingService,
        val store: RecordBackupStore,
        val workoutDao: FakeWorkoutDao,
        val weightDao: FakeWeightDao,
        val menstrual: MenstrualRepository,
        val rescue: FakeRescueRepository,
        val sync: RecordSyncCoordinator,
    )

    private fun env(service: RecordingService = RecordingService(MockFriendsService())): Env {
        val ds = newDataStore()
        val store = RecordBackupStore(ds)
        val workoutDao = FakeWorkoutDao()
        val weightDao = FakeWeightDao()
        val menstrual = MenstrualRepositoryImpl(ds, store, json, clock, IdentityStringCipher)
        val rescue = FakeRescueRepository()
        val sync = RecordSyncCoordinator(service, store, workoutDao, weightDao, menstrual, rescue, json, clock)
        return Env(service, store, workoutDao, weightDao, menstrual, rescue, sync)
    }

    private fun workout(id: String, day: LocalDate, updatedAt: Instant, memo: String? = null) =
        WorkoutRecordEntity(
            id = id, dateEpochDay = day.toEpochDay(), categoryRaw = "strength",
            exercisesJson = """[{"id":"e1","name":"スクワット","reps":10,"sets":3,"loadKilograms":20.0,"category":"strength"}]""",
            memo = memo, createdAtEpochMs = updatedAt.toEpochMilli(), updatedAtEpochMs = updatedAt.toEpochMilli(),
        )

    private fun weight(id: String, at: Instant, kg: Double) =
        WeightEntryEntity(id = id, recordedAtEpochMs = at.toEpochMilli(), weightKg = kg, memo = null,
            createdAtEpochMs = at.toEpochMilli(), updatedAtEpochMs = at.toEpochMilli())

    // ---- push: payload 契約 ----

    @Test fun push_payloadContract_matchesIOS() = runBlocking {
        // 既存データがある状態で ON(初回 = lastSync なしの全量 push)
        val e = env()
        e.workoutDao.upsert(workout("11111111-1111-1111-1111-111111111111", LocalDate.of(2026, 6, 11), now))
        e.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now, 61.5))
        e.menstrual.toggle(LocalDate.of(2026, 6, 10))
        e.rescue.importRescuedDays(setOf(LocalDate.of(2026, 6, 9)))
        e.sync.enableBackup()

        val rows = e.service.delegate.backupFetchAll().associateBy { it.id }
        assertEquals(4, rows.size)

        val w = rows["11111111-1111-1111-1111-111111111111"]!!
        assertEquals("workout", w.kind)
        // ローカル暦日 2026-06-11 の 0 時 JST = 2026-06-10T15:00:00Z(iOS startOfDay と同じ意味)
        assertEquals("2026-06-10T15:00:00Z", w.payload.s("date"))
        assertEquals("strength", w.payload.s("category"))
        assertEquals("2026-06-11T03:00:00Z", w.payload.s("updatedAt"))
        assertTrue(w.payload["exercises"].toString().contains("loadKilograms"))

        val kg = rows["22222222-2222-2222-2222-222222222222"]!!
        assertEquals("weight", kg.kind)
        // entity の recordedAtEpochMs は「UTC 解釈した壁時計値」(03:00)。クラウドには
        // JST の壁時計 03:00 を指す実 instant(= 前日 18:00Z)として書く(クロスOS契約)。
        assertEquals("2026-06-10T18:00:00Z", kg.payload.s("date"))
        assertEquals(61.5, kg.payload.d("kg")!!, 0.0001)

        val rescued = rows["rescued-2026-06-09"]!!
        assertEquals("rescued_day", rescued.kind)
        assertEquals("2026-06-09", rescued.payload.s("day"))

        val mens = rows.values.first { it.kind == "menstrual" }
        assertEquals("2026-06-09T15:00:00Z", mens.payload.s("date")) // 6/10 の 0 時 JST
        assertNotNull(mens.payload.s("createdAt"))
    }

    @Test fun push_diff_onlyChangedSinceLastSync() = runBlocking {
        val e = env()
        e.sync.enableBackup()
        e.workoutDao.upsert(workout("11111111-1111-1111-1111-111111111111", LocalDate.of(2026, 6, 10), now.minusSeconds(3600)))
        e.sync.syncNow()
        e.service.upsertBatches.clear()
        // lastSync(= 同期開始時刻 now)より古い行は push されない。新しい行だけ push。
        e.workoutDao.upsert(workout("33333333-3333-3333-3333-333333333333", LocalDate.of(2026, 6, 11), now.plusSeconds(60)))
        e.sync.syncNow()
        val pushed = e.service.upsertBatches.flatten().filter { it.kind == "workout" }.map { it.id }
        assertEquals(listOf("33333333-3333-3333-3333-333333333333"), pushed)
    }

    // ---- pull: 復元 / LWW ----

    @Test fun pull_restoresOnFreshDevice() = runBlocking {
        // 端末 A で push → 端末 B(空ローカル・同一アカウント)で restoreAfterSignIn
        val service = RecordingService(MockFriendsService())
        val a = env(service)
        a.workoutDao.upsert(workout("11111111-1111-1111-1111-111111111111", LocalDate.of(2026, 6, 11), now))
        a.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now, 61.5))
        a.menstrual.toggle(LocalDate.of(2026, 6, 10))
        a.rescue.importRescuedDays(setOf(LocalDate.of(2026, 6, 9)))
        a.sync.enableBackup() // 初回 = 全量 push

        val b = env(service) // 同じ service = 同じアカウントのクラウド
        b.sync.restoreAfterSignIn()
        assertEquals(1, b.workoutDao.rows.size)
        val w = b.workoutDao.rows.values.first()
        assertEquals(LocalDate.of(2026, 6, 11).toEpochDay(), w.dateEpochDay)
        assertTrue(w.exercisesJson.contains("スクワット"))
        assertEquals(1, b.weightDao.rows.size)
        // 壁時計値が round-trip する(push で実 instant 化 → pull で壁時計へ戻す)
        assertEquals(now.toEpochMilli(), b.weightDao.rows.values.first().recordedAtEpochMs)
        assertEquals(setOf(LocalDate.of(2026, 6, 10)), b.menstrual.periodDays.first())
        assertEquals(setOf(LocalDate.of(2026, 6, 9)), b.rescue.days)
        // リモートにバックアップがあれば自動 ON(機種変更フロー)
        assertTrue(b.store.isEnabled())
    }

    @Test fun restore_pushesPreexistingLocalRecords() = runBlocking {
        // 切替先にバックアップがある場合でも、切替前から端末にあったローカル限定の記録が
        // 復元後の全量同期でクラウドへ載る(watermark 先打ちで永久に漏れない。Codex R4)。
        val service = RecordingService(MockFriendsService())
        val a = env(service)
        a.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now, 61.5))
        a.sync.enableBackup() // アカウントに 1 件のリモート行
        val b = env(service) // 同一アカウントへ切替する端末 B(ローカル限定の記録を持つ)
        b.workoutDao.upsert(workout("33333333-3333-3333-3333-333333333333", LocalDate.of(2026, 6, 10), now))
        b.sync.restoreAfterSignIn()
        val remoteIds = service.delegate.backupFetchAll().map { it.id }.toSet()
        assertTrue("ローカル限定の記録が push されていない", "33333333-3333-3333-3333-333333333333" in remoteIds)
        assertEquals(1, b.weightDao.rows.size) // リモート行の取り込みも行われている
        assertTrue(b.store.isEnabled())
    }

    @Test fun restoreAfterSignIn_emptyRemote_doesNotEnable() = runBlocking {
        val e = env()
        e.service.delegate.signIn("あなた", "you")
        e.sync.restoreAfterSignIn()
        assertFalse(e.store.isEnabled())
    }

    @Test fun pull_lww_remoteNewerWins_olderLoses() = runBlocking {
        val e = env()
        e.sync.enableBackup()
        val id = "11111111-1111-1111-1111-111111111111"
        e.workoutDao.upsert(workout(id, LocalDate.of(2026, 6, 11), now, memo = "ローカル"))
        // リモートに 1 時間新しい同 id(別端末の編集)
        e.service.delegate.backupUpsert(listOf(remoteWorkout(id, now.plusSeconds(3600), memo = "リモート")))
        e.sync.syncNow()
        assertEquals("リモート", e.workoutDao.rows[id]!!.memo)
        // 逆: リモートが古ければローカル維持(push の冪等 upsert がリモートを上書きする)
        e.service.delegate.backupUpsert(listOf(remoteWorkout(id, now.minusSeconds(7200), memo = "古い")))
        e.workoutDao.upsert(e.workoutDao.rows[id]!!.copy(memo = "ローカル2", updatedAtEpochMs = now.plusSeconds(7200).toEpochMilli()))
        e.sync.syncNow()
        assertEquals("ローカル2", e.workoutDao.rows[id]!!.memo)
    }

    @Test fun pull_beforePush_preservesNewerRemoteEdit() = runBlocking {
        // 他端末がより新しい編集をアップ済みのとき、自端末の古い編集(updatedAt > lastSync)が
        // 無条件 push で新しいリモート行を潰さない(pull→push 順序の固定。Codex R5)。
        val e = env()
        val id = "11111111-1111-1111-1111-111111111111"
        e.workoutDao.upsert(workout(id, LocalDate.of(2026, 6, 11), now, memo = "初版"))
        e.sync.enableBackup()
        // 他端末の新しい編集(now+100s)がリモードに存在
        e.service.delegate.backupUpsert(listOf(remoteWorkout(id, now.plusSeconds(100), memo = "新しい編集")))
        // 自端末でそれより古い編集(now+10s > lastSync=now)
        e.workoutDao.upsert(e.workoutDao.rows[id]!!.copy(memo = "古い編集", updatedAtEpochMs = now.plusSeconds(10).toEpochMilli()))
        e.sync.syncNow()
        // リモートもローカルも「新しい編集」が勝つ(古い編集で上書きされない)
        assertEquals("新しい編集", e.workoutDao.rows[id]!!.memo)
        val remote = e.service.delegate.backupFetchAll().first { it.id == id }
        assertEquals("新しい編集", (remote.payload["memo"] as? kotlinx.serialization.json.JsonPrimitive)?.content)
    }

    @Test fun pull_iosShapedPayload_decodes() = runBlocking {
        // iOS が書いた形(秒精度 ISO8601・UUID 大文字)をそのまま適用できる
        val e = env()
        e.sync.enableBackup()
        val payload = buildJsonObject {
            put("date", "2026-06-10T15:00:00Z")
            put("category", "cardio")
            putJsonArray("exercises") {
                add(json.parseToJsonElement("""{"id":"5DE0AC4F-9C1B-4A39-B86F-111111111111","name":"ランニング","durationSeconds":1200,"loadKilograms":null}"""))
            }
            put("createdAt", "2026-06-10T22:00:00Z")
            put("updatedAt", "2026-06-10T22:30:00Z")
        }
        e.service.delegate.backupUpsert(listOf(
            BackupRecord("AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE", "workout", payload, Instant.parse("2026-06-10T22:30:00Z"), deleted = false),
        ))
        e.sync.syncNow()
        val w = e.workoutDao.rows["aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"]
        assertNotNull(w)
        assertEquals(LocalDate.of(2026, 6, 11).toEpochDay(), w!!.dateEpochDay) // JST のローカル暦日へ戻る
        assertEquals("cardio", w.categoryRaw)
        // exercises は ExerciseItem として解釈可能(loadKilograms 含む契約互換)
        val items = json.decodeFromString(
            kotlinx.serialization.builtins.ListSerializer(com.goexercise.app.domain.ExerciseItem.serializer()),
            w.exercisesJson,
        )
        assertEquals("ランニング", items.single().name)
        assertEquals(1200, items.single().durationSeconds)
    }

    // ---- 削除伝播(tombstone)----

    @Test fun tombstone_deletePropagates_andDoesNotResurrect() = runBlocking {
        val e = env()
        val id = "22222222-2222-2222-2222-222222222222"
        e.weightDao.insert(weight(id, now, 60.0))
        e.sync.enableBackup() // 初回全量 push でリモートに行ができる
        // 削除 → キュー → 同期で論理削除、pull で復活しない
        e.weightDao.deleteById(id)
        e.store.noteDeletion(id)
        e.sync.syncNow()
        assertNull(e.weightDao.rows[id])
        val remote = e.service.delegate.backupFetchAll().first { it.id == id }
        assertTrue(remote.deleted)
        assertEquals(emptySet<String>(), e.store.peekPending().ids) // 成功後にキュー消化
    }

    @Test fun tombstone_keptWhenSendFails_thenRetried() = runBlocking {
        val e = env()
        val id = "22222222-2222-2222-2222-222222222222"
        e.weightDao.insert(weight(id, now, 60.0))
        e.sync.enableBackup() // 初回全量 push でリモートに行ができる
        e.store.noteDeletion(id)
        e.service.failMarkDeleted = true
        e.sync.syncNow() // 送信失敗
        assertEquals(setOf(id), e.store.peekPending().ids) // peek→clear 方式: 失敗時はキュー温存(Codex P1)
        e.service.failMarkDeleted = false
        e.sync.syncNow() // 再試行で成功
        assertTrue(e.service.delegate.backupFetchAll().first { it.id == id }.deleted)
        assertEquals(emptySet<String>(), e.store.peekPending().ids)
    }

    @Test fun wipe_deletesAllRemote() = runBlocking {
        val e = env()
        e.sync.enableBackup()
        e.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now, 60.0))
        e.sync.syncNow()
        e.weightDao.clearAll()
        e.store.noteWipe()
        e.sync.syncNow()
        assertTrue(e.service.delegate.backupFetchAll().isEmpty())
        assertFalse(e.store.peekPending().wipe)
    }

    @Test fun syncNow_abortsDestructiveOps_whenIdentityChangesMidSync() = runBlocking {
        // 同期開始後〜破壊的操作前にアカウント切替が完了した場合、旧アカウント宛の
        // wipe/削除を新アカウントへ適用せず同期ごと中止する(in-flight 口座跨ぎの是正)。
        val e = env()
        val id = "22222222-2222-2222-2222-222222222222"
        e.weightDao.insert(weight(id, now, 60.0))
        e.sync.enableBackup()
        e.store.noteDeletion(id)
        e.service.friendCodeOverrides = ArrayDeque(listOf("AAA111", "BBB222")) // 開始時と再検証で別アカウント
        e.sync.syncNow()
        val remote = e.service.delegate.backupFetchAll().first { it.id == id }
        assertFalse(remote.deleted) // 新アカウント(に相当する口座)へ削除を適用していない
        assertEquals(setOf(id), e.store.peekPending().ids) // キューも消化しない(reset 側が破棄する)
    }

    @Test fun syncNow_abortsPush_whenIdentityChangesMidSync() = runBlocking {
        // 削除キューが空でも、push 直前の再検証で切替を検出したら旧アカウントの記録
        // (機微データ)を新アカウントへ upsert しない。
        val e = env()
        e.sync.enableBackup()
        e.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now.plusSeconds(60), 60.0))
        e.service.upsertBatches.clear()
        e.service.friendCodeOverrides = ArrayDeque(listOf("AAA111", "BBB222"))
        e.sync.syncNow()
        assertTrue(e.service.upsertBatches.isEmpty())
    }

    @Test fun resetForIdentityChange_dropsQueueWipeAndWatermark() = runBlocking {
        // 口座跨ぎ事故: A の wipe/削除キューを持ったままアカウント B に切替えても B を消さない(Codex P1)
        val e = env()
        e.sync.enableBackup()
        e.sync.syncNow()
        e.store.noteDeletion("22222222-2222-2222-2222-222222222222")
        e.store.noteWipe()
        e.sync.resetForIdentityChange()
        val pending = e.store.peekPending()
        assertEquals(emptySet<String>(), pending.ids)
        assertFalse(pending.wipe)
        assertNull(e.store.lastSyncAt.first()) // 次回は全量 push(冪等)の安全側
    }

    @Test fun syncNow_disabled_isNoop() = runBlocking {
        val e = env()
        e.service.delegate.signIn("あなた", "you")
        e.weightDao.insert(weight("22222222-2222-2222-2222-222222222222", now, 60.0))
        e.sync.syncNow()
        assertTrue(e.service.upsertBatches.isEmpty())
    }

    @Test fun noteDeletion_whileDisabled_isNotQueued() = runBlocking {
        val e = env()
        e.store.noteDeletion("22222222-2222-2222-2222-222222222222")
        assertEquals(emptySet<String>(), e.store.peekPending().ids)
    }

    // ---- menstrual の旧形式マイグレーション ----

    @Test fun menstrualLegacyId_isDeterministic() {
        val day = LocalDate.of(2026, 6, 1).toEpochDay()
        assertEquals(MenstrualRepositoryImpl.legacyId(day), MenstrualRepositoryImpl.legacyId(day))
        assertTrue(MenstrualRepositoryImpl.legacyId(day) != MenstrualRepositoryImpl.legacyId(day + 1))
        // UUID 形式(iOS pull の UUID(uuidString:) ガードを通る)
        assertNotNull(java.util.UUID.fromString(MenstrualRepositoryImpl.legacyId(day)))
    }

    @Test fun menstrual_toggleOff_queuesTombstone() = runBlocking {
        val e = env()
        e.store.setEnabled(true)
        val day = LocalDate.of(2026, 6, 10)
        e.menstrual.toggle(day) // ON
        val id = e.menstrual.entriesOnce().single().id
        e.menstrual.toggle(day) // OFF → tombstone
        assertEquals(setOf(id), e.store.peekPending().ids)
        assertTrue(e.menstrual.periodDays.first().isEmpty())
    }

    // ---- helpers ----

    private fun remoteWorkout(id: String, updatedAt: Instant, memo: String): BackupRecord {
        val payload = buildJsonObject {
            put("date", "2026-06-10T15:00:00Z")
            put("category", "strength")
            putJsonArray("exercises") {}
            put("memo", memo)
            put("createdAt", "2026-06-10T15:00:00Z")
            put("updatedAt", java.time.format.DateTimeFormatter.ISO_INSTANT.format(updatedAt))
        }
        return BackupRecord(id, "workout", payload, updatedAt, deleted = false)
    }

    private fun kotlinx.serialization.json.JsonObject.s(key: String): String? =
        (this[key] as? kotlinx.serialization.json.JsonPrimitive)?.content

    private fun kotlinx.serialization.json.JsonObject.d(key: String): Double? =
        (this[key] as? kotlinx.serialization.json.JsonPrimitive)?.content?.toDoubleOrNull()
}

/** 引数を記録し、失敗/identity 切替を注入できる委譲サービス(push 差分・tombstone 再試行・口座跨ぎ検証用)。 */
private class RecordingService(val delegate: MockFriendsService) : FriendsService by delegate {
    val upsertBatches = mutableListOf<List<BackupRecord>>()
    var failMarkDeleted = false

    /** myProfile() 呼出しごとに friendCode を差し替える(同期中のアカウント切替シミュレーション)。 */
    var friendCodeOverrides: ArrayDeque<String>? = null

    override suspend fun myProfile(): com.goexercise.app.domain.friends.FriendProfile? {
        val base = delegate.myProfile() ?: return null
        val code = friendCodeOverrides?.removeFirstOrNull() ?: return base
        return base.copy(friendCode = code)
    }

    override suspend fun backupUpsert(records: List<BackupRecord>) {
        upsertBatches.add(records)
        delegate.backupUpsert(records)
    }

    override suspend fun backupMarkDeleted(recordIds: List<String>) {
        if (failMarkDeleted) throw RuntimeException("network down")
        delegate.backupMarkDeleted(recordIds)
    }
}

private class FakeWorkoutDao : WorkoutDao {
    val rows = linkedMapOf<String, WorkoutRecordEntity>()
    override fun observeAll(): Flow<List<WorkoutRecordEntity>> = flowOf(rows.values.toList())
    override suspend fun findById(id: String): WorkoutRecordEntity? = rows[id]
    override suspend fun upsert(record: WorkoutRecordEntity) { rows[record.id] = record }
    override suspend fun deleteById(id: String) { rows.remove(id) }
    override suspend fun getAllOnce(): List<WorkoutRecordEntity> = rows.values.toList()
    override suspend fun clearAll() { rows.clear() }
}

private class FakeWeightDao : WeightDao {
    val rows = linkedMapOf<String, WeightEntryEntity>()
    override fun observeAll(): Flow<List<WeightEntryEntity>> = flowOf(rows.values.toList())
    override suspend fun insert(entry: WeightEntryEntity) { rows[entry.id] = entry }
    override suspend fun upsert(entry: WeightEntryEntity) { rows[entry.id] = entry }
    override suspend fun findById(id: String): WeightEntryEntity? = rows[id]
    override suspend fun deleteById(id: String) { rows.remove(id) }
    override suspend fun getAllOnce(): List<WeightEntryEntity> = rows.values.toList()
    override suspend fun clearAll() { rows.clear() }
}

private class FakeRescueRepository : RescueTicketRepository {
    val days = mutableSetOf<LocalDate>()
    private val flow = MutableStateFlow<Set<LocalDate>>(emptySet())
    override val rescuedDates: Flow<Set<LocalDate>> get() = flow.map { days.toSet() }
    override suspend fun useTicket(date: LocalDate, allowance: Int): Boolean { days.add(date); return true }
    override suspend fun clearAll() { days.clear() }
    override suspend fun importRescuedDays(days: Set<LocalDate>) { this.days.addAll(days) }
}
