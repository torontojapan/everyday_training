package com.goexercise.app.data

import com.goexercise.app.data.local.WorkoutDao
import com.goexercise.app.data.local.toDomain
import com.goexercise.app.data.local.toEntity
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.json.Json
import java.time.LocalDate
import javax.inject.Inject

/**
 * 運動記録のリポジトリ。ViewModel はこの interface 越しに永続層へアクセスする
 * (iOS の WorkoutStore 相当)。ドメイン型(WorkoutRecord)だけを公開し Room を隠蔽。
 */
interface WorkoutRepository {
    fun observeRecords(): Flow<List<WorkoutRecord>>
    suspend fun recordsInRange(start: LocalDate, end: LocalDate): List<WorkoutRecord>
    suspend fun save(record: WorkoutRecord)
    suspend fun delete(id: String)
}

class WorkoutRepositoryImpl @Inject constructor(
    private val dao: WorkoutDao,
    private val json: Json,
) : WorkoutRepository {

    override fun observeRecords(): Flow<List<WorkoutRecord>> =
        dao.observeAll().map { rows -> rows.map { it.toDomain(json) } }

    override suspend fun recordsInRange(start: LocalDate, end: LocalDate): List<WorkoutRecord> =
        dao.rangeOnce(start.toEpochDay(), end.toEpochDay()).map { it.toDomain(json) }

    override suspend fun save(record: WorkoutRecord) {
        // TODO(P1a 仕上げ): 編集時は既存 createdAt を保持する(現状は upsert で now 上書き)。
        val now = System.currentTimeMillis()
        dao.upsert(record.toEntity(json, createdAtEpochMs = now, updatedAtEpochMs = now))
    }

    override suspend fun delete(id: String) = dao.deleteById(id)
}
