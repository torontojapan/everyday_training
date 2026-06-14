package com.goexercise.app.domain

import java.text.Collator
import java.time.LocalDate
import java.util.Locale

/**
 * 「よく使う種目」サジェスト(純粋関数)。iOS `ExerciseHistoryProvider.topExerciseNames` の移植。
 * カテゴリで絞り、**最後に使った日の新しい順**(同日内は使用回数→名前順)で候補名を返す。
 * 記録入力の横スクロールチップに使う。
 */
object ExerciseHistoryProvider {

    private data class Suggestion(val name: String, val lastUsedDate: LocalDate, val count: Int)

    fun topExerciseNames(
        records: List<WorkoutRecord>,
        category: WorkoutCategory,
        limit: Int = 8,
    ): List<String> {
        if (limit <= 0) return emptyList()
        val collator = Collator.getInstance(Locale.JAPANESE)

        val byName = HashMap<String, Suggestion>()
        for (record in records) {
            for (item in record.exercises) {
                // 種目ごとのカテゴリで絞る(旧データは記録全体の category にフォールバック)。
                val itemCategory = item.category ?: record.category
                if (itemCategory != category) continue
                val name = item.name.trim()
                if (name.isEmpty()) continue
                val cur = byName[name]
                val lastUsed = if (cur == null || record.date.isAfter(cur.lastUsedDate)) record.date else cur.lastUsedDate
                byName[name] = Suggestion(name, lastUsed, (cur?.count ?: 0) + 1)
            }
        }

        return byName.values
            .sortedWith(
                compareByDescending<Suggestion> { it.lastUsedDate }
                    .thenByDescending { it.count }
                    .thenComparator { a, b -> collator.compare(a.name, b.name) },
            )
            .take(limit)
            .map { it.name }
    }
}
