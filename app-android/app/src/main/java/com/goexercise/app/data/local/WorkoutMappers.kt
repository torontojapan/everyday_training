package com.goexercise.app.data.local

import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.domain.WorkoutRecord
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.time.LocalDate

/** entity → domain。exercises JSON をデコード。createdAt/updatedAt はドメインに渡さない(純粋に保つ)。 */
fun WorkoutRecordEntity.toDomain(json: Json): WorkoutRecord =
    WorkoutRecord(
        id = id,
        date = LocalDate.ofEpochDay(dateEpochDay),
        category = WorkoutCategory.fromRaw(categoryRaw),
        exercises = json.decodeFromString(ListSerializer(ExerciseItem.serializer()), exercisesJson),
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
