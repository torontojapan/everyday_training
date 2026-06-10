package com.goexercise.app.domain

import java.time.LocalDate

/**
 * 連続記録のフリーズ(保険チケット)復活判定。iOS `StreakFreezeWindow` の純ロジック移植。
 *
 * 「直近に途切れた連続記録を、フリーズ(課金チケット)で復活できるか」を評価する。
 * 純判定層(`Decision`)と、記録から状態列を組み立てる層を分ける(前者は完全に純粋でテスト容易)。
 */
object StreakFreezeWindow {

    /**
     * 復活判定の結果。
     * @param revivable 復活可能(過去に達成があり、間に Missed が挟まる)か。
     * @param missedOffsets 復活に必要な Missed の日オフセット(1=昨日, 2=一昨日…)。
     * @param freezesNeeded 必要なフリーズ枚数(= missedOffsets.size)。
     * @param hasEnough 手持ちフリーズが必要数以上か。
     */
    data class Result(
        val revivable: Boolean,
        val missedOffsets: List<Int>,
        val freezesNeeded: Int,
        val hasEnough: Boolean,
    )

    /**
     * 純判定層。statuses[0]=offset1(昨日), [1]=offset2(一昨日)… の順。
     * statuses は offset 1..(lookback+1) を想定(アンカー検出用に 1 件余分に渡す)。
     * offset = index+1 として走査する。
     *
     * - Achieved / TodayAchieved → 過去の達成(アンカー)を発見し打ち切る(foundPrior=true)。
     * - Rest → スキップ(フリーズ不要、連続も切れない)。
     * - Missed → offset <= lookback なら復活対象として収集。それを超えていれば猶予枠超過で
     *   tooOld=true として打ち切る(lookback ちょうどの途切れは復活可能、それより古いと不可)。
     * - その他(Future / TodayPending)→ 走査打ち切り。
     *
     * revivable = アンカーあり && !tooOld && Missed が 1 件以上。
     */
    object Decision {
        fun evaluate(
            statuses: List<DailyStatus>,
            remainingFreezes: Int,
            lookback: Int,
        ): Result {
            val missedOffsets = mutableListOf<Int>()
            var foundPrior = false
            var tooOld = false

            run {
                statuses.forEachIndexed { idx, status ->
                    val offset = idx + 1
                    when (status) {
                        DailyStatus.Achieved, DailyStatus.TodayAchieved -> {
                            foundPrior = true
                            return@run
                        }
                        DailyStatus.Rest -> {
                            // skip — フリーズ不要、連続も切れない
                        }
                        DailyStatus.Missed -> {
                            if (offset <= lookback) {
                                missedOffsets.add(offset)
                            } else {
                                // 猶予枠を超える途切れ → 復活不可
                                tooOld = true
                                return@run
                            }
                        }
                        else -> {
                            // Future / TodayPending → 打ち切り
                            return@run
                        }
                    }
                }
            }

            val revivable = foundPrior && !tooOld && missedOffsets.isNotEmpty()
            if (!revivable) {
                return Result(
                    revivable = false,
                    missedOffsets = emptyList(),
                    freezesNeeded = 0,
                    hasEnough = false,
                )
            }

            val needed = missedOffsets.size
            return Result(
                revivable = true,
                missedOffsets = missedOffsets.toList(),
                freezesNeeded = needed,
                hasEnough = remainingFreezes >= needed,
            )
        }
    }

    /**
     * 記録から状態列(offset 1..(lookback+1))を組み立てて判定を委譲する。
     * アンカー(直前の達成日)を見つけられるよう lookback より 1 件余分に遡る。
     */
    fun evaluate(
        records: List<WorkoutRecord>,
        today: LocalDate,
        rescuedDates: Set<LocalDate>,
        remainingFreezes: Int,
        lookback: Int = 4,
    ): Result {
        val statuses = (1..(lookback + 1)).map { offset ->
            val date = today.minusDays(offset.toLong())
            val restDays = RestDayResolver.restDaySet(date, records, today)
            AchievementEvaluator.dailyStatus(
                date = date,
                records = records,
                restDays = restDays,
                rescuedDates = rescuedDates,
                today = today,
            )
        }
        return Decision.evaluate(statuses, remainingFreezes, lookback)
    }

    /** Missed オフセット群を実日付へ変換。 */
    fun missedDatesForOffsets(offsets: List<Int>, today: LocalDate): List<LocalDate> =
        offsets.map { today.minusDays(it.toLong()) }
}
