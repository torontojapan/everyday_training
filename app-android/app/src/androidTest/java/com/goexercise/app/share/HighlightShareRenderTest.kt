package com.goexercise.app.share

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.MonthlyReviewBuilder
import com.goexercise.app.domain.WorkoutCategory
import kotlinx.coroutines.runBlocking
import org.junit.Test

/**
 * ハイライト共有カードの **実描画** を出力して目視検証するための instrumented テスト。
 * 各 Kind の PNG を app の externalFilesDir に書き出す(adb pull で取り出してレイアウト確認)。
 * アサーションは「非 null・期待サイズ」の最低限のみ(主目的は視覚成果物の生成)。
 */
class HighlightShareRenderTest {

    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext

    private fun sampleReview() = MonthlyReviewBuilder.Review(
        periodLabel = "2026年6月",
        achievedDays = 18,
        totalDays = 30,
        longestStreak = 9,
        totalDurationMinutes = 420,
        totalExerciseCount = 54,
        topCategory = WorkoutCategory.Strength,
        topExerciseName = "ブルガリアンスクワット(かなり長い種目名のテスト)",
    )

    @Test
    fun renders_all_three_kinds_to_png() = runBlocking {
        HighlightShareImageRenderer.Kind.entries.forEach { kind ->
            // サイズ検証(最低限のアサーション)。
            val bmp: Bitmap = HighlightShareImageRenderer.render(
                ctx, sampleReview(), kind, CatBreed.Default, "最長連続", poseSeed = 42,
            )
            assert(bmp.width == 1080 && bmp.height == 2340)
            // MediaStore(Pictures/GOExercise)へ保存。アンインストール後も残り adb pull で取り出せる。
            val ok = HighlightShareImageRenderer.saveToGallery(
                ctx, sampleReview(), kind, CatBreed.Default, "最長連続", poseSeed = 42,
            )
            assert(ok)
        }
    }
}
