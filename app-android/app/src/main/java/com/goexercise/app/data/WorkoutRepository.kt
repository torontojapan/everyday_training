package com.goexercise.app.data

import com.goexercise.app.data.local.WorkoutDao
import com.goexercise.app.data.local.toDomain
import com.goexercise.app.data.local.toEntity
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import java.time.Clock
import java.time.Instant
import java.time.LocalDate
import javax.inject.Inject

/**
 * 運動記録のリポジトリ。ViewModel はこの interface 越しに永続層へアクセスする
 * (iOS の WorkoutStore 相当)。ドメイン型(WorkoutRecord)だけを公開し Room を隠蔽。
 */
interface WorkoutRepository {
    fun observeRecords(): Flow<List<WorkoutRecord>>
    suspend fun save(record: WorkoutRecord)
    suspend fun delete(id: String)
}

class WorkoutRepositoryImpl @Inject constructor(
    private val dao: WorkoutDao,
    private val json: Json,
    private val clock: Clock,
    private val backupStore: com.goexercise.app.data.backup.RecordBackupStore,
) : WorkoutRepository {

    // JSON デコードを collector スレッドから逃がす(履歴が増えても UI を塞がない)。
    override fun observeRecords(): Flow<List<WorkoutRecord>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain(json) } }.flowOn(Dispatchers.Default)


    override suspend fun save(record: WorkoutRecord) {
        val now = Instant.now(clock).toEpochMilli()
        // 編集時は既存 createdAt を保持し、updatedAt のみ更新(iOS と同じ作成/更新分離)。
        val createdAt = dao.findById(record.id)?.createdAtEpochMs ?: now
        dao.upsert(record.toEntity(json, createdAtEpochMs = createdAt, updatedAtEpochMs = now))
    }

    override suspend fun delete(id: String) {
        dao.deleteById(id)
        // クラウドバックアップへ削除を伝播(現状 UI からの個別削除は無いが、導線追加時の漏れを防ぐ)。
        backupStore.noteDeletion(id.lowercase())
    }
}
