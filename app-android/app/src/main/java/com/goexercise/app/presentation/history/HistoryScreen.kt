package com.goexercise.app.presentation.history

import android.content.Intent
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.ExerciseTrendSummary
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.colorForStatus
import java.time.LocalDate
import java.time.YearMonth

@Composable
fun HistoryRoute(
    onUseRescue: () -> Unit = {},
    onOpenHighlight: (String) -> Unit = {},
    viewModel: HistoryViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HistoryContent(state, viewModel::prevMonth, viewModel::nextMonth, onUseRescue, viewModel::toggleMenstrual, onOpenHighlight)
}

@Composable
fun HistoryContent(
    state: HistoryUiState,
    onPrev: () -> Unit = {},
    onNext: () -> Unit = {},
    onUseRescue: () -> Unit = {},
    onToggleMenstrual: (LocalDate) -> Unit = {},
    onOpenHighlight: (String) -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val today = remember { LocalDate.now() }
    var selected by remember { mutableStateOf<MonthCell?>(null) }
    // 翌月ガード: 当月より先には進めない(iOS canShiftForward)。
    val canGoNext = state.month.isBefore(YearMonth.from(today))

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text(
            "履歴",
            style = AppType.screenTitle,
            color = palette.textPrimary,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )

        // カレンダーカード(月ナビ + 曜日 + グリッド + 凡例 + 注記をすべてカード内に)。iOS monthlyCalendarCard。
        Surface(color = palette.surface, shape = RoundedCornerShape(22.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                    MonthNavButton(Icons.Filled.ChevronLeft, "前月", enabled = true, onClick = onPrev)
                    Text(
                        "${state.month.year}年${state.month.monthValue}月",
                        style = AppType.sectionTitle,
                        color = palette.textPrimary,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                    )
                    MonthNavButton(Icons.Filled.ChevronRight, "翌月", enabled = canGoNext, onClick = onNext)
                }
                WeekdayHeader()
                state.cells.chunked(7).forEach { week ->
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        week.forEach { cell ->
                            DayCell(
                                cell, Modifier.weight(1f),
                                isToday = cell.date != null && cell.date == today,
                                // 生理日マークは周期トラッキング ON のときだけ(iOS パリティ)。
                                isPeriod = state.cycleTrackingEnabled && cell.date != null && cell.date in state.periodDays,
                                onClick = { if (cell.date != null && cell.status != null) selected = cell },
                            )
                        }
                        repeat(7 - week.size) { Box(Modifier.weight(1f)) }
                    }
                }
                CalendarLegend(hasPeriod = state.cycleTrackingEnabled && state.periodDays.isNotEmpty())
                Text(
                    "休養日は週2日まで自動でカウントされ、連続記録は途切れません。最初の記録より前の日は集計されません。",
                    color = palette.textSecondary,
                    style = AppType.caption,
                )
            }
        }

        // 保険チケット(連続を守るフリーズ)。iOS の折りたたみセクション相当の導線。
        EntryCard(
            icon = Icons.Filled.ConfirmationNumber,
            iconTint = palette.primaryDeep,
            title = "保険チケット",
            subtitle = "連続が途切れそうな日に使って記録を守る",
            onClick = onUseRescue,
        )

        // ハイライト共有(Weekly/Monthly/All-time)。subtitle は記録から算出。
        val weekly = remember(state.records) { ExerciseTrendSummary.week(state.records, today) }
        val lifetime = remember(state.records) {
            val first = state.records.minOfOrNull { it.date } ?: today
            LifetimeStatsCalculator.calculate(state.records, first, today)
        }
        // iOS build 12: ラベルは Weekly/Monthly/All-time ハイライト。Weekly は今週に記録がある時だけ。
        if (weekly.hasExerciseData) {
            EntryCard(
                icon = Icons.Filled.AutoAwesome, iconTint = palette.primaryDeep,
                title = "Weeklyハイライト",
                subtitle = "合計 ${weekly.totalMinutes} 分 / ${weekly.usedCategories.size} カテゴリ",
                onClick = { onOpenHighlight("weekly") },
            )
        }
        // Monthly = 今月(常時活性。遷移先 HighlightShareViewModel も month=today で当月レビューを作る)。
        EntryCard(
            icon = Icons.Filled.Description, iconTint = palette.primaryDeep,
            title = "Monthlyハイライト",
            subtitle = "今月のがんばりをカードでサマリー",
            onClick = { onOpenHighlight("monthly") },
        )
        EntryCard(
            icon = Icons.Filled.EmojiEvents, iconTint = palette.primaryDeep,
            title = "All-timeハイライト",
            subtitle = "累計 ${lifetime.achievedDays} 日達成 / 達成率 ${(lifetime.rate * 100).toInt()}%",
            onClick = { onOpenHighlight("alltime") },
        )

        // 運動履歴(折りたたみ)。iOS 運動履歴 CollapsibleSection。
        ExerciseHistorySection(state.records)

        // このアプリを友達にシェア。iOS shareAppEntry。
        val context = LocalContext.current
        EntryCard(
            icon = Icons.Filled.IosShare, iconTint = palette.primaryDeep,
            title = "このアプリを友達にシェア",
            subtitle = "一緒に運動を習慣にしよう",
            onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, "GOエクササイズで一緒に運動しよう！\nhttps://goexercise.app")
                }
                runCatching { context.startActivity(Intent.createChooser(intent, "シェア")) }
            },
        )

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

