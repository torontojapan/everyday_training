package com.goexercise.app.domain

import java.time.LocalDate

/**
 * レビュー依頼の永続状態(最終依頼日 / 依頼済み節目)。iOS は UserDefaults、Android は
 * SharedPreferences(同期)で実装する。純ロジックをテスト可能に保つためインターフェースで
 * 抽象化する([RankUpStore] と同じ方針)。
 */
interface ReviewPromptStore {
    /** 最後にレビュー依頼を出した日(epoch day)。未依頼なら null。 */
    fun lastRequestEpochDay(): Long?
    fun setLastRequestEpochDay(day: Long)
    /** これまでに依頼済みの節目(連続日数)の集合。 */
    fun promptedMilestones(): Set<Int>
    fun addPromptedMilestone(streak: Int)
}

/**
 * Play ストアのレビュー依頼を「成功体験の直後(連続記録の節目)」に控えめに出すための判定。
 * iOS `ReviewRequestController` の 1:1 移植。実際のダイアログ表示は UI 層(Play In-App Review)が
 * 担い、本型は「今出すべきか」の判断と「出した記録」だけを担う(純粋ロジックでテストしやすい)。
 *
 * 設計方針:
 * - 連続記録の節目(7 / 30 / 100 日)という明確な達成時だけ出す
 * - 一度出したら最低 90 日は出さない(Play 側も制限するが二重で抑制)
 * - 同じ節目では二度と出さない(再達成での重複を防ぐ)
 */
class ReviewRequestController(private val store: ReviewPromptStore) {

    /** この連続記録日数でレビュー依頼を出すべきか。 */
    fun shouldRequestReview(streak: Int, today: LocalDate): Boolean {
        if (streak !in MILESTONES) return false
        if (streak in store.promptedMilestones()) return false
        val last = store.lastRequestEpochDay()
        if (last != null && today.toEpochDay() - last < MIN_INTERVAL_DAYS) return false
        return true
    }

    /** 依頼を出したことを記録する(節目と日付)。 */
    fun markRequested(streak: Int, today: LocalDate) {
        store.setLastRequestEpochDay(today.toEpochDay())
        store.addPromptedMilestone(streak)
    }

    companion object {
        /** レビュー依頼を出す連続記録の節目(日数)。 */
        val MILESTONES: Set<Int> = setOf(7, 30, 100)
        /** 前回依頼からの最小間隔(日)。 */
        const val MIN_INTERVAL_DAYS: Long = 90
    }
}
