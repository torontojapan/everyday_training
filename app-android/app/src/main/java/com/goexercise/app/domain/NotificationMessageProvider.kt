package com.goexercise.app.domain

import java.time.LocalDate

/**
 * リマインダー通知のメッセージ(純粋関数)。iOS `NotificationMessageProvider` の移植。
 * 性格(personality)・連続日数・今週の達成率・スロット(朝/夕)で文言を出し分け、
 * 発火日の日番号で日替わりローテーションする(同じ文言が連日続かない)。
 */
object NotificationMessageProvider {

    private val quiet = listOf(
        "🐱「今日まだ間に合うよ。1分だけ」",
        "🐱「ふと思い出したら、また会いに来てね」",
        "🐱「気が向いたら 1 種目だけ残そ？」",
        "🐱「無理しなくていい、ちょっとだけ」",
    )
    private val goodWeek = listOf(
        "🐱「今週いい感じだよ。今日も続けよ？」",
        "🐱「あと少しで今週の達成率が上がるよ」",
        "🐱「今週の流れ、守っていこ？」",
        "🐱「いい調子。今日もちょこっとやろ？」",
        "🐱「今週のがんばり、まだ伸ばせるね」",
        "🐱「このペース、続けたら週末いい気分だよ」",
        "🐱「今日もちょっとだけ、いつもの調子で」",
        "🐱「今週の自分、すでにえらいよ」",
        "🐱「いい流れ、もう一日プラスしてみよ？」",
    )
    private val keepStreak = listOf(
        "🐱「今日の連続記録、まだ守れるよ」",
        "🐱「あと少しで今日の記録が残せるよ」",
        "🐱「今日の記録、まだ待ってるよ」",
        "🐱「1分だけでも続けたら連続記録キープだよ」",
        "🐱「今日のぶん、まだ間に合うよ」",
        "🐱「お疲れさま。ストレッチ1つで OK だよ」",
        "🐱「寝る前に1種目だけ、どう？」",
        "🐱「今日も会えてうれしい。記録残そ？」",
        "🐱「焦らなくていい、自分のペースで残そ」",
    )
    private val gentle = listOf(
        "🐱「今日の運動、そろそろ一緒にやろ？」",
        "🐱「1分だけでも記録しよ？」",
        "🐱「今日も少しだけ体を動かしてみよ？」",
        "🐱「無理しなくていいから、ちょっとだけやろ？」",
        "🐱「ストレッチ1つでも OK だよ」",
        "🐱「今日も一緒に体動かそ？」",
        "🐱「軽くでいいから、はじめてみよ」",
        "🐱「やる気が出ないときほど、1分だけ」",
        "🐱「気が向いたタイミングで OK だよ」",
        "🐱「今日もそばにいるよ、待ってるね」",
    )

    fun message(
        slot: NotificationSlot,
        personality: NotificationPersonality = NotificationPersonality.Voice,
        currentStreak: Int,
        weeklyProgressRate: Double,
        seedDate: LocalDate,
    ): String {
        val day = seedDate.toEpochDay().toInt()
        if (personality == NotificationPersonality.Quiet) {
            return quiet[Math.floorMod(day, quiet.size)]
        }
        val messages = when {
            weeklyProgressRate >= 0.5 -> goodWeek
            slot == NotificationSlot.Evening || currentStreak > 0 -> keepStreak
            else -> gentle
        }
        val slotOffset = if (slot == NotificationSlot.Morning) 0 else 1
        return messages[Math.floorMod(day + slotOffset, messages.size)]
    }
}