/** 月送りの丸ボタン(chip 背景 + chevron)。iOS の円形ナビボタン相当。無効時は淡色・非活性。 */
@Composable
private fun MonthNavButton(icon: androidx.compose.ui.graphics.vector.ImageVector, desc: String, enabled: Boolean, onClick: () -> Unit) {
    val palette = LocalAppPalette.current
    Box(
        modifier = Modifier
            .size(36.dp)
            .clip(CircleShape)
            .background(palette.chipBackground.copy(alpha = if (enabled) 1f else 0.4f))
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            icon, contentDescription = desc,
            // 無効(未来月)時は iOS と同じ中立グレー。活性は primaryDeep。
            tint = if (enabled) palette.primaryDeep else palette.textSecondary.copy(alpha = 0.4f),
            modifier = Modifier.size(22.dp),
        )
    }
}

/** アイコン + タイトル + サブタイトル + chevron の汎用エントリカード。iOS entry-row 相当。
 *  dimmed=true(例: 記録の無い先月ハイライト)はタイトル/アイコンを淡色にして非活性を示す(iOS パリティ)。 */
@Composable
private fun EntryCard(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    iconTint: Color,
    title: String,
    subtitle: String,
    dimmed: Boolean = false,
    onClick: () -> Unit,
) {
    val palette = LocalAppPalette.current
    val titleColor = if (dimmed) palette.textSecondary else palette.textPrimary
    val resolvedIconTint = if (dimmed) palette.textSecondary.copy(alpha = 0.5f) else iconTint
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .clickable(onClick = onClick)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(icon, contentDescription = null, tint = resolvedIconTint, modifier = Modifier.size(24.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(title, style = AppType.headline, color = titleColor)
                Text(subtitle, style = AppType.caption, color = palette.textSecondary)
            }
            if (!dimmed) {
                Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(20.dp))
            }
        }
    }
}

/** 運動履歴の折りたたみセクション。iOS 運動履歴 CollapsibleSection。日付別に種目を表示。 */
@Composable
private fun ExerciseHistorySection(records: List<com.goexercise.app.domain.WorkoutRecord>) {
    val palette = LocalAppPalette.current
    var expanded by remember { mutableStateOf(false) }
    val days = records.map { it.date }.distinct().size
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                Text("運動履歴", style = AppType.headline, color = palette.textPrimary)
                Text("合計 $days 日", style = AppType.caption, color = palette.textSecondary, modifier = Modifier.weight(1f))
                Icon(
                    if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                    contentDescription = null, tint = palette.textSecondary,
                )
            }
            if (expanded) {
                // 日付でグルーピング(同日に複数記録があっても日付見出しは1回。iOS HistoryRowView の日別表示)。
                records.groupBy { it.date }.toSortedMap(compareByDescending { it }).forEach { (date, dayRecords) ->
                    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Text(
                            date.format(java.time.format.DateTimeFormatter.ofPattern("M月d日(E)", java.util.Locale.JAPANESE)),
                            style = AppType.caption, color = palette.textSecondary,
                        )
                        dayRecords.flatMap { it.exercises }.forEach { ex ->
                            val parts = buildList {
                                ex.durationSeconds?.let { add("${it / 60}分") }
                                ex.reps?.let { add("${it}回") }
                                ex.sets?.let { add("${it}セット") }
                            }
                            Text(
                                buildString { append(ex.name); if (parts.isNotEmpty()) append("  ").append(parts.joinToString(" / ")) },
                                style = AppType.caption,
                                color = palette.textPrimary,
                            )
                        }
                    }
                }
                if (records.isEmpty()) {
                    Text("まだ記録がありません", style = AppType.caption, color = palette.textSecondary)
                }
            }
        }
    }
}

