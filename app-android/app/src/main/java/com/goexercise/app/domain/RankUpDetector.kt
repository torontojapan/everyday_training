package com.goexercise.app.domain

/**
 * 昇格/週間ベースの達成イベント検知。iOS の `RankUpDetector`(UserDefaults 注入)の移植。
 * Android では永続層を `RankUpStore` インタフェースで抽象化し、JVM ユニットテスト可能にする。
 */
sealed class RankUpEvent {
    /** 称号ランクが上がった(to = 新ランク)。 */
    data class RankUp(val to: Int) : RankUpEvent()

    /** 連続日数が 7 の倍数に到達した(streak = その倍数)。 */
    data class Weekly(val streak: Int) : RankUpEvent()
}

/** 検知状態の永続化抽象(iOS UserDefaults 相当)。 */
interface RankUpStore {
    fun getInt(key: String): Int?
    fun putInt(key: String, value: Int)
}

class RankUpDetector(private val store: RankUpStore) {

    /**
     * 現在の連続日数からイベント列を評価し、状態を更新する。
     * - 昇格: newRank > lastRank で RankUp(newRank)。lastRank は変化があれば追従(降格も保存)。
     * - 週間: 7 の倍数 currentMultiple が 7 以上 かつ lastMultiple より大きいとき Weekly(currentMultiple)。
     */
    fun evaluate(currentStreak: Int): List<RankUpEvent> {
        val events = mutableListOf<RankUpEvent>()
        val streak = maxOf(0, currentStreak)

        // 昇格判定
        val lastRank = store.getInt(KEY_LAST_RANK) ?: 0
        val newRank = CatRank.of(streak).rank
        if (newRank > lastRank) {
            events.add(RankUpEvent.RankUp(newRank))
        }
        if (newRank != lastRank) {
            store.putInt(KEY_LAST_RANK, newRank)
        }

        // 週間倍数判定
        val currentMultiple = (streak / 7) * 7
        val lastMultiple = store.getInt(KEY_LAST_WEEKLY_MULTIPLE) ?: 0
        if (currentMultiple >= 7 && currentMultiple > lastMultiple) {
            events.add(RankUpEvent.Weekly(currentMultiple))
        }
        if (currentMultiple != lastMultiple) {
            store.putInt(KEY_LAST_WEEKLY_MULTIPLE, currentMultiple)
        }

        return events
    }


    companion object {
        private const val KEY_LAST_RANK = "rankup.lastRank"
        private const val KEY_LAST_WEEKLY_MULTIPLE = "rankup.lastWeeklyMultiple"
    }
}
