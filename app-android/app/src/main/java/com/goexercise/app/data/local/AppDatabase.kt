package com.goexercise.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * アプリ DB。v1 は WorkoutRecord のみ。体重/生理(premium, P1.x)エンティティは後で version 上げて追加。
 * exportSchema は v0 段階では false(マイグレーションを書き始める段階で true + スキーマ出力に切替)。
 */
@Database(entities = [WorkoutRecordEntity::class], version = 1, exportSchema = false)
abstract class AppDatabase : RoomDatabase() {
    abstract fun workoutDao(): WorkoutDao
}
