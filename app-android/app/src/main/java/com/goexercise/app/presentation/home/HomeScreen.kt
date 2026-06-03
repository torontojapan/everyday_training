package com.goexercise.app.presentation.home

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.DailyStatusEntry
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.GOExerciseTheme
import com.goexercise.app.ui.theme.LocalAppPalette

/** Home ルートのエントリ。VM から状態を購読して [HomeContent] に渡す。 */
@Composable
fun HomeRoute(
    onRecordClick: () -> Unit = {},
    viewModel: HomeViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HomeContent(state = state, onRecordClick = onRecordClick)
}

/** ステートレスなホーム本体(プレビュー/テストしやすいよう状態を引数で受ける)。 */
@Composable
fun HomeContent(
    state: HomeUiState,
    onRecordClick: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        CatTheater(state)
        WeekStrip(state.weekStatuses)
        StatsRow(state)
        Button(
            onClick = onRecordClick,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("記録する")
        }
    }
}

@Composable
private fun CatTheater(state: HomeUiState) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(text = state.catState.emoji, fontSize = 56.sp)
        Surface(
            color = palette.surface,
            shape = RoundedCornerShape(20.dp),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = state.catMessage.text,
                color = palette.textPrimary,
                modifier = Modifier.padding(16.dp),
            )
        }
    }
}

@Composable
private fun WeekStrip(week: List<DailyStatusEntry>) {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        week.forEach { entry ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Text(text = "${entry.date.dayOfMonth}", color = palette.textSecondary, fontSize = 11.sp)
                Box(
                    modifier = Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(colorFor(entry.status)),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(text = entry.status.symbol, fontSize = 14.sp)
                }
            }
        }
    }
}

@Composable
private fun StatsRow(state: HomeUiState) {
    val palette = LocalAppPalette.current
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxWidth()) {
        StatPill(label = "連続", value = "${state.streak.currentStreak}日", modifier = Modifier.weight(1f))
        StatPill(label = "累計達成", value = "${state.lifetimeStats.achievedDays}日", modifier = Modifier.weight(1f))
        val decoText = if (state.catDecoration == com.goexercise.app.domain.CatDecoration.None) "—" else state.catDecoration.emoji
        StatPill(label = "ランク", value = decoText, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun StatPill(label: String, value: String, modifier: Modifier = Modifier) {
    val palette = LocalAppPalette.current
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = modifier) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(text = value, color = palette.textPrimary, fontWeight = FontWeight.Bold)
            Text(text = label, color = palette.textSecondary, fontSize = 11.sp, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun colorFor(status: DailyStatus) = with(LocalAppPalette.current) {
    when (status) {
        DailyStatus.TodayAchieved -> primary
        DailyStatus.Achieved -> success
        DailyStatus.Rest -> restDay
        DailyStatus.Missed -> missed
        DailyStatus.TodayPending -> secondary
        DailyStatus.Future -> chipBackground
    }
}

@androidx.compose.ui.tooling.preview.Preview(showBackground = true)
@Composable
private fun HomeContentPreview() {
    GOExerciseTheme(theme = AppTheme.Peach) {
        HomeContent(state = HomeUiState())
    }
}
