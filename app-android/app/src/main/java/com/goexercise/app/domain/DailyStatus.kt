package com.goexercise.app.domain

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 1 日の達成状態。iOS `DailyStatus`(String, Codable)の移植(symbol / countsAsAchieved を含む)。
 * @SerialName で iOS rawValue(achieved/rest/...)と JSON 表現を一致させる。
 */
@Serializable
enum class DailyStatus(val rawValue: String, val symbol: String) {
    // ◎=実運動 / ○=保険チケット救済 / 休=休養日(iOS と一致)。
    // rawValue は iOS DailyStatus.rawValue・@SerialName と同一文字列(クロスOS契約)。
    @SerialName("achieved") Achieved("achieved", "◎"),
    @SerialName("rescued") Rescued("rescued", "○"),
    @SerialName("rest") Rest("rest", "休"),
    @SerialName("missed") Missed("missed", "×"),
    @SerialName("future") Future("future", "-"),
    @SerialName("todayPending") TodayPending("todayPending", "・"),
    @SerialName("todayAchieved") TodayAchieved("todayAchieved", "◎");

    val countsAsAchieved: Boolean
        get() = this == Achieved || this == Rescued || this == Rest || this == TodayAchieved

    companion object {
        /**
         * rawValue 文字列から復元。未知の値(将来 iOS が追加した case 等)は Future にフォールバックして
         * 配列長(月→日7要素)を保つ。drop すると後続の曜日が左にズレるため(iOS 1.3 と同じ防御)。
         */
        fun fromRaw(raw: String): DailyStatus = entries.firstOrNull { it.rawValue == raw } ?: Future
    }
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
