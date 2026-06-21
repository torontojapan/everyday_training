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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.AcUnit
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bedtime
import androidx.compose.material.icons.filled.ChevronLeft
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.Pets
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.ConfirmationNumber
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.IosShare
import androidx.compose.material.icons.filled.WorkspacePremium
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.vectorResource
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.DailyStatus
import com.goexercise.app.domain.ExerciseTrendSummary
import com.goexercise.app.domain.LifetimeStatsCalculator
import com.goexercise.app.domain.MonthlyCalendarCalculator.MonthCell
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.categoryIcon
import com.goexercise.app.ui.theme.colorForStatus
import java.time.LocalDate
import java.time.YearMonth

@Composable
fun HistoryRoute(
    onUseRescue: () -> Unit = {},
    onOpenHighlight: (String) -> Unit = {},
    onOpenPremium: () -> Unit = {},
    onOpenMenstrual: () -> Unit = {},
    viewModel: HistoryViewModel = hiltViewModel(),
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    HistoryContent(state, viewModel::prevMonth, viewModel::nextMonth, onUseRescue, viewModel::toggleMenstrual, onOpenHighlight, onOpenPremium, onOpenMenstrual)
}

@Composable
fun HistoryContent(
    state: HistoryUiState,
    onPrev: () -> Unit = {},
    onNext: () -> Unit = {},
    onUseRescue: () -> Unit = {},
    onToggleMenstrual: (LocalDate) -> Unit = {},
    onOpenHighlight: (String) -> Unit = {},
    onOpenPremium: () -> Unit = {},
    onOpenMenstrual: () -> Unit = {},
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
            // iOS は .navigationTitle inline(17pt semibold)。screenTitle(22 Bold)は大きすぎ → headline。
            "履歴",
            style = AppType.headline,
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
                        // iOS MonthlyCalendarView month title = Typography.headline(17 SemiBold)。
                        style = AppType.headline,
                        color = palette.textPrimary,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                    )
                    MonthNavButton(Icons.Filled.ChevronRight, "翌月", enabled = canGoNext, onClick = onNext)
                }
                WeekdayHeader()
                state.cells.chunked(7).forEach { week ->
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
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

        // 生理日まとめ入力 entry-row(周期トラッキング ON のときだけ)。iOS StatsView の並び順:
        // カレンダー → 生理日入力 → 保険チケット → ハイライト。
        if (state.cycleTrackingEnabled) {
            MenstrualEntryRow(palette, onClick = onOpenMenstrual)
        }

        // 保険チケット(連続を守るフリーズ)。iOS は折りたたみ: 動的subtitle + 説明 + 適用導線 + 非Premium訴求。
        RescueTicketCollapsible(state, palette, onUseRescue, onOpenPremium)

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
        // Monthly = 今月。記録ゼロの月は淡色・非活性・chevron 非表示(iOS パリティ)。
        val currentMonthHasRecords = state.records.any { YearMonth.from(it.date) == YearMonth.from(today) }
        EntryCard(
            icon = Icons.Filled.Description, iconTint = palette.primaryDeep,
            title = "Monthlyハイライト",
            subtitle = if (currentMonthHasRecords) "今月のがんばりをカードでサマリー" else "今月の記録はまだありません",
            dimmed = !currentMonthHasRecords,
            onClick = { if (currentMonthHasRecords) onOpenHighlight("monthly") },
        )
        // All-time: 累計達成 / 使用日数 / 達成率(iOS subtitle「累計 N 日達成 / 使用 M 日 (R%)」)。記録ゼロは空状態。
        EntryCard(
            icon = Icons.Filled.EmojiEvents, iconTint = palette.primaryDeep,
            title = "All-timeハイライト",
            subtitle = if (state.records.isEmpty()) "まだ記録がありません"
                else "累計 ${lifetime.achievedDays} 日達成 / 使用 ${lifetime.usedDays} 日 (${(lifetime.rate * 100).toInt()}%)",
            onClick = { onOpenHighlight("alltime") },
        )

        // このアプリを友達にシェア。iOS shareAppEntry(運動履歴の前に配置)。
        val context = LocalContext.current
        EntryCard(
            icon = Icons.Filled.IosShare, iconTint = palette.primaryDeep,
            title = "このアプリを友達にシェア",
            subtitle = "インストール用リンクが LINE / メッセージなどで送れます",
            onClick = {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, "GOエクササイズで一緒に運動しよう！\nhttps://play.google.com/store/apps/details?id=com.goexercise.app")
                }
                runCatching { context.startActivity(Intent.createChooser(intent, "シェア")) }
            },
        )

        // 運動履歴(折りたたみ)。iOS 運動履歴 CollapsibleSection。
        ExerciseHistorySection(state.records)

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

