package com.goexercise.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * アプリ DB。v1 は WorkoutRecord のみ。体重/生理(premium, P1.x)エンティティは後で version 上げて追加。
 * exportSchema=true: 各バージョンのスキーマを app/schemas に出力し、将来の migration 検証の基準にする
 * (Codexレビュー: v1 スキーマこそ migration の起点)。room.schemaLocation は build.gradle.kts の ksp arg。
 */
@Database(entities = [WorkoutRecordEntity::class], version = 1, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun workoutDao(): WorkoutDao
}
