package com.goexercise.app.domain

/** 1 日の達成状態。iOS `DailyStatus` の移植(symbol / countsAsAchieved を含む)。 */
enum class DailyStatus(val symbol: String) {
    Achieved("○"),
    Rest("休"),
    Missed("×"),
    Future("-"),
    TodayPending("・"),
    TodayAchieved("◎");

    val countsAsAchieved: Boolean
        get() = this == Achieved || this == Rest || this == TodayAchieved
}

/** 連続記録の集計。iOS `StreakState` の移植。 */
data class StreakState(
    val currentStreak: Int,
    val longestStreak: Int,
    val lastAchievedDate: java.time.LocalDate?,
)

/** 週間達成率。iOS `WeeklyProgress` の移植。 */
data class WeeklyProgress(
    val achievedCount: Int,
    val totalDays: Int,
) {
    val rate: Double
        get() = if (totalDays > 0) achievedCount.toDouble() / totalDays.toDouble() else 0.0
}
