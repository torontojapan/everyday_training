package com.goexercise.app.domain

import java.time.LocalDate
import java.util.UUID

/**
 * 運動記録のドメインモデル(純粋ロジック用)。iOS `WorkoutRecord` の値部分の移植。
 *
 * 日付は **`LocalDate`(暦日)** で持つ。iOS は `Date` を `startOfDay` に丸めて保持するが、
 * ストリーク/達成判定は暦日単位なので Android は最初から LocalDate を正本にする
 * (タイムゾーン依存を排除し iOS と同入力同出力を担保)。Room 永続層では epochDay で保存する。
 */
data class WorkoutRecord(
    val id: String = UUID.randomUUID().toString(),
    val date: LocalDate,
    val category: WorkoutCategory,
    val exercises: List<ExerciseItem>,
    val memo: String? = null,
)
