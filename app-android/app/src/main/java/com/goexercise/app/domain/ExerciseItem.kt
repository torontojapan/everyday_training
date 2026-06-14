package com.goexercise.app.domain

import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * 1 種目。iOS `ExerciseItem.swift` の移植。category は種目ごとに保持(1記録に複数カテゴリ混在可)。
 * 旧データ(フィールドなし)は null になり、表示時に記録全体の category へフォールバックする。
 * Room の exercises JSON 列に kotlinx.serialization で格納する。
 */
@Serializable
data class ExerciseItem(
    val id: String = UUID.randomUUID().toString(),
    val name: String,
    val durationSeconds: Int? = null,
    val reps: Int? = null,
    val sets: Int? = null,
    val memo: String? = null,
    /** 重さ(負荷 kg。ダンベル等)。iOS `loadKilograms` と同名キー。クラウドバックアップの
     *  クロスOS往復でフィールドを落とさないため、入力 UI 未実装でも保持・再エンコードする。 */
    val loadKilograms: Double? = null,
    val category: WorkoutCategory? = null,
)
