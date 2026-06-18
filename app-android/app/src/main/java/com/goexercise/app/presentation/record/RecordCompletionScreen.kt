package com.goexercise.app.presentation.record

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircleOutline
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.domain.ExerciseItem
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.categoryIcon

/** リボン/数字のグラデ(オレンジ→ピンク。iOS の LinearGradient と同じ RGB)。 */
private val RibbonOrange = Color(1.00f, 0.55f, 0.35f)
private val RibbonPink = Color(0.95f, 0.32f, 0.60f)
private val HeroOrange = Color(1.00f, 0.55f, 0.30f)

/** 記録完了画面のエントリ。直近の連続日数/猫種/状態/今日の種目を購読して祝福を出す。iOS RecordCompletionView 相当。 */
@Composable
fun RecordCompletionRoute(
    onDone: () -> Unit = {},
    onRecordAgain: () -> Unit = {},
    viewModel: RecordCompletionViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    RecordCompletionContent(
        streak = state.streak,
        breed = state.breed,
        catState = state.catState,
        exercises = state.exercises,
        onDone = onDone,
        onRecordAgain = onRecordAgain,
    )
}

/** 記録直後の祝福。iOS RecordCompletionView パリティ: 暖色放射背景 + 祝福猫 + 称賛リボン(グラデ) +
 *  連続日数ヒーローカード + 今日の記録サマリー + もう一種目/ホームへ戻る。 */
@Composable
fun RecordCompletionContent(
    streak: Int,
    breed: CatBreed,
    catState: CatState,
    exercises: List<ExerciseItem> = emptyList(),
    onDone: () -> Unit = {},
    onRecordAgain: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val ribbon = rememberSaveable { praiseRibbons.random() }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Brush.radialGradient(listOf(palette.primary.copy(alpha = 0.30f), palette.background))),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // 1. ヒーロー: 大きい祝福猫。
            com.goexercise.app.ui.components.CatImage(
                breed = breed,
                state = catState,
                modifier = Modifier.size(210.dp),
                useShaker = true,
            )
            // 2. 称賛リボン(オレンジ→ピンクのグラデカプセル + 白文字)。
            Surface(
                shape = RoundedCornerShape(50),
                color = Color.Transparent,
                modifier = Modifier.background(Brush.horizontalGradient(listOf(RibbonOrange, RibbonPink)), RoundedCornerShape(50)),
            ) {
                Text(
                    ribbon,
                    style = AppType.screenTitle.copy(fontWeight = FontWeight.Black),
                    color = Color.White,
                    modifier = Modifier.padding(horizontal = 22.dp, vertical = 10.dp),
                )
            }
            // 3. 連続日数ヒーローカード(一番のごほうび)。
            if (streak > 0) StreakHeroCard(streak)
            // 4. 今日の記録サマリー。
            if (exercises.isNotEmpty()) RecordSummaryCard(exercises)

            Spacer(Modifier.height(0.dp))
            // もう一種目を記録する(アウトライン)。
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = palette.surface,
                modifier = Modifier
                    .fillMaxWidth()
                    .border(1.dp, palette.primary.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                    .clickable { onRecordAgain() },
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 14.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.AddCircleOutline, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.size(8.dp))
                    Text("もう一種目を記録する", style = AppType.headline, color = palette.primaryDeep)
                }
            }
            // ホームへ戻る(塗りつぶし)。
            Surface(
                shape = RoundedCornerShape(16.dp),
                color = palette.primary,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onDone() },
            ) {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 16.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.Home, contentDescription = null, tint = Color.White, modifier = Modifier.size(20.dp))
                    Spacer(Modifier.size(8.dp))
                    Text("ホームへ戻る", style = AppType.headline, color = Color.White)
                }
            }
        }
    }
}

/** 連続日数を大きな数字でヒーロー化したカード。iOS streakHero パリティ。 */
@Composable
private fun StreakHeroCard(streak: Int) {
    val palette = LocalAppPalette.current
    Surface(
        shape = RoundedCornerShape(24.dp),
        color = palette.surface,
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, palette.primary.copy(alpha = 0.18f), RoundedCornerShape(24.dp)),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 22.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Pets, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(28.dp))
            Spacer(Modifier.size(8.dp))
            Text(
                "$streak",
                fontSize = 60.sp,
                fontWeight = FontWeight.Black,
                style = TextStyle(brush = Brush.verticalGradient(listOf(HeroOrange, RibbonPink))),
            )
            Spacer(Modifier.size(8.dp))
            Text("日連続", style = AppType.sectionTitle.copy(fontWeight = FontWeight.Bold), color = palette.textSecondary)
        }
    }
}

/** 今日記録した種目のサマリーカード。各行「カテゴリ/名前 … 30分・3回・3セット」。iOS recordSummaryCard パリティ。 */
@Composable
private fun RecordSummaryCard(exercises: List<ExerciseItem>) {
    val palette = LocalAppPalette.current
    Surface(shape = RoundedCornerShape(20.dp), color = palette.surface, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Text("今日の記録", style = AppType.headline, color = palette.textPrimary)
            exercises.forEachIndexed { index, item ->
                val category = item.category ?: WorkoutCategory.Strength
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    verticalAlignment = Alignment.Top,
                ) {
                    Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                            Icon(categoryIcon(category), contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(14.dp))
                            Text(category.displayName, style = AppType.caption, color = palette.textSecondary)
                        }
                        Text(item.name, style = AppType.headline, color = palette.textPrimary)
                    }
                    Spacer(Modifier.size(8.dp))
                    Text(summaryFor(item), style = AppType.caption, color = palette.textSecondary, textAlign = TextAlign.End)
                }
                if (index != exercises.lastIndex) {
                    HorizontalDivider(color = palette.textSecondary.copy(alpha = 0.15f))
                }
            }
        }
    }
}

/** 「30分・3回・3セット」整形。iOS summary(for:) パリティ。 */
private fun summaryFor(item: ExerciseItem): String {
    val parts = mutableListOf<String>()
    item.durationSeconds?.let { dur ->
        val m = dur / 60
        val s = dur % 60
        parts += when {
            m > 0 && s > 0 -> "${m}分${s}秒"
            m > 0 -> "${m}分"
            else -> "${s}秒"
        }
    }
    item.reps?.let { parts += "${it}回" }
    item.sets?.let { parts += "${it}セット" }
    item.memo?.let { parts += it }
    return if (parts.isEmpty()) "詳細なし" else parts.joinToString("・")
}

private val praiseRibbons = listOf(
    "お見事！", "ナイス継続！", "今日もえらい！", "素晴らしい！", "やったね！", "完璧！", "天才！", "コツコツ最強！",
)
