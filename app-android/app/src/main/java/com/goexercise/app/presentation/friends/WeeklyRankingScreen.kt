package com.goexercise.app.presentation.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.friends.RankingPeriod
import com.goexercise.app.domain.friends.WeeklyRankingEntry
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette

@Composable
fun WeeklyRankingRoute(onBack: () -> Unit = {}, viewModel: WeeklyRankingViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    WeeklyRankingContent(state, onBack, viewModel::setPeriod)
}

@Composable
fun WeeklyRankingContent(
    state: RankingUiState,
    onBack: () -> Unit = {},
    onSetPeriod: (RankingPeriod) -> Unit = {},
) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("戻る") }
            Text("ランキング", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        }

        PeriodPicker(state.period, palette, onSetPeriod)
        RulesCard(state.period, palette)
        state.myEntry?.let { MySummaryCard(it, state.entries.size, state.period, palette) }

        if (state.entries.isEmpty()) {
            Text(
                "ランキングを表示するには、友達を追加してください。",
                fontSize = 13.sp,
                color = palette.textSecondary,
                modifier = Modifier.padding(vertical = 24.dp).fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                state.entries.forEach { RankRow(it, palette) }
            }
        }
    }
}

@Composable
private fun PeriodPicker(period: RankingPeriod, palette: AppTheme, onSet: (RankingPeriod) -> Unit) {
    Surface(color = palette.chipBackground, shape = RoundedCornerShape(50), modifier = Modifier.fillMaxWidth()) {
        Row(Modifier.padding(4.dp)) {
            RankingPeriod.entries.forEach { p ->
                val selected = p == period
                Surface(
                    color = if (selected) palette.primary else Color.Transparent,
                    shape = RoundedCornerShape(50),
                    modifier = Modifier.weight(1f).clickable { onSet(p) },
                ) {
                    Text(
                        p.label,
                        fontSize = 14.sp,
                        fontWeight = if (selected) FontWeight.Bold else FontWeight.Normal,
                        color = if (selected) Color.White else palette.textSecondary,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(vertical = 8.dp).fillMaxWidth(),
                    )
                }
            }
        }
    }
}

@Composable
private fun RulesCard(period: RankingPeriod, palette: AppTheme) {
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text("🏆 ${period.rulesTitle}", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.settingsAccent)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                PriorityPill(1, "連続日数が長い", palette.primary, palette)
                PriorityPill(2, "運動時間が長い", palette.settingsAccent, palette)
            }
            Text(period.resetHint, fontSize = 12.sp, color = palette.textSecondary)
        }
    }
}

@Composable
private fun PriorityPill(number: Int, label: String, color: Color, palette: AppTheme) {
    Surface(color = color.copy(alpha = 0.10f), shape = RoundedCornerShape(50)) {
        Row(
            Modifier.padding(horizontal = 10.dp, vertical = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Box(Modifier.size(18.dp).clip(CircleShape).background(color), contentAlignment = Alignment.Center) {
                Text("$number", fontSize = 11.sp, fontWeight = FontWeight.Black, color = Color.White)
            }
            Text(label, fontSize = 12.sp, color = palette.textPrimary)
        }
    }
}

@Composable
private fun MySummaryCard(me: WeeklyRankingEntry, total: Int, period: RankingPeriod, palette: AppTheme) {
    Surface(
        color = palette.primary.copy(alpha = 0.12f),
        shape = RoundedCornerShape(20.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.size(64.dp).clip(CircleShape).background(palette.primary.copy(alpha = 0.18f)), contentAlignment = Alignment.Center) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text("${me.rank}", fontSize = 24.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep)
                    Text("位", fontSize = 10.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep)
                }
            }
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("あなたは ${me.rank} 位 / 全 $total 人中", fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("🔥 ${me.profile.currentStreak} 日連続", fontSize = 12.sp, color = palette.primaryDeep)
                    Text("⏱ ${me.totalMinutes} 分", fontSize = 12.sp, color = palette.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun RankRow(entry: WeeklyRankingEntry, palette: AppTheme) {
    Surface(
        color = if (entry.isMe) palette.primary.copy(alpha = 0.08f) else palette.surface,
        shape = RoundedCornerShape(14.dp),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            RankBadge(entry.rank, palette)
            Box(Modifier.size(44.dp).clip(CircleShape).background(palette.primary.copy(alpha = 0.20f)), contentAlignment = Alignment.Center) {
                Text("🐱", fontSize = 24.sp)
            }
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(entry.profile.displayName, fontSize = 15.sp, fontWeight = FontWeight.SemiBold, color = palette.textPrimary)
                    if (entry.isMe) {
                        Surface(color = palette.primary, shape = RoundedCornerShape(50)) {
                            Text("あなた", fontSize = 10.sp, fontWeight = FontWeight.Black, color = Color.White, modifier = Modifier.padding(horizontal = 6.dp, vertical = 2.dp))
                        }
                    }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text("🔥 ${entry.profile.currentStreak}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.primaryDeep)
                    Text("⏱ ${entry.totalMinutes}分", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = palette.textSecondary)
                }
            }
        }
    }
}

@Composable
private fun RankBadge(rank: Int, palette: AppTheme) {
    val medal = when (rank) {
        1 -> "🥇"
        2 -> "🥈"
        3 -> "🥉"
        else -> null
    }
    Box(
        modifier = Modifier.size(40.dp).clip(CircleShape).background(palette.chipBackground),
        contentAlignment = Alignment.Center,
    ) {
        if (medal != null) {
            Text(medal, fontSize = 22.sp)
        } else {
            Text("$rank", fontSize = 15.sp, fontWeight = FontWeight.Black, color = palette.textPrimary)
        }
    }
}
