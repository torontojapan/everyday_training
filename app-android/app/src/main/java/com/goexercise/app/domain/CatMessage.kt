package com.goexercise.app.domain

import java.time.LocalDate

/** 猫の吹き出しメッセージ。iOS `CatMessage` の移植。 */
data class CatMessage(val emoji: String, val text: String)

/**
 * 猫の状態ごとのメッセージを日替わりで返す。iOS `CatMessageProvider`(state 版)の移植。
 * 日替わり選択は iOS の `calendar.ordinality(.day,.era)` の代わりに `LocalDate.toEpochDay()` を使う
 * (ローカル装飾なので「日ごとに決定的に変わる」性質が保てればよい)。
 */
object CatMessageProvider {

    fun message(state: CatState, seedDate: LocalDate): CatMessage {
        val messages = messagesFor(state)
        return CatMessage(emoji = state.emoji, text = pick(messages, seedDate))
    }

    private fun messagesFor(state: CatState): List<String> = when (state) {
        CatState.WaitingMorning -> listOf(
            "今日も1分だけやってみよ？",
            "今日も少しだけ体を動かしてみよ？",
            "おはよう。気が向いたら一緒にやろ？",
            "ストレッチ1つから始めても OK だよ",
            "今日もそばにいるよ。マイペースで",
            "朝の体、起こしてあげよ？",
        )
        CatState.WorriedNoon -> listOf(
            "そろそろ一緒に体を動かそ？",
            "無理しなくていいから、ちょっとだけやろ？",
            "今のうちに、1種目だけでも",
            "お昼の合間に、ストレッチどう？",
            "1分でいいから、はじめてみない？",
            "気軽にいこ。続けることが大事だよ",
        )
        CatState.BeggingNight -> listOf(
            "今日の連続記録、まだ守れるよ",
            "あと少しで今日の記録が残せるよ",
            "1種目だけ、お願い…!",
            "寝る前にストレッチだけでも OK だよ",
            "焦らなくていい、1分で十分だよ",
            "今日のぶん、まだ間に合うよ",
        )
        CatState.Celebrating -> listOf(
            "今日も達成！えらい！",
            "1分でも続けたのがすごいよ",
            "今日の記録、ちゃんと残せたね",
            "いい感じ！また明日も待ってるね",
            "やったね、お疲れさま",
            "今日の自分、最高だよ",
            "ちゃんとできた、それがすごい",
            "がんばった分、ご褒美時間だね",
            "今日もえらい、ほんとに",
            "また明日も、ちょっとだけ一緒に",
        )
        CatState.StreakExtended -> listOf(
            "連続記録更新！すごいよ",
            "今日も続いたね。大成功！",
            "いい流れ、ちゃんと守れたね",
            "新記録おめでとう！",
            "ここまで続いたの、ほんとにすごい",
            "コツコツが力になってるね",
            "今日のおかげでまた1日伸びたよ",
            "この調子で、また明日も会お？",
        )
        CatState.Resting -> listOf(
            "今日は回復日だね",
            "休むことも継続の一部だよ",
            "明日に向けて整えよう",
            "無理しないのも大事だよ",
            "ゆっくりしていいよ、おつかれさま",
            "体を休めるのも立派な習慣",
            "今日はリセットの日。気にしないで",
            "また明日、待ってるね",
        )
        CatState.Encouraging -> listOf(
            "今日からまた一緒に始めよ？",
            "少しだけ体を動かしてみない？",
            "今ならまだ間に合うよ",
            "気にしない気にしない、また今日から",
            "1分でいいよ、はじめの一歩",
            "焦らなくていい、自分のペースで",
            "今日が新しいスタートだね",
            "やる気の波は誰でもあるよ、大丈夫",
        )
    }

    private fun pick(messages: List<String>, seedDate: LocalDate): String {
        if (messages.isEmpty()) return "今日もそばにいるよ"
        val day = seedDate.toEpochDay()
        val index = (Math.floorMod(day, messages.size.toLong())).toInt()
        return messages[index]
    }
}
