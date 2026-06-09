package com.goexercise.app.domain

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 1 日の達成状態。iOS `DailyStatus`(String, Codable)の移植(symbol / countsAsAchieved を含む)。
 * @SerialName で iOS rawValue(achieved/rest/...)と JSON 表現を一致させる。
 */
@Serializable
enum class DailyStatus(val symbol: String) {
    @SerialName("achieved") Achieved("○"),
    @SerialName("rest") Rest("休"),
    @SerialName("missed") Missed("×"),
    @SerialName("future") Future("-"),
    @SerialName("todayPending") TodayPending("・"),
    @SerialName("todayAchieved") TodayAchieved("◎");

    val countsAsAchieved: Boolean
        get() = this == Achieved || this == Rest || this == TodayAchieved
}

/** 1 日分の状態エントリ(週/月カレンダー用)。iOS `DailyStatusEntry` の移植。 */
data class DailyStatusEntry(
    val date: java.time.LocalDate,
    val status: DailyStatus,
    val recordIds: List<String>,
)

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
