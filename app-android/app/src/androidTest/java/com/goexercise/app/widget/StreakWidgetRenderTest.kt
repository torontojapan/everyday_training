package com.goexercise.app.widget

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import org.junit.Test
import java.io.File

/**
 * ウィジェット(systemSmall 相当)の **実描画** を PNG 出力して iOS golden と横並び照合するための
 * instrumented テスト。代表 3 状態(未達成/達成/回復日)を externalFilesDir に書き出す(adb pull で取得)。
 */
class StreakWidgetRenderTest {

    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext

    private fun catRes(state: CatState): Int {
        fun id(name: String) = ctx.resources.getIdentifier(name, "drawable", ctx.packageName)
        return id(CatBreed.Default.assetName(state)).takeIf { it != 0 }
            ?: id(CatBreed.fallbackAssetName(state)).takeIf { it != 0 }
            ?: id(CatBreed.FALLBACK_AVATAR)
    }

    // connectedAndroidTest はテスト後にアプリを uninstall するため filesDir は消える。
    // MediaStore(Pictures/GOExercise)へ保存して adb pull で取り出せるようにする(共有ストレージは残る)。
    private fun save(name: String, bmp: Bitmap) {
        val values = android.content.ContentValues().apply {
            put(android.provider.MediaStore.Images.Media.DISPLAY_NAME, name)
            put(android.provider.MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
                put(android.provider.MediaStore.Images.Media.RELATIVE_PATH, "Pictures/GOExercise")
            }
        }
        val resolver = ctx.contentResolver
        val uri = resolver.insert(android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)!!
        resolver.openOutputStream(uri)!!.use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }

    @Test
    fun renders_widget_states_to_png() {
        // iPhone 17 Pro Max の systemSmall は約 170pt 角 → @3x 相当で 510px 角に描いて比較する。
        val px = 510
        val cases = listOf(
            Triple(
                "widget_pending",
                StreakWidgetRenderer.Data(catRes(CatState.WaitingMorning), CatState.WaitingMorning, 12, todayAchieved = false, isRestDay = false, weeklyAchieved = 4, weeklyTotal = 7, hoursLeft = 9),
                Unit,
            ),
            Triple(
                "widget_achieved",
                StreakWidgetRenderer.Data(catRes(CatState.Celebrating), CatState.Celebrating, 13, todayAchieved = true, isRestDay = false, weeklyAchieved = 5, weeklyTotal = 7, hoursLeft = 9),
                Unit,
            ),
            Triple(
                "widget_rest",
                StreakWidgetRenderer.Data(catRes(CatState.Resting), CatState.Resting, 12, todayAchieved = false, isRestDay = true, weeklyAchieved = 4, weeklyTotal = 7, hoursLeft = 9),
                Unit,
            ),
        )
        cases.forEach { (name, data, _) ->
            val bmp = StreakWidgetRenderer.render(ctx, px, px, data)
            assert(bmp.width == px && bmp.height == px)
            save("$name.png", bmp)
        }
    }
}
