package com.goexercise.app.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * アプリ DB。v2 で WeightEntry(体重, premium P1.x)を追加。exportSchema=true で各版を app/schemas へ出力。
 * ⚠️ **#10(出荷)前に v1→v2 の実 Migration を書くこと**。現状 dev は fallbackToDestructiveMigration で
 * 再生成する(未リリースで本番データ無し。schemas/2.json が実 migration の基準になる)。
 */
@Database(entities = [WorkoutRecordEntity::class, WeightEntryEntity::class], version = 2, exportSchema = true)
abstract class AppDatabase : RoomDatabase() {
    abstract fun workoutDao(): WorkoutDao
    abstract fun weightDao(): WeightDao
}