/** 生理日まとめ入力への導線。iOS StatsView.menstrualEntry: ★(markColor) + 2 行テキスト + chevron, surface r18 padding14。 */
@Composable
private fun MenstrualEntryRow(palette: com.goexercise.app.ui.theme.AppTheme, onClick: () -> Unit) {
    val markColor = Color(0.86f, 0.36f, 0.45f)
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier.clickable(onClick = onClick).padding(14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text("★", color = markColor, style = AppType.screenTitle.copy(fontWeight = FontWeight.ExtraBold))
            Column(modifier = Modifier.weight(1f)) {
                Text("生理日を記録する", style = AppType.headline, color = palette.textPrimary)
                Text("過去の日付もまとめて入力できます", style = AppType.caption, color = palette.textSecondary)
            }
            Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(20.dp))
        }
    }
}

/** 保険チケットの折りたたみ。iOS: 動的subtitle「今月 N / M 回 残り」+ 説明 + 適用導線 + 非Premium訴求。 */
@Composable
private fun RescueTicketCollapsible(state: HistoryUiState, palette: AppTheme, onUseRescue: () -> Unit, onOpenPremium: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth().clickable { expanded = !expanded },
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // iOS CollapsibleSection header: アイコン(16/heavy)+ タイトル。subtitle は折りたたみ中のみ。
                Icon(Icons.Filled.ConfirmationNumber, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(20.dp))
                Column(Modifier.weight(1f)) {
                    Text("保険チケット", style = AppType.headline, color = palette.textPrimary)
                    // iOS: 展開時は本文と二重になるので subtitle を隠す(CollapsibleSection.header)。
                    if (!expanded) {
                        Text("今月 ${state.rescueRemaining} / ${state.rescueAllowance} 回 残り", style = AppType.caption, color = palette.textSecondary)
                    }
                }
                Icon(if (expanded) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore, contentDescription = null, tint = palette.textSecondary)
            }
            if (expanded) {
                val available = state.rescueRemaining > 0
                // iOS rescueTicketContent: アイコン + (残数 body + 説明 caption)。
                Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Icon(
                        Icons.Filled.ConfirmationNumber, contentDescription = null,
                        tint = if (available) palette.primary else palette.textSecondary.copy(alpha = 0.5f),
                        modifier = Modifier.size(22.dp),
                    )
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("今月 ${state.rescueRemaining} / ${state.rescueAllowance} 回 残り", style = AppType.body, color = palette.textPrimary)
                        Text("忙しい日に連続記録を守れます。毎月リセットされます。", style = AppType.caption, color = palette.textSecondary)
                    }
                }
                // iOS: 「使う日を選んで適用」= primary 塗りの目立つボタン(白文字・カレンダーアイコン・影・52dp)。
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .shadow(6.dp, RoundedCornerShape(14.dp), spotColor = palette.primary.copy(alpha = 0.30f))
                        .clip(RoundedCornerShape(14.dp))
                        .background(palette.primary)
                        .clickable { onUseRescue() }
                        .padding(horizontal = 18.dp, vertical = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Icon(Icons.Filled.EventAvailable, contentDescription = null, tint = Color.White, modifier = Modifier.size(18.dp))
                    Text("使う日を選んで適用", style = AppType.body, fontWeight = FontWeight.ExtraBold, color = Color.White, modifier = Modifier.weight(1f))
                    Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(18.dp))
                }
                // 非Premium 向け訴求(GOプレミアムで月4回)。iOS: Divider + 塗り無しの primary 文字行。
                if (!state.isPremium) {
                    HorizontalDivider(color = palette.textSecondary.copy(alpha = 0.2f))
                    Row(
                        modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { onOpenPremium() }.padding(horizontal = 14.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        // iOS StatsView は crown.fill。crown ベクターで統一(WorkspacePremium リボンから是正)。
                        Icon(ImageVector.vectorResource(com.goexercise.app.R.drawable.ic_crown), contentDescription = null, tint = palette.primary, modifier = Modifier.size(16.dp))
                        Text("GOプレミアムで保険チケットが月4回に", style = AppType.body, fontWeight = FontWeight.SemiBold, color = palette.primary, modifier = Modifier.weight(1f))
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = palette.primary, modifier = Modifier.size(16.dp))
                    }
                }
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
                if (records.isEmpty()) {
                    Text("まだ記録がありません", style = AppType.caption, color = palette.textSecondary)
                }
                // 日付でグルーピング(日付見出し sectionTitle)→ 記録ごとに HistoryRowView 相当のカード。iOS StatsView の運動履歴。
                records.groupBy { it.date }.toSortedMap(compareByDescending { it }).forEach { (date, dayRecords) ->
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            date.format(java.time.format.DateTimeFormatter.ofPattern("M月d日(E)", java.util.Locale.JAPANESE)),
                            style = AppType.sectionTitle, color = palette.textPrimary,
                        )
                        dayRecords.forEach { record -> HistoryRecordRow(record) }
                    }
                }
            }
        }
    }
}

