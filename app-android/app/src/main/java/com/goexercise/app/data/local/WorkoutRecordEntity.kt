package com.goexercise.app.data.local

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Room 永続化エンティティ。iOS SwiftData `WorkoutRecord` の移植(計画書 §4)。
 * - 日付は **epochDay**(LocalDate.toEpochDay)で保存しタイムゾーン非依存にする。
 * - exercises は iOS と同様 **JSON 文字列**で保持(子テーブルにしない)。
 * - createdAt/updatedAt は epoch milli。ドメインモデルは純粋に保つため、これらは
 *   データ層だけが持ち、Repository が書き込み時に設定する。
 */
@Entity(tableName = "workout_records", indices = [Index("dateEpochDay")])
data class WorkoutRecordEntity(
    @PrimaryKey val id: String,
    val dateEpochDay: Long,
    val categoryRaw: String,
    val exercisesJson: String,
    val memo: String?,
    val createdAtEpochMs: Long,
    val updatedAtEpochMs: Long,
)
