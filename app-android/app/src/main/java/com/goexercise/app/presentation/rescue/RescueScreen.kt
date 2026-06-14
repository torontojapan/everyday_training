package com.goexercise.app.presentation.rescue

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
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
    Column(
        modifier = Modifier.fillMaxSize().background(palette.background).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("戻る") }
            Text("保険チケット", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = palette.textPrimary)
        }
        Surface(color = palette.chipBackground, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(14.dp)) {
                Text("今月の残り: ${state.remaining} / ${state.allowance} 枚", fontWeight = FontWeight.Bold, color = palette.textPrimary)
                Text("未達成の日(×)をタップすると、その日を達成扱いにして連続記録を守れます。",
                    color = palette.textSecondary, fontSize = 12.sp)
            }
        }
        // 無料枠(月1)のときだけプレミアム誘導(月4枚)。加入済み(allowance>=4)では非表示。
        if (state.allowance < 4) {
            Surface(
                color = palette.primary.copy(alpha = 0.10f),
                shape = RoundedCornerShape(14.dp),
                modifier = Modifier.fillMaxWidth().clickable(onClick = onUpgrade),
            ) {
                Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text("👑 プレミアムで保険チケットを月4回に", color = palette.primaryDeep, fontWeight = FontWeight.Bold, fontSize = 13.sp, modifier = Modifier.weight(1f))
                    Text("›", color = palette.primaryDeep, fontWeight = FontWeight.Bold, fontSize = 16.sp)
                }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = onPrev) { Text("‹ 前月") }
            Text("${state.month.year}年${state.month.monthValue}月", fontWeight = FontWeight.Bold,
                color = palette.textPrimary, modifier = Modifier.weight(1f), textAlign = TextAlign.Center)
            TextButton(onClick = onNext) { Text("翌月 ›") }
        }
        state.cells.chunked(7).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell -> DayCell(cell, state.remaining > 0, onUse, Modifier.weight(1f)) }
                repeat(7 - week.size) { Box(Modifier.weight(1f)) }
            }
        }
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
                    fontSize = 12.sp,
                    color = palette.textPrimary,
                    fontWeight = if (rescuable) FontWeight.Bold else FontWeight.Normal,
                )
            }
        }
    }
}
