package com.goexercise.app.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/**
 * iOS `RestDayResolverTests.swift` の移植。
 * iOS は `restDays(in: week,...)` に DateInterval を渡すが、Kotlin は週起点(月曜)で表現するため
 * `RestDayResolver.weekStart(today)` を渡す。
 */
class RestDayResolverTest {

    @Test
    fun firstTwoUnrecordedPastDaysBecomeRestDays() {
        val today = date(22)
        val records = listOf(record(18), record(21))

        val restDays = RestDayResolver.restDays(RestDayResolver.weekStart(today), records, today)

        assertEquals(listOf(date(19), date(20)), restDays)
    }

    @Test
    fun thirdUnrecordedDayIsNotRestDay() {
        val today = date(22)
        val records = listOf(record(18))

        val restDays = RestDayResolver.restDays(RestDayResolver.weekStart(today), records, today)

        assertFalse(restDays.contains(date(21)))
    }

    @Test
    fun futureDaysAreNotRestDays() {
        val today = date(20)
        val records = listOf(record(18))

        val restDays = RestDayResolver.restDays(RestDayResolver.weekStart(today), records, today)

        assertFalse(restDays.contains(date(21)))
    }

    @Test
    fun limitZeroReturnsNoRestDays() {
        val today = date(20)

        val restDays = RestDayResolver.restDays(RestDayResolver.weekStart(today), emptyList(), today, limit = 0)

        assertTrue(restDays.isEmpty())
    }

    @Test
    fun unachievedRecordsDoNotBlockRestDay() {
        val today = date(20)
        val emptyRecord = WorkoutRecord(date = date(18), category = WorkoutCategory.Strength, exercises = emptyList())

        val restDays = RestDayResolver.restDays(RestDayResolver.weekStart(today), listOf(emptyRecord), today)

        assertTrue(restDays.contains(date(18)))
    }

    private fun record(day: Int): WorkoutRecord =
        WorkoutRecord(date = date(day), category = WorkoutCategory.Strength, exercises = listOf(ExerciseItem(name = "運動")))

    private fun date(day: Int): LocalDate = LocalDate.of(2026, 5, day)
}
