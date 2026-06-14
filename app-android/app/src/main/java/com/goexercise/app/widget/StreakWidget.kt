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
        val breed = ep.settingsRepository().catBreed.first()
        val now = LocalDateTime.now(ep.clock())
        val state = HomeStateReducer.reduce(records, now, rescuedDates = rescued, firstUseDate = firstUse)

        provideContent {
            WidgetBody(
                context = context,
                breed = breed,
                catState = state.catState,
                streak = state.streak.currentStreak,
                todayAchieved = state.todayStatus.countsAsAchieved,
            )
        }
    }

    companion object {
        // Peach 系の固定色(Glance は LocalAppPalette 不可)。
        private val BG = Color(0xFFFDF1E7)
        val bgProvider = ColorProvider(BG)
    }
}

@androidx.compose.runtime.Composable
private fun WidgetBody(context: Context, breed: CatBreed, catState: CatState, streak: Int, todayAchieved: Boolean) {
    val resId = resolveCatRes(context, breed, catState)
    Column(
        modifier = GlanceModifier
            .fillMaxSize()
            .background(StreakWidget.bgProvider)
            .cornerRadius(16.dp)
            .padding(8.dp)
            // タップでアプリ(ホーム)を開く。
            .clickable(actionStartActivity(android.content.Intent(context, com.goexercise.app.MainActivity::class.java))),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (resId != 0) {
            Image(provider = ImageProvider(resId), contentDescription = breed.displayName, modifier = GlanceModifier.size(64.dp))
        }
        Text(
            "🔥 ${streak}日連続",
            style = TextStyle(color = ColorProvider(Color(0xFFD9663D)), fontWeight = FontWeight.Bold),
        )
        Text(
            if (todayAchieved) "今日 達成" else "今日 まだ",
            style = TextStyle(color = ColorProvider(if (todayAchieved) Color(0xFF4CAF7D) else Color(0xFF9E8E84))),
        )
    }
}

/** breed × state の drawable を getIdentifier で解決(欠損は orange→既定にフォールバック)。 */
private fun resolveCatRes(context: Context, breed: CatBreed, state: CatState): Int {
    fun id(name: String) = context.resources.getIdentifier(name, "drawable", context.packageName)
    return id(breed.assetName(state)).takeIf { it != 0 }
        ?: id(CatBreed.fallbackAssetName(state)).takeIf { it != 0 }
        ?: id(CatBreed.FALLBACK_AVATAR)
}

/** ウィジェットの BroadcastReceiver。AndroidManifest に登録する。 */
class StreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StreakWidget()
}