/** カレンダー凡例。iOS legendRow パリティ(運動した日/休養日/フリーズ/未達成 + 生理日ドット)。 */
@Composable
private fun CalendarLegend(hasPeriod: Boolean) {
    val palette = LocalAppPalette.current
    Row(
        modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        LegendSwatch(monthlyStatusColor(DailyStatus.Achieved), "運動した日")
        LegendSwatch(monthlyStatusColor(DailyStatus.Rest), "休養日")
        LegendSwatch(monthlyStatusColor(DailyStatus.Rescued), "保険チケット")
        LegendSwatch(monthlyStatusColor(DailyStatus.Missed), "未達成")
        if (hasPeriod) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(Color(0xFFE05A8A)))
                Text("生理日", color = palette.textSecondary, style = AppType.caption)
            }
        }
    }
}

/** iOS MonthlyCalendarView.background(for:) と同じ不透明度のセル配色(solid な colorForStatus でなく
 *  iOS のパステル調に合わせる。これでフリーズ(淡緑)が休養日(緑)と区別できる)。 */
@Composable
private fun monthlyStatusColor(status: DailyStatus): Color {
    val palette = LocalAppPalette.current
    return when (status) {
        DailyStatus.Achieved, DailyStatus.TodayAchieved -> Color(0.93f, 0.33f, 0.30f).copy(alpha = 0.60f)
        DailyStatus.Rest -> Color(0.36f, 0.65f, 0.40f).copy(alpha = 0.55f)
        DailyStatus.Rescued -> Color(0.36f, 0.65f, 0.40f).copy(alpha = 0.32f)
        DailyStatus.Missed -> Color(0.38f, 0.55f, 0.90f).copy(alpha = 0.30f)
        DailyStatus.Future, DailyStatus.TodayPending -> palette.secondary.copy(alpha = 0.45f)
    }
}

@Composable
private fun LegendSwatch(color: Color, label: String) {
    val palette = LocalAppPalette.current
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        Box(Modifier.size(12.dp).clip(RoundedCornerShape(3.dp)).background(color))
        Text(label, color = palette.textSecondary, style = AppType.caption)
    }
}

@Composable
private fun WeekdayHeader() {
    val palette = LocalAppPalette.current
    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
        listOf("月", "火", "水", "木", "金", "土", "日").forEach { d ->
            Text(d, modifier = Modifier.weight(1f), color = palette.textSecondary, style = AppType.caption, textAlign = TextAlign.Center)
        }
    }
}

@Composable
private fun DayCell(cell: MonthCell, modifier: Modifier, isToday: Boolean = false, isPeriod: Boolean = false, onClick: () -> Unit = {}) {
    val palette = LocalAppPalette.current
    Box(modifier = modifier.aspectRatio(1f), contentAlignment = Alignment.Center) {
        val date = cell.date
        val status = cell.status
        if (date != null && status != null) {
            // 今日は primary 強調(iOS と同じ)。それ以外は status 色。
            val bg = if (isToday) palette.primary.copy(alpha = 0.85f) else monthlyStatusColor(status)
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(2.dp)
                    .clip(RoundedCornerShape(9.dp))
                    .background(bg)
                    .clickable { onClick() },
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    "${date.dayOfMonth}",
                    style = AppType.caption.copy(fontWeight = if (isToday) FontWeight.Black else FontWeight.Normal),
                    color = if (isToday) Color.White else palette.textPrimary,
                )
                if (isPeriod) {
                    Box(
                        Modifier.align(Alignment.TopEnd).padding(3.dp).size(6.dp).clip(CircleShape).background(Color(0xFFE05A8A)),
                    )
                }
            }
        }
    }
}

/** 日セルタップ時の詳細ボトムシート。iOS `DayDetailSheet` の移植。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DayDetailSheet(
    date: LocalDate,
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
            Modifier.fillMaxWidth().padding(20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val title = date.format(java.time.format.DateTimeFormatter.ofPattern("M月d日(E)", java.util.Locale.JAPANESE))
            Text(title, style = AppType.sectionTitle, color = palette.textPrimary)
            if (records.isEmpty()) {
                Text(messageForStatus(status), color = palette.textSecondary, style = AppType.body)
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
                            buildString { append(ex.name); if (parts.isNotEmpty()) append("  ").append(parts.joinToString(" / ")) },
                            color = palette.textPrimary, style = AppType.body,
                        )
                    }
                }
            }
            if (cycleTrackingEnabled && !date.isAfter(LocalDate.now())) {
                TextButton(onClick = onToggleMenstrual) {
                    Text(if (isPeriod) "生理日の登録を解除" else "この日を生理日に登録", color = palette.primaryDeep)
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
