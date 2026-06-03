package com.goexercise.app.presentation.record

import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import java.time.LocalDate
import java.util.UUID

/**
 * 記録入力フォームの 1 種目分の下書き。iOS `RecordEntryViewModel.ExerciseDraft` の移植。
 * 数値はフォーム入力なので String で保持し、保存時に Int 化(空/0/非数値 = 未設定)。
 * v1 はカテゴリを記録単位(RecordUiState.category)で持つ。種目ごとカテゴリは後続で拡張。
 */
data class ExerciseDraft(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val minutes: String = "",
    val reps: String = "",
    val sets: String = "",
    val memo: String = "",
)

/** 記録入力画面の状態。 */
data class RecordUiState(
    val category: WorkoutCategory = WorkoutCategory.Strength,
    val drafts: List<ExerciseDraft> = listOf(ExerciseDraft()),
    val memo: String = "",
    val saved: Boolean = false,
) {
    /** 種目名が入っている下書きだけを ExerciseItem 化(iOS validExercises 相当)。 */
    fun validExercises(): List<ExerciseItem> =
        drafts.mapNotNull { d ->
            val name = d.name.trim()
            if (name.isEmpty()) return@mapNotNull null
            val durationSeconds = d.minutes.trim().toIntOrNull()?.takeIf { it > 0 }?.times(60)
            ExerciseItem(
                id = d.id,
                name = name,
                durationSeconds = durationSeconds,
                reps = d.reps.trim().toIntOrNull()?.takeIf { it > 0 },
                sets = d.sets.trim().toIntOrNull()?.takeIf { it > 0 },
                memo = d.memo.trim().ifEmpty { null },
                category = category,
            )
        }

    val canSave: Boolean get() = validExercises().isNotEmpty()

    /** 保存用 WorkoutRecord を組み立てる。有効種目が無ければ null(保存不可)。 */
    fun toRecord(date: LocalDate): WorkoutRecord? {
        val exercises = validExercises()
        if (exercises.isEmpty()) return null
        return WorkoutRecord(
            date = date,
            category = category,
            exercises = exercises,
            memo = memo.trim().ifEmpty { null },
        )
    }
}
