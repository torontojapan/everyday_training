package com.goexercise.app.presentation.history

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.colorForStatus

@Composable
fun HistoryRoute(onUseRescue: () -> Unit = {}, viewModel: HistoryViewModel = hiltViewModel()) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HistoryContent(state, viewModel::prevMonth, viewModel::nextMonth, onUseRescue, viewModel::toggleMenstrual)
}

@Composable
fun HistoryContent(
    state: HistoryUiState,
    onPrev: () -> Unit = {},
    onNext: () -> Unit = {},
    onUseRescue: () -> Unit = {},
    onToggleMenstrual: (java.time.LocalDate) -> Unit = {},
) {
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

        var selected by remember { mutableStateOf<MonthCell?>(null) }
        state.cells.chunked(7).forEach { week ->
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                week.forEach { cell ->
                    DayCell(
                        cell, Modifier.weight(1f),
                        isPeriod = cell.date != null && cell.date in state.periodDays,
                        onClick = { if (cell.date != null && cell.status != null) selected = cell },
                    )
                }
                repeat(7 - week.size) { Box(Modifier.weight(1f)) } // 末週の埋め
            }
        }
        // 凡例 + 休養ルール説明(記号だけだと意味が伝わらないため。iOS footerSummary パリティ)。
        CalendarLegend(hasPeriod = state.periodDays.isNotEmpty())
        Text(
            "休養日は週2日まで自動でカウントされ、連続記録は途切れません。最初の記録より前の日は集計されません。",
            color = palette.textSecondary, fontSize = 11.sp,
        )

        TextButton(onClick = onUseRescue) { Text("保険チケットを使う") }

        // 日セルタップ → その日の詳細(記録一覧 or 状態別メッセージ)。iOS DayDetailSheet パリティ。
        val sel = selected
        if (sel?.date != null && sel.status != null) {
            DayDetailSheet(
                date = sel.date,
                status = sel.status,
                records = state.records.filter { it.date == sel.date },
                cycleTrackingEnabled = state.cycleTrackingEnabled,
                isPeriod = sel.date in state.periodDays,
                onToggleMenstrual = { onToggleMenstrual(sel.date) },
                onDismiss = { selected = null },
            )
        }
    }
}

/** カレンダー凡例。セルと同じ色(colorForStatus)で「色=状態」を一目で読めるようにする。iOS legendRow パリティ。 */
@Composable
private fun CalendarLegend(hasPeriod: Boolean) {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LegendSwatch(colorForStatus(DailyStatus.Achieved), "運動した日")
        LegendSwatch(colorForStatus(DailyStatus.Rest), "休養日")
        LegendSwatch(colorForStatus(DailyStatus.Rescued), "保険チケット")
        LegendSwatch(colorForStatus(DailyStatus.Missed), "未達成")
        if (hasPeriod) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Text("★", fontSize = 10.sp, color = Color(0xFFE05A8A))
                Text("生理日", color = palette.textSecondary, fontSize = 11.sp)
            }
        }
    }
}

@Composable
private fun LegendSwatch(color: Color, label: String) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(12.dp).clip(RoundedCornerShape(3.dp)).background(color))
        Text(label, color = palette.textSecondary, fontSize = 11.sp)
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
private fun DayCell(cell: MonthCell, modifier: Modifier, isPeriod: Boolean = false, onClick: () -> Unit = {}) {
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
                    .background(colorForStatus(status))
                    .clickable { onClick() },
                contentAlignment = Alignment.Center,
            ) {
                Text("${date.dayOfMonth}", fontSize = 12.sp, color = palette.textPrimary)
                // 生理日マーク(右上の★)。iOS 履歴カレンダー パリティ。
                if (isPeriod) {
                    Text("★", fontSize = 9.sp, color = Color(0xFFE05A8A), modifier = Modifier.align(Alignment.TopEnd).padding(1.dp))
                }
            }
        }
    }
}

/**
 * 日セルタップ時の詳細ボトムシート。iOS `DayDetailSheet` の移植。
 * 記録があれば一覧、無ければ状態別の一言メッセージ。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DayDetailSheet(
    date: java.time.LocalDate,
    status: DailyStatus,
    records: List<com.goexercise.app.domain.WorkoutRecord>,
    cycleTrackingEnabled: Boolean = false,
    isPeriod: Boolean = false,
    onToggleMenstrual: () -> Unit = {},
    onDismiss: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = palette.background) {
        Column(
            Modifier
                .fillMaxWidth()
                .padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val title = date.format(
                java.time.format.DateTimeFormatter.ofPattern("M月d日(E)", java.util.Locale.JAPANESE),
            )
            Text(title, fontWeight = FontWeight.Bold, fontSize = 18.sp, color = palette.textPrimary)
            if (records.isEmpty()) {
                Text(messageForStatus(status), color = palette.textSecondary, fontSize = 14.sp)
            } else {
                records.forEach { record ->
                    record.exercises.forEach { ex ->
                        val parts = buildList {
                            ex.durationSeconds?.let { add("${it / 60}分") }
                            ex.reps?.let { add("${it}回") }
                            ex.sets?.let { add("${it}セット") }
                            ex.loadKilograms?.let { add("${it}kg") }
                        }
                        Text(
                            buildString {
                                append(ex.name)
                                if (parts.isNotEmpty()) append("  ").append(parts.joinToString(" / "))
                            },
                            color = palette.textPrimary, fontSize = 14.sp,
                        )
                    }
                }
            }
            // 周期トラッキング ON のとき、過去日を含めて生理日を登録/解除できる(iOS MenstrualEntryView パリティ)。
            if (cycleTrackingEnabled && !date.isAfter(java.time.LocalDate.now())) {
                TextButton(onClick = onToggleMenstrual) {
                    Text(if (isPeriod) "★ 生理日の登録を解除" else "この日を生理日に登録", color = palette.primaryDeep)
                }
            }
        }
    }
}

private fun messageForStatus(status: DailyStatus): String = when (status) {
    DailyStatus.Rest -> "この日は回復日。無理しないのも大事だよ"
    DailyStatus.Future -> "これからの日だね"
    DailyStatus.Missed -> "この日は記録がないよ"
    DailyStatus.TodayPending -> "今日はまだ記録がないよ"
    DailyStatus.Achieved, DailyStatus.TodayAchieved -> "記録がここに表示されます"
    DailyStatus.Rescued -> "この日は保険チケットで連続記録を継続したよ"
}