/** 1 記録分のカード。iOS `HistoryRowView` パリティ: カテゴリ見出し(色付き)+ 種目行(名前 回 セット 時間)+ 合計 + メモ。 */
@Composable
private fun HistoryRecordRow(record: com.goexercise.app.domain.WorkoutRecord) {
    val palette = LocalAppPalette.current
    val uniqueCategories = record.exercises.mapNotNull { it.category ?: record.category }.distinct()
    Surface(color = palette.surface, shape = RoundedCornerShape(18.dp), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            if (uniqueCategories.size <= 1) {
                val category = uniqueCategories.firstOrNull() ?: record.category
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Icon(categoryIcon(category), contentDescription = null, tint = palette.categoryColor(category), modifier = Modifier.size(18.dp))
                    Text(category.displayName, style = AppType.headline, color = palette.categoryColor(category))
                }
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    record.exercises.forEach { ex ->
                        Text(exerciseLine(ex), style = AppType.body, color = palette.textPrimary)
                    }
                }
            } else {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    record.exercises.forEach { ex ->
                        val category = ex.category ?: record.category
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Icon(categoryIcon(category), contentDescription = null, tint = palette.categoryColor(category), modifier = Modifier.size(18.dp).padding(end = 0.dp))
                            Text(exerciseLine(ex), style = AppType.body, color = palette.textPrimary)
                        }
                    }
                }
            }
            val totalSeconds = record.exercises.sumOf { it.durationSeconds ?: 0 }
            if (totalSeconds > 0) {
                Text("合計 ${durationText(totalSeconds)}", style = AppType.caption, color = palette.textSecondary)
            }
            record.memo?.takeIf { it.isNotEmpty() }?.let { memo ->
                Text(memo, style = AppType.caption, color = palette.textSecondary, maxLines = 2)
            }
        }
    }
}

/** 種目1行「名前 回 セット 時間」(iOS exerciseLine: reps→sets→duration の順、半角スペース区切り)。 */
private fun exerciseLine(ex: com.goexercise.app.domain.ExerciseItem): String {
    val parts = buildList {
        add(ex.name)
        ex.reps?.let { add("${it}回") }
        ex.sets?.let { add("${it}セット") }
        ex.durationSeconds?.let { add(durationText(it)) }
    }
    return parts.joinToString(" ")
}

/** 秒 → 「X分Y秒」/「X分」/「Y秒」。iOS durationText 相当。 */
private fun durationText(seconds: Int): String {
    val m = seconds / 60
    val s = seconds % 60
    return when {
        m > 0 && s > 0 -> "${m}分${s}秒"
        m > 0 -> "${m}分"
        else -> "${s}秒"
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
            Row(
                modifier = Modifier.clip(CircleShape).background(palette.chipBackground.copy(alpha = 0.5f)).padding(horizontal = 8.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(Modifier.size(10.dp).clip(CircleShape).background(PeriodDotColor))
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
        // iOS: Future はカード地と同じ surface(空白扱い)、TodayPending は secondary@0.40。
        DailyStatus.Future -> palette.surface
        DailyStatus.TodayPending -> palette.secondary.copy(alpha = 0.40f)
    }
}

/** 生理日ドット色。iOS Color(red:0.86, green:0.36, blue:0.45)。 */
private val PeriodDotColor = Color(0.86f, 0.36f, 0.45f)

@Composable
private fun LegendSwatch(color: Color, label: String) {
    val palette = LocalAppPalette.current
    // iOS: swatch 14×14 r4、各凡例は chipBackground@0.5 のカプセルチップ。
    Row(
        modifier = Modifier.clip(CircleShape).background(palette.chipBackground.copy(alpha = 0.5f)).padding(horizontal = 8.dp, vertical = 4.dp),
        verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        Box(Modifier.size(14.dp).clip(RoundedCornerShape(4.dp)).background(color))
        // iOS は 11pt medium。caption(12sp)だと 4 チップ目がスクロール端で切れるため 11sp に合わせる。
        Text(label, color = palette.textSecondary, style = AppType.caption2.copy(fontWeight = FontWeight.Medium))
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
                    // iOS MonthlyCalendarView day = size 14, today heavy / それ以外 semibold。
                    "${date.dayOfMonth}",
                    style = AppType.caption.copy(fontSize = 14.sp, fontWeight = if (isToday) FontWeight.ExtraBold else FontWeight.SemiBold),
                    color = if (isToday) Color.White else palette.textPrimary,
                )
                if (isPeriod) {
                    Box(
                        Modifier.align(Alignment.TopEnd).padding(3.dp).size(6.dp).clip(CircleShape).background(PeriodDotColor),
                    )
                }
                // 保険チケットで救済した日は右下に ticket グリフ(iOS の ticket.fill 相当)。
                if (status == DailyStatus.Rescued) {
                    Icon(
                        Icons.Filled.ConfirmationNumber, contentDescription = "保険チケット使用",
                        tint = if (isToday) Color.White else palette.primaryDeep,
                        modifier = Modifier.align(Alignment.BottomEnd).padding(2.dp).size(10.dp),
                    )
                }
            }
        }
    }
}

