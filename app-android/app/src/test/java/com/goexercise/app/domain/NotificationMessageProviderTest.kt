package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class NotificationMessageProviderTest {

    private val day = LocalDate.of(2026, 5, 20)

    @Test
    fun quietPersonality_usesQuietBucket() {
        val msg = NotificationMessageProvider.message(
            NotificationSlot.Evening, NotificationPersonality.Quiet, currentStreak = 5, weeklyProgressRate = 0.9, seedDate = day,
        )
        // quiet バケットは「今週いい感じ」等の達成率系を出さない(静かなトーン)。
        assertTrue(msg.contains("1分だけ") || msg.contains("ちょっと") || msg.contains("会いに来て") || msg.contains("1 種目"))
        assertTrue(!msg.contains("今週いい感じ"))
    }

    @Test
    fun goodWeek_usesGoodWeekBucket() {
        val msg = NotificationMessageProvider.message(
            NotificationSlot.Morning, NotificationPersonality.Voice, currentStreak = 0, weeklyProgressRate = 0.8, seedDate = day,
        )
        // 週達成率>=0.5 は維持促進トーン(「今週」を含む文言群)。
        assertTrue(msg.contains("今週") || msg.contains("いい調子") || msg.contains("いい流れ") || msg.contains("このペース"))
    }

    @Test
    fun streakOrEvening_usesKeepStreakBucket() {
        val msg = NotificationMessageProvider.message(
            NotificationSlot.Evening, NotificationPersonality.Voice, currentStreak = 3, weeklyProgressRate = 0.1, seedDate = day,
        )
        assertTrue(msg.contains("連続") || msg.contains("記録") || msg.contains("間に合う") || msg.contains("ストレッチ") || msg.contains("寝る前"))
    }

    @Test
    fun morningNoStreak_usesGentleBucket() {
        val msg = NotificationMessageProvider.message(
            NotificationSlot.Morning, NotificationPersonality.Voice, currentStreak = 0, weeklyProgressRate = 0.0, seedDate = day,
        )
        assertTrue(msg.startsWith("🐾"))   // 種中立の肉球(犬種追加で🐱から変更)
    }

    @Test
    fun newTones_produceDistinctVoices() {
        // 同一入力でも声掛けトーンごとに文面が変わる(スパルタ/元気/クール/ツンデレ)。
        val inputs = Triple(NotificationSlot.Morning, 0, 0.0)
        val voice = NotificationMessageProvider.message(inputs.first, NotificationPersonality.Voice, inputs.second, inputs.third, day)
        val spartan = NotificationMessageProvider.message(inputs.first, NotificationPersonality.Spartan, inputs.second, inputs.third, day)
        val cheer = NotificationMessageProvider.message(inputs.first, NotificationPersonality.Cheer, inputs.second, inputs.third, day)
        val cool = NotificationMessageProvider.message(inputs.first, NotificationPersonality.Cool, inputs.second, inputs.third, day)
        val tsundere = NotificationMessageProvider.message(inputs.first, NotificationPersonality.Tsundere, inputs.second, inputs.third, day)
        // 4トーンはいずれも標準(voice)と異なる文面で、互いにも重複しない。
        val all = listOf(voice, spartan, cheer, cool, tsundere)
        assertEquals(all.size, all.toSet().size)
        all.forEach { assertTrue(it.startsWith("🐾")) }
    }

    @Test
    fun rotatesByDate() {
        // 連日で同じ文言が続かない(日番号でローテーション)。
        val a = NotificationMessageProvider.message(NotificationSlot.Morning, NotificationPersonality.Voice, 0, 0.0, LocalDate.of(2026, 5, 20))
        val b = NotificationMessageProvider.message(NotificationSlot.Morning, NotificationPersonality.Voice, 0, 0.0, LocalDate.of(2026, 5, 21))
        assertEquals(false, a == b)
    }
}
