package com.goexercise.app.data.friends

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `ProfileRow.toProfile()` の today_exercise_details デコード(C7・iOS パリティ)。
 * summary は iOS `SharedExerciseDetail.summary` と完全一致の形式であることを固定する。
 */
class ProfileRowDecodeTest {

    private fun row(details: List<SharedExerciseDetailRow>?) = ProfileRow(
        userId = "u1",
        friendCode = "ABC234",
        todayExerciseDetails = details,
    )

    @Test
    fun decodes_structured_details_with_ios_summary_format() {
        val profile = row(
            listOf(
                SharedExerciseDetailRow(name = "スクワット", reps = 20, sets = 3),
                SharedExerciseDetailRow(name = "ベンチプレス", durationMinutes = 20, reps = 10, sets = 3),
                SharedExerciseDetailRow(name = "プランク", durationMinutes = 2),
            ),
        ).toProfile()

        val d = profile.todayExerciseDetails!!
        assertEquals(3, d.size)
        assertEquals("スクワット", d[0].name)
        assertEquals("20回 × 3セット", d[0].summary)
        // reps&sets + duration は " / " 連結。
        assertEquals("10回 × 3セット / 20分", d[1].summary)
        // duration のみ。
        assertEquals("2分", d[2].summary)
    }

    @Test
    fun reps_only_and_sets_only_summaries() {
        val d = row(
            listOf(
                SharedExerciseDetailRow(name = "腕立て", reps = 15),
                SharedExerciseDetailRow(name = "懸垂", sets = 4),
            ),
        ).toProfile().todayExerciseDetails!!
        assertEquals("15回", d[0].summary)
        assertEquals("4セット", d[1].summary)
    }

    @Test
    fun empty_list_decodes_to_null() {
        assertNull(row(emptyList()).toProfile().todayExerciseDetails)
    }

    @Test
    fun null_details_decode_to_null() {
        assertNull(row(null).toProfile().todayExerciseDetails)
    }
}
