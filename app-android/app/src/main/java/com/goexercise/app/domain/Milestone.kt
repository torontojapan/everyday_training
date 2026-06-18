package com.goexercise.app.domain

import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * 達成の節目。iOS `Milestone` の移植。weightLoss は体重(#9)が揃ったら発火する(snapshot 経由)。
 */
sealed interface Milestone {
    data class Anniversary(val years: Int) : Milestone
    data class LifetimeDays(val days: Int) : Milestone
    data class CurrentStreak(val days: Int) : Milestone
    data class WeightLoss(val kg: Int) : Milestone

    val headline: String
        get() = when (this) {
            is Anniversary -> "${years}周年おめでとう！"
            is LifetimeDays -> "累計 $days 日達成！"
            is CurrentStreak -> "連続 $days 日達成！"
            is WeightLoss -> "-${kg}kg 達成！"
        }

    val detail: String
        get() = when (this) {
            is Anniversary -> "GO エクササイズを始めてから${years}周年です。ここまでよくがんばったね！"
            is LifetimeDays -> "通算 $days 日の運動を達成しました。続けることに大きな意味があります。"
            is CurrentStreak -> "$days 日連続で運動を続けています。すごい習慣力！"
            is WeightLoss -> "開始時から -${kg}kg。コツコツ続けてきた結果だね。"
        }

    /** SNS シェア本文(末尾に URL は付けない=ShareLink/Intent 側で付与)。iOS shareMessage と同文。 */
    val shareMessage: String
        get() = when (this) {
            is Anniversary -> "GO エクササイズ ${years}周年達成！ねこ達とゆるく運動習慣を続けてます。一緒にやろう"
            is LifetimeDays -> "GO エクササイズで通算 $days 日達成！ねこ達とゆるく続けてます。一緒にやろう"
            is CurrentStreak -> "GO エクササイズで $days 日連続達成！ねこ達とゆるく運動習慣つくってます"
            is WeightLoss -> "GO エクササイズで -${kg}kg 達成！ねこ達と一緒にコツコツ続けた結果"
        }

    /** acknowledged 永続化のキー。iOS key(for:) と一致。 */
    val key: String
        get() = when (this) {
            is Anniversary -> "anniv.$years"
            is LifetimeDays -> "lifetime.$days"
            is CurrentStreak -> "streak.$days"
            is WeightLoss -> "weightLoss.$kg"
        }
}

/**
 * 達成節目の検出(純粋)。iOS `MilestoneDetector` の判定部を移植。永続化(acknowledged/migration)は
 * data 層の MilestoneRepository に分離する。
 */
object MilestoneDetector {

    /** 体重節目の入力(体重ストアに非依存に保つためのスナップショット)。iOS WeightLossSnapshot。 */
    data class WeightLossSnapshot(val startKg: Double?, val currentKg: Double?, val isLossGoal: Boolean?)

    /**
     * `currentStreak` が達した streak 節目を昇順で返す。`[10, 30, 50, 100, 200, ... 2000]`。
     * 100 以降は 100 単位、現実的上限 2000(≒5年半連続)で打ち切る。iOS と同一。
     */
    fun currentStreakMilestones(upTo: Int): List<Int> {
        if (upTo < 10) return emptyList()
        val result = mutableListOf<Int>()
        for (t in listOf(10, 30, 50)) if (upTo >= t) result.add(t)
        var t = 100
        while (t <= 2000 && upTo >= t) {
            result.add(t)
            t += 100
        }
        return result
    }

    /** 現時点で達成済みの全候補(anniversary→lifetime→streak→weightLoss の優先順)。iOS candidates と同順。 */
    fun candidates(
        firstUseDate: LocalDate?,
        today: LocalDate,
        lifetimeAchieved: Int,
        currentStreak: Int,
        weightLoss: WeightLossSnapshot? = null,
    ): List<Milestone> {
        val result = mutableListOf<Milestone>()
        if (firstUseDate != null) {
            val years = ChronoUnit.YEARS.between(firstUseDate, today).toInt()
            if (years >= 1) result.add(Milestone.Anniversary(years))
        }
        for (target in listOf(100, 365, 500, 1000)) {
            if (lifetimeAchieved >= target) result.add(Milestone.LifetimeDays(target))
        }
        for (target in currentStreakMilestones(currentStreak)) {
            result.add(Milestone.CurrentStreak(target))
        }
        if (weightLoss != null) {
            for (kg in WeightLossMilestoneDetector.reachedThresholds(weightLoss.startKg, weightLoss.currentKg, weightLoss.isLossGoal)) {
                result.add(Milestone.WeightLoss(kg))
            }
        }
        return result
    }

    /** まだ祝っていない最初の節目(優先順=candidates 順)。iOS nextPending 相当。 */
    fun nextPending(candidates: List<Milestone>, acknowledged: Set<String>): Milestone? =
        candidates.firstOrNull { it.key !in acknowledged }
}

/**
 * 体重節目(weightLoss)検出(純粋)。iOS `WeightLossMilestoneDetector` 移植。
 * 開始時 - 現在で達した -kg 節目を昇順で返す。減量目標(isLossGoal==true)のみ発火。
 */
object WeightLossMilestoneDetector {
    fun reachedThresholds(
        startKg: Double?,
        currentKg: Double?,
        isLossGoal: Boolean?,
        thresholds: List<Int> = listOf(3, 5, 10),
    ): List<Int> {
        if (startKg == null || currentKg == null || isLossGoal != true) return emptyList()
        val lost = startKg - currentKg
        if (lost <= 0) return emptyList()
        return thresholds.filter { it <= lost }
    }
}
