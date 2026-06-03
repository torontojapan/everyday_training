package com.goexercise.app.data.local

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface WorkoutDao {
    @Query("SELECT * FROM workout_records ORDER BY dateEpochDay DESC")
    fun observeAll(): Flow<List<WorkoutRecordEntity>>

    @Query("SELECT * FROM workout_records WHERE dateEpochDay BETWEEN :startEpochDay AND :endEpochDay ORDER BY dateEpochDay")
    suspend fun rangeOnce(startEpochDay: Long, endEpochDay: Long): List<WorkoutRecordEntity>

    @Upsert
    suspend fun upsert(record: WorkoutRecordEntity)

    @Query("DELETE FROM workout_records WHERE id = :id")
    suspend fun deleteById(id: String)
}
