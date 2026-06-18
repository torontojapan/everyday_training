package com.goexercise.app.presentation.record

import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import java.time.LocalDate
import java.util.UUID

/** 数値入力の上限桁(Int overflow / 非現実値ガード)。 */
private const val MINUTES_MAX_DIGITS = 4 // 〜9999 分
private const val COUNT_MAX_DIGITS = 4   // 回数/セット 〜9999

/**
 * 記録入力フォームの 1 種目分の下書き。iOS `RecordEntryViewModel.ExerciseDraft` の移植。
 * **カテゴリは種目ごと**に持つ(1 記録に複数カテゴリ混在可。iOS と保存 JSON を一致させる)。
 * 数値はフォーム入力なので String、保存時に Int 化(空/0/非数値 = 未設定)。
 */
data class ExerciseDraft(
    val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val category: WorkoutCategory = WorkoutCategory.Strength,
    val minutes: String = "",
    val reps: String = "",
    val sets: String = "",
    /** 重さ(負荷 kg。ダンベル等)。小数可のフリー入力。iOS ExerciseDraft.loadText 移植。 */
    val loadText: String = "",
    val memo: String = "",
)

/** 記録入力画面の状態。`saved` は one-shot イベント化したので状態には持たない。 */
data class RecordUiState(
    val drafts: List<ExerciseDraft> = listOf(ExerciseDraft()),
    val memo: String = "",
    val isSaving: Boolean = false,
    val errorMessage: String? = null,
    /** 今日の体重(任意・kg のフリー入力)。iOS RecordEntryView「今日の体重 (任意)」パリティ。 */
    val weightInput: String = "",
    /** 直近の体重(入力欄下の「前回: X kg」ヒント用)。 */
    val latestWeightKg: Double? = null,
    /** 「今日は生理日」トグルの状態。周期トラッキング ON のときのみ表示・保存。 */
    val menstrualToday: Boolean = false,
    /** 周期トラッキングが有効か(設定)。OFF なら生理日トグルは出さず触らない(iOS cycleSettings.isEnabled)。 */
    val cycleTrackingEnabled: Boolean = false,
) {
    /** 今日の体重(0〜500kg のみ。空/0/範囲外/非数値は null)。iOS parsedWeight (>0 && <500) 相当。 */
    val parsedWeightKg: Double? get() = parseWeight(weightInput)
    /** 体重入力はあるが無効(0〜500 外)。保存をブロックし disabledReason を出す。iOS hasWeightInputButInvalid。 */
    val hasWeightInputButInvalid: Boolean get() = weightInput.isNotBlank() && parsedWeightKg == null
    /** 保存不可の理由(体重が無効なとき)。iOS disabledReason(info.circle 付き)相当。 */
    val weightDisabledReason: String? get() =
        if (hasWeightInputButInvalid) "体重は 0〜500 kg の数値で入力してください" else null
    /** 種目名が入っている下書きだけを ExerciseItem 化(iOS validExercises 相当)。 */
    fun validExercises(): List<ExerciseItem> =
        drafts.mapNotNull { d ->
            val name = d.name.trim()
            if (name.isEmpty()) return@mapNotNull null
            ExerciseItem(
                id = d.id,
                name = name,
                durationSeconds = d.minutes.trim().toIntOrNull()?.takeIf { it > 0 }?.times(60),
                reps = d.reps.trim().toIntOrNull()?.takeIf { it > 0 },
                sets = d.sets.trim().toIntOrNull()?.takeIf { it > 0 },
                loadKilograms = parseLoad(d.loadText),
                memo = d.memo.trim().ifEmpty { null },
                category = d.category,
            )
        }

    // iOS: canSave = !validExercises.isEmpty && !hasWeightInputButInvalid。無効な体重は保存をブロックする。
    val canSave: Boolean get() = validExercises().isNotEmpty() && !isSaving && !hasWeightInputButInvalid

    /** 保存用 WorkoutRecord。代表カテゴリは先頭の有効種目(iOS primaryCategory)。 */
    fun toRecord(date: LocalDate): WorkoutRecord? {
        val exercises = validExercises()
        if (exercises.isEmpty()) return null
        return WorkoutRecord(
            date = date,
            category = exercises.first().category ?: WorkoutCategory.Strength,
            exercises = exercises,
            memo = memo.trim().ifEmpty { null },
        )
    }

    companion object {
        fun clampDigits(input: String, max: Int): String = input.filter { it.isDigit() }.take(max)

        /** 重さ入力のサニタイズ: 数字 + 小数点1つまで、整数部は4桁・小数部は1桁まで。 */
        fun clampDecimal(input: String): String {
            val cleaned = input.replace(',', '.').filter { it.isDigit() || it == '.' }
            val dot = cleaned.indexOf('.')
            if (dot < 0) return cleaned.take(4)
            val intPart = cleaned.substring(0, dot).take(4)
            val fracPart = cleaned.substring(dot + 1).filter { it.isDigit() }.take(1)
            return "$intPart.$fracPart"
        }

        /** 重さ文字列 → kg(0 < x < 1000 のみ。空/0/範囲外/非数値は null)。iOS parsedLoad (>0 && <1000) 相当。 */
        fun parseLoad(input: String): Double? =
            input.trim().replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 && it < 1000 }

        /** 体重文字列 → kg(0 < x < 500 のみ)。iOS parsedWeight (>0 && <500) 相当。 */
        fun parseWeight(input: String): Double? =
            input.trim().replace(',', '.').toDoubleOrNull()?.takeIf { it > 0 && it < 500 }

        const val minutesMaxDigits = MINUTES_MAX_DIGITS
        const val countMaxDigits = COUNT_MAX_DIGITS
    }
}
