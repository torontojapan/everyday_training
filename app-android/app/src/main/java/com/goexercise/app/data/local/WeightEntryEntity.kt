package com.goexercise.app.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * 体重記録の Room エンティティ(P1.x premium)。iOS SwiftData `WeightEntry` の移植。
 * - `recordedAtEpochMs`: 計測時刻(Instant millis)。同一日複数記録のため startOfDay 正規化はしない。
 * - createdAt/updatedAt は epoch milli(順序安定 + 日内最新の tie-break)。
 */
@Entity(tableName = "weight_entries", indices = [Index("recordedAtEpochMs")])
data class WeightEntryEntity(
    @PrimaryKey val id: String,
    val recordedAtEpochMs: Long,
    val weightKg: Double,
    val memo: String?,
    val createdAtEpochMs: Long,
    val updatedAtEpochMs: Long,
)