/** 日セルタップ時の詳細ボトムシート。iOS `DayDetailSheet` の移植。
 *  ホーム週カレンダーの日タップからも再利用する(internal)。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
internal fun DayDetailSheet(
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
            // iOS DayDetailSheet: 中央タイトル + 右上「閉じる」(iOS26 カプセル)。
            Box(Modifier.fillMaxWidth()) {
                Text(title, style = AppType.sectionTitle, color = palette.textPrimary, modifier = Modifier.align(Alignment.Center))
                com.goexercise.app.ui.components.SheetCloseButton(onClick = onDismiss, modifier = Modifier.align(Alignment.CenterEnd))
            }
            if (records.isEmpty()) {
                // iOS DayDetailSheet は .medium detent の中央にアイコン円+メッセージを置く
                // (= 縦中央寄せ・下に余白)。Android も同等の高さの領域に中央寄せして揃える。
                val (icon, tint) = dayStatusIcon(status, palette)
                Box(Modifier.fillMaxWidth().heightIn(min = 340.dp), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                        Box(Modifier.size(92.dp).clip(CircleShape).background(tint.copy(alpha = 0.12f)), contentAlignment = Alignment.Center) {
                            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(44.dp))
                        }
                        Text(messageForStatus(status), color = palette.textSecondary, style = AppType.body, textAlign = TextAlign.Center)
                    }
                }
            } else {
                // iOS: 記録ごとに HistoryRowView カード(カテゴリ色見出し + 種目行 + 合計 + メモ)。
                records.forEach { record -> HistoryRecordRow(record) }
            }
            if (cycleTrackingEnabled && !date.isAfter(LocalDate.now())) {
                TextButton(onClick = onToggleMenstrual) {
                    Text(if (isPeriod) "生理日の登録を解除" else "この日を生理日に登録", color = palette.primaryDeep)
                }
            }
        }
    }
}

/** 空状態のアイコン+色(iOS DayDetailSheet: moon.zzz/calendar/pawprint/checkmark.seal/snowflake)。 */
// iOS iconColor: rest/future=textSecondary、missed/todayPending/achieved/rescued=primary。
// (旧 Android はカレンダー凡例色=rest/rescue を緑・missed を灰にしていたが iOS と不一致だった)
private fun dayStatusIcon(status: DailyStatus, palette: AppTheme): Pair<androidx.compose.ui.graphics.vector.ImageVector, Color> = when (status) {
    DailyStatus.Rest -> Icons.Filled.Bedtime to palette.textSecondary
    DailyStatus.Future -> Icons.Filled.Event to palette.textSecondary
    DailyStatus.Rescued -> Icons.Filled.AcUnit to palette.primary
    DailyStatus.Achieved, DailyStatus.TodayAchieved -> Icons.Filled.Verified to palette.primary
    DailyStatus.Missed, DailyStatus.TodayPending -> Icons.Filled.Pets to palette.primary
}

private fun messageForStatus(status: DailyStatus): String = when (status) {
    DailyStatus.Rest -> "この日は回復日。\n無理しないのも大事だよ"
    DailyStatus.Future -> "これからの日だね"
    DailyStatus.Missed -> "この日は記録がないよ"
    DailyStatus.TodayPending -> "今日はまだ記録がないよ"
    DailyStatus.Achieved, DailyStatus.TodayAchieved -> "記録がここに表示されます"
    DailyStatus.Rescued -> "この日は保険チケットで連続記録を継続したよ"
}
