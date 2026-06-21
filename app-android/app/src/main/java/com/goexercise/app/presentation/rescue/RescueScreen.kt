package com.goexercise.app.presentation.rescue

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.TouchApp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.colorForStatus
import java.time.LocalDate

@Composable
fun RescueRoute(onBack: () -> Unit = {}, onUpgrade: () -> Unit = {}, viewModel: RescueViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    RescueContent(state, onBack, viewModel::useTicket, viewModel::prevMonth, viewModel::nextMonth, onUpgrade)
}

@Composable
fun RescueContent(
    state: RescueUiState,
    onBack: () -> Unit = {},
    onUse: (LocalDate) -> Unit = {},
    onPrev: () -> Unit = {},
    onNext: () -> Unit = {},
    onUpgrade: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    // iOS は適用前に確認 alert(チケット誤消費防止)。タップ→pendingDate→確認→適用。
    var pendingDate by remember { mutableStateOf<LocalDate?>(null) }
    Column(
        modifier = Modifier.fillMaxSize().background(palette.background).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        // iOS navigationTitle「保険チケットを使う」(inline)。
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("戻る") }
            Text("保険チケットを使う", style = AppType.headline, color = palette.textPrimary)
        }

        // summaryCard: チケットアイコン + 残数 + 説明(無料枠のみインラインで「(GOプレミアムで月4回)」)。
        val available = state.remaining > 0
        Surface(color = palette.surface, shape = RoundedCornerShape(20.dp), modifier = Modifier.fillMaxWidth()) {
            Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                Box(
                    Modifier.size(56.dp).clip(CircleShape)
                        .background(if (available) palette.primary.copy(alpha = 0.18f) else palette.chipBackground.copy(alpha = 0.5f)),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        Icons.Filled.ConfirmationNumber, contentDescription = null,
                        tint = if (available) palette.primary else palette.textSecondary.copy(alpha = 0.5f),
                        modifier = Modifier.size(28.dp),
                    )
                }
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("今月の保険チケット: ${state.remaining} / ${state.allowance} 回 残り", style = AppType.headline, color = palette.textPrimary)
                    val premiumHint = if (state.allowance > 1) "" else " (GOプレミアムで月4回)"
                    Text("月 ${state.allowance} 回まで$premiumHint。忙しい日に過去にさかのぼって適用できます。", style = AppType.caption, color = palette.textSecondary)
                }
            }
        }

        // instructionCard。iOS: hand.tap.fill + 操作説明。
        Surface(color = palette.chipBackground.copy(alpha = 0.6f), shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
            Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Icon(Icons.Filled.TouchApp, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
                Text("カレンダーで × の日(未達成) をタップ → 確認 → 適用", style = AppType.caption, color = palette.textPrimary)
            }
        }

        // 月ナビ。
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = onPrev) { Text("‹ 前月") }
            Text("${state.month.year}年${state.month.monthValue}月", fontWeight = FontWeight.Bold,
                color = palette.textPrimary, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            TextButton(onClick = onNext) { Text("翌月 ›") }
        }
        state.cells.chunked(7).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell -> DayCell(cell, state.remaining > 0, { pendingDate = it }, Modifier.weight(1f)) }
                repeat(7 - week.size) { Box(Modifier.weight(1f)) }
            }
        }

        // マークの意味(凡例)。iOS legend。
        RescueLegend(palette)

        // これまでに使った日。iOS rescuedHistory(救済済みがある時だけ)。
        if (state.rescuedDates.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("これまでに使った日", style = AppType.headline, color = palette.textPrimary)
                state.rescuedDates.forEach { d ->
                    Surface(color = palette.surface, shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                        Row(Modifier.padding(horizontal = 12.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(Icons.Filled.ConfirmationNumber, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
                            Text("${d.year}年${d.monthValue}月${d.dayOfMonth}日", color = palette.textPrimary, style = AppType.body.copy(fontWeight = FontWeight.Normal))
                        }
                    }
                }
            }
        }
    }

    // 適用確認ダイアログ(iOS confirm alert)。
    pendingDate?.let { date ->
        val after = (state.remaining - 1).coerceAtLeast(0)
        AlertDialog(
            onDismissRequest = { pendingDate = null },
            title = { Text("${date.year}年${date.monthValue}月${date.dayOfMonth}日 に保険チケットを適用しますか？") },
            text = { Text("$date に保険チケットを1回使うと、今月の残りは $after 回になります。連続記録が途切れずに済みます。") },
            confirmButton = { TextButton(onClick = { onUse(date); pendingDate = null }) { Text("適用する", color = palette.primaryDeep, fontWeight = FontWeight.Bold) } },
            dismissButton = { TextButton(onClick = { pendingDate = null }) { Text("キャンセル") } },
            containerColor = palette.surface,
        )
    }
}

/** マークの意味(凡例)。iOS RescueTicketUseView.legend パリティ。 */
@Composable
private fun RescueLegend(palette: AppTheme) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("マークの意味", style = AppType.caption, color = palette.textSecondary)
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LegendSymbol("×", "未達成 (適用可)", bordered = true, palette = palette)
            LegendSymbol("○", "達成済み", palette = palette)
            LegendSymbol("休", "自動休養", palette = palette)
        }
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            LegendIcon("チケット適用済み", palette)
            LegendSymbol("★", "★ 生理日", palette = palette)
        }
    }
}

@Composable
private fun LegendSymbol(symbol: String, label: String, bordered: Boolean = false, palette: AppTheme) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(
            Modifier.size(22.dp).clip(CircleShape).background(palette.surface)
                .then(if (bordered) Modifier.border(2.dp, palette.primary, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) { Text(symbol, fontSize = 12.sp, fontWeight = FontWeight.ExtraBold, color = palette.textPrimary) }  // parity-allow: AppType トークン同値(size12・Rounded全域・weight明示/既定Normal・density393 iOS照合済)
        Text(label, style = AppType.caption, color = palette.textSecondary)
    }
}

@Composable
private fun LegendIcon(label: String, palette: AppTheme) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Icon(Icons.Filled.ConfirmationNumber, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(22.dp))
        Text(label, style = AppType.caption, color = palette.textSecondary)
    }
}

@Composable
private fun DayCell(cell: MonthCell, hasTickets: Boolean, onUse: (LocalDate) -> Unit, modifier: Modifier) {
    val palette = LocalAppPalette.current
    val date = cell.date
    val status = cell.status
    val rescuable = date != null && status == DailyStatus.Missed && hasTickets
    Box(modifier = modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        if (date != null && status != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(2.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(colorForStatus(status))
                    .then(if (rescuable) Modifier.clickable { onUse(date) } else Modifier),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = if (rescuable) "${date.dayOfMonth}+" else "${date.dayOfMonth}",
                    fontSize = 12.sp,  // parity-allow: AppType トークン同値(size12・Rounded全域・weight明示/既定Normal・density393 iOS照合済)
                    color = palette.textPrimary,
                    fontWeight = if (rescuable) FontWeight.Bold else FontWeight.Normal,
                )
            }
        }
    }
}
