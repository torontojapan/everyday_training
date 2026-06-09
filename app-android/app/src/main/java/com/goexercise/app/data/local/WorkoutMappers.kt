package com.goexercise.app.data.local

import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDate

/**
 * entity → domain。exercises JSON をデコード。createdAt/updatedAt はドメインに渡さない(純粋に保つ)。
 * **decode 失敗は空配列にフォールバック**(iOS と同様)。1 行の壊れた JSON や未知 enum で
 * 一覧 Flow 全体を落とさない(Json も coerceInputValues=true で未知 enum を既定値に寄せる)。
 */
fun WorkoutRecordEntity.toDomain(json: Json): WorkoutRecord =
    WorkoutRecord(
        id = id,
        date = LocalDate.ofEpochDay(dateEpochDay),
        category = WorkoutCategory.fromRaw(categoryRaw),
        exercises = runCatching {
            json.decodeFromString(ListSerializer(ExerciseItem.serializer()), exercisesJson)
        }.getOrDefault(emptyList()),
        memo = memo,
    )

/** domain → entity。exercises を JSON へ。timestamps は Repository が供給する。 */
fun WorkoutRecord.toEntity(
    json: Json,
    createdAtEpochMs: Long,
    updatedAtEpochMs: Long,
): WorkoutRecordEntity =
    WorkoutRecordEntity(
        id = id,
        dateEpochDay = date.toEpochDay(),
        categoryRaw = category.rawValue,
        exercisesJson = json.encodeToString(ListSerializer(ExerciseItem.serializer()), exercises),
        memo = memo,
        createdAtEpochMs = createdAtEpochMs,
        updatedAtEpochMs = updatedAtEpochMs,
    )
