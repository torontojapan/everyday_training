package com.goexercise.app.presentation.history

import androidx.compose.foundation.background
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
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.colorForStatus

@Composable
fun HistoryRoute(viewModel: HistoryViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HistoryContent(state, viewModel::prevMonth, viewModel::nextMonth)
}

@Composable
fun HistoryContent(state: HistoryUiState, onPrev: () -> Unit = {}, onNext: () -> Unit = {}) {
    val palette = LocalAppPalette.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
            TextButton(onClick = onPrev) { Text("‹ 前月") }
            Text(
                text = "${state.month.year}年${state.month.monthValue}月",
                fontWeight = FontWeight.Bold,
                fontSize = 18.sp,
                color = palette.textPrimary,
                modifier = Modifier.weight(1f),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            )
            TextButton(onClick = onNext) { Text("翌月 ›") }
        }
        Text("達成 ${state.achievedDays} 日", color = palette.textSecondary, fontSize = 13.sp)

        WeekdayHeader()

        state.cells.chunked(7).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell -> DayCell(cell, Modifier.weight(1f)) }
                repeat(7 - week.size) { Box(Modifier.weight(1f)) } // 末週の埋め
            }
        }
    }
}

@Composable
private fun WeekdayHeader() {
    val palette = LocalAppPalette.current
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf("月", "火", "水", "木", "金", "土", "日").forEach { d ->
            Text(d, modifier = Modifier.weight(1f), color = palette.textSecondary, fontSize = 11.sp,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
    }
}

@Composable
private fun DayCell(cell: MonthCell, modifier: Modifier) {
    val palette = LocalAppPalette.current
    Box(modifier = modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        val date = cell.date
        val status = cell.status
        if (date != null && status != null) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(2.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(colorForStatus(status)),
                contentAlignment = Alignment.Center,
            ) {
                Text("${date.dayOfMonth}", fontSize = 12.sp, color = palette.textPrimary)
            }
        }
    }
}
