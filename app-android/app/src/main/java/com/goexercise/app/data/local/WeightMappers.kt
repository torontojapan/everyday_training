package com.goexercise.app.data.local

import com.goexercise.app.domain.WeightEntry
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneOffset

/**
 * WeightEntryEntity ↔ domain WeightEntry の変換。`recordedAt` は壁時計の LocalDateTime であり、
 * **固定 UTC で serialize** する(端末のタイムゾーンが変わっても壁時計の年月日時が完全に round-trip し、
 * 日付グルーピング/履歴日付/期間窓がズレない。systemDefault を使うと TZ 変更で日付が動く)。
 * recordedAtEpochMs は実 instant ではなく「UTC 解釈した壁時計値」だが、順序は壁時計と単調一致する。
 */
fun WeightEntryEntity.toDomain(): WeightEntry = WeightEntry(
    id = id,
    recordedAt = LocalDateTime.ofInstant(Instant.ofEpochMilli(recordedAtEpochMs), ZoneOffset.UTC),
    weightKg = weightKg,
    memo = memo,
    createdAtMillis = createdAtEpochMs,
)

fun WeightEntry.toEntity(
    createdAt: Long = createdAtMillis,
    updatedAt: Long = createdAtMillis,
): WeightEntryEntity = WeightEntryEntity(
    id = id,
    recordedAtEpochMs = recordedAt.toInstant(ZoneOffset.UTC).toEpochMilli(),
    weightKg = weightKg,
    memo = memo,
    createdAtEpochMs = createdAt,
    updatedAtEpochMs = updatedAt,
)
