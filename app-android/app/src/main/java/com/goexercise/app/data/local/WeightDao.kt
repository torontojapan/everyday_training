package com.goexercise.app.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface WeightDao {
    // 新→古。同一時刻の二重 insert でも createdAt→id で deterministic に。
    @Query("SELECT * FROM weight_entries ORDER BY recordedAtEpochMs DESC, createdAtEpochMs DESC, id DESC")
    fun observeAll(): Flow<List<WeightEntryEntity>>

    @Insert
    suspend fun insert(entry: WeightEntryEntity)

    @Query("DELETE FROM weight_entries WHERE id = :id")
    suspend fun deleteById(id: String)
}
