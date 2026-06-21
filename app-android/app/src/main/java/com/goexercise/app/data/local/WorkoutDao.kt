package com.goexercise.app.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkoutDao {
    // 同一日内の順序を安定化(SQLite は ORDER 未指定だと順序未保証)。id を最終 tie-break に。
    @Query("SELECT * FROM workout_records ORDER BY dateEpochDay DESC, updatedAtEpochMs DESC, id")
    fun observeAll(): Flow<List<WorkoutRecordEntity>>

    @Query("SELECT * FROM workout_records WHERE id = :id")
    suspend fun findById(id: String): WorkoutRecordEntity?

    @Upsert
    suspend fun upsert(record: WorkoutRecordEntity)

    @Query("DELETE FROM workout_records WHERE id = :id")
    suspend fun deleteById(id: String)

    @Query("SELECT * FROM workout_records ORDER BY dateEpochDay, updatedAtEpochMs, id")
    suspend fun getAllOnce(): List<WorkoutRecordEntity>

    @Query("DELETE FROM workout_records")
    suspend fun clearAll()
}
