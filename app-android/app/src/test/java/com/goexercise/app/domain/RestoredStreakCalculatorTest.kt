package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate

/**
 * [RestoredStreakCalculator] の検証。3LLM監査で見つかった「今日が既に達成済みのとき復元後 streak が
 * 取りこぼす」バグの回帰テストを含む(iOS `restoredStreakLength` パリティ)。
 */
class RestoredStreakCalculatorTest {

    private fun achieved(date: LocalDate): WorkoutRecord =
        WorkoutRecord(
            date = date,
            category = WorkoutCategory.Strength,
            exercises = listOf(ExerciseItem(name = "腕立て", durationSeconds = 120)),
        )

    /**
     * 週(月曜起点)の先頭2日(月・火)を未達成にして自動休息枠を使い切らせ、
     * 対象の gap 日が **Rest ではなく Missed** になるようにする。
     * 月=休息, 火=休息, 水=達成, 木=missed(gap), 金=今日=達成。
     * 復活で木を橋渡しすると、現連続は 水・木(救済)・金 = 3 になるべき。
     * 旧実装は最新 missed(木)起点で後方しか数えず金(今日達成)を取りこぼし 2 を返していた。
     */
    @Test
    fun `counts today when today already achieved (revive bridges gap)`() {
        val mon = LocalDate.of(2026, 6, 1)
        val tue = mon.plusDays(1)
        val wed = mon.plusDays(2)
        val thu = mon.plusDays(3) // missed gap
        val fri = mon.plusDays(4) // today, achieved
        val today = fri
        // 月・火は記録なし(=未達成→自動休息で消費)。水・金は達成。木は記録なし(=missed)。
        val records = listOf(achieved(wed), achieved(fri))
        // 木のオフセット = today(金) - 木 = 1
        val thuOffset = (today.toEpochDay() - thu.toEpochDay()).toInt() // 1
        val result = RestoredStreakCalculator.restoredStreakLength(
            records = records,
            rescued = emptySet(),
            missedOffsets = listOf(thuOffset),
            today = today,
        )
        assertEquals(3, result) // 水 + 木(救済) + 金(今日) = 3(旧実装は 2)
    }

    /**
     * 今日が未達成(TodayPending)のケースでは最新 missed 起点のまま(今日を数えない)。
     * 月=休息, 火=休息, 水=達成, 木=missed(gap), 金=今日=未達成。
     * 復活で木を橋渡し → 守られるのは 水・木(救済) = 2(今日は未達成なので含めない)。
     */
    @Test
    fun `anchors at latest missed when today pending`() {
        val mon = LocalDate.of(2026, 6, 1)
        val wed = mon.plusDays(2)
        val thu = mon.plusDays(3) // missed gap
        val fri = mon.plusDays(4) // today, NOT achieved
        val today = fri
        val records = listOf(achieved(wed)) // 金(今日)は記録なし=未達成
        val thuOffset = (today.toEpochDay() - thu.toEpochDay()).toInt()
        val result = RestoredStreakCalculator.restoredStreakLength(
            records = records,
            rescued = emptySet(),
            missedOffsets = listOf(thuOffset),
            today = today,
        )
        assertEquals(2, result) // 水 + 木(救済)。今日(未達成)は含めない
    }

    @Test
    fun `returns 0 when no missed offsets and today pending`() {
        val today = LocalDate.of(2026, 6, 5)
        val result = RestoredStreakCalculator.restoredStreakLength(
            records = emptyList(),
            rescued = emptySet(),
            missedOffsets = emptyList(),
            today = today,
        )
        assertEquals(0, result)
    }
}
