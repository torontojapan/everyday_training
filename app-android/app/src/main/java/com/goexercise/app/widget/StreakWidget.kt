package com.goexercise.app.widget

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.action.clickable
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.Image
import androidx.glance.ImageProvider
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.cornerRadius
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.layout.size
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.glance.unit.ColorProvider
import com.goexercise.app.data.WorkoutRepository
import com.goexercise.app.data.rescue.RescueTicketRepository
import com.goexercise.app.data.settings.SettingsRepository
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.presentation.home.HomeStateReducer
import dagger.hilt.EntryPoint
import dagger.hilt.InstallIn
import dagger.hilt.android.EntryPointAccessors
import dagger.hilt.components.SingletonComponent
import kotlinx.coroutines.flow.first
import java.time.Clock
import java.time.LocalDateTime

/** ウィジェットから Hilt 依存へアクセスする EntryPoint(Glance は @AndroidEntryPoint 不可のため手動取得)。 */
@EntryPoint
@InstallIn(SingletonComponent::class)
interface WidgetEntryPoint {
    fun workoutRepository(): WorkoutRepository
    fun rescueRepository(): RescueTicketRepository
    fun settingsRepository(): SettingsRepository
    fun clock(): Clock
}

/**
 * ホーム画面ウィジェット(Jetpack Glance)。連続日数 + ユーザーの猫 + 今日の達成状況を表示。
 * iOS WidgetKit の small 相当。データは Room/DataStore を直接読む(同一プロセス)。
 */
class StreakWidget : GlanceAppWidget() {

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val ep = EntryPointAccessors.fromApplication(context, WidgetEntryPoint::class.java)
        val records = ep.workoutRepository().observeRecords().first()
        val rescued = ep.rescueRepository().rescuedDates.first()
        val firstUse = ep.settingsRepository().firstUseDate.first()
        val now = LocalDateTime.now(ep.clock())
        val state = HomeStateReducer.reduce(records, now, rescuedDates = rescued, firstUseDate = firstUse)

        // 2026-06 改修: キャラ廃止 → 肉球 + 今週ストリップ表示。
        val data = StreakWidgetRenderer.Data(
            weeklyStatuses = state.weekStatuses.map { it.status },
            streak = state.streak.currentStreak,
            todayAchieved = state.todayStatus.countsAsAchieved,
            isRestDay = state.todayStatus == com.goexercise.app.domain.DailyStatus.Rest,
            weeklyAchieved = state.weeklyProgress.achievedCount,
            weeklyTotal = state.weeklyProgress.totalDays,
            hoursLeft = (23 - now.hour).coerceAtLeast(0),
            pawResId = context.resources.getIdentifier("ic_stat_paw", "drawable", context.packageName),
        )
        provideContent { WidgetBody(context, data) }
    }

    companion object {
        // Peach 系の固定色(Glance は LocalAppPalette 不可)。
        private val BG = Color(0xFFFDF1E7)
        val bgProvider = ColorProvider(BG)
    }
}

@androidx.compose.runtime.Composable
private fun WidgetBody(context: Context, data: StreakWidgetRenderer.Data) {
    // iOS SmallWidgetView の構図(猫 halo + 週リング + 見出し/サブ + 未達成 CTA・左寄せ)は Glance では描けない。
    // 同一構図を Android Canvas で 1 枚の Bitmap に描いて Image として表示する(StreakWidgetRenderer)。
    val size = androidx.glance.LocalSize.current
    val density = context.resources.displayMetrics.density
    val wPx = (size.width.value * density).toInt().coerceIn(120, 1600)
    val hPx = (size.height.value * density).toInt().coerceIn(120, 1600)
    val bmp = StreakWidgetRenderer.render(context, wPx, hPx, data)
    Image(
        provider = ImageProvider(bmp),
        contentDescription = "${data.streak}日連続",
        modifier = GlanceModifier
            .fillMaxSize()
            .clickable(actionStartActivity(android.content.Intent(context, com.goexercise.app.MainActivity::class.java))),
    )
}

/** ウィジェットの BroadcastReceiver。AndroidManifest に登録する。 */
class StreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StreakWidget()
}
