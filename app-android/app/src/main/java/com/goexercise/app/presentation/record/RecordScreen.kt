package com.goexercise.app.presentation.record

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.clickable
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AddCircle
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.Button
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.LaunchedEffect
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.ui.theme.AppType
import com.goexercise.app.ui.theme.LocalAppPalette
import com.goexercise.app.ui.theme.categoryIcon

/** Record ルートのエントリ。保存完了は one-shot イベントで onSaved、戻るで onBack。 */
@Composable
fun RecordRoute(
    onSaved: () -> Unit = {},
    onBack: () -> Unit = {},
    viewModel: RecordViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val suggestions by viewModel.suggestionsByCategory.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        viewModel.saved.collect { onSaved() }
    }
    RecordContent(
        state = state,
        suggestionsByCategory = suggestions,
        onBack = onBack,
        onCategory = viewModel::setCategory,
        onMemo = viewModel::setMemo,
        onUpdateDraft = viewModel::updateDraft,
        onAddExercise = viewModel::addExercise,
        onRemoveExercise = viewModel::removeExercise,
        onAddSet = viewModel::addSet,
        onWeightInput = viewModel::setWeightInput,
        onMenstrualToday = viewModel::setMenstrualToday,
        onSave = viewModel::save,
    )
}

@Composable
fun RecordContent(
    state: RecordUiState,
    suggestionsByCategory: Map<WorkoutCategory, List<String>> = emptyMap(),
    onBack: () -> Unit = {},
    onCategory: (String, WorkoutCategory) -> Unit = { _, _ -> },
    onMemo: (String) -> Unit = {},
    onUpdateDraft: (String, (ExerciseDraft) -> ExerciseDraft) -> Unit = { _, _ -> },
    onAddExercise: () -> Unit = {},
    onRemoveExercise: (String) -> Unit = {},
    onAddSet: (String) -> Unit = {},
    onWeightInput: (String) -> Unit = {},
    onMenstrualToday: (Boolean) -> Unit = {},
    onSave: () -> Unit = {},
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
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("閉じる") }
            Text("今日の記録", style = AppType.headline, color = palette.textPrimary)
        }

        // iOS Form の Section("種目") ヘッダ(RecordEntryView.swift:25)。体調・周期/今日の体重/メモ と同じ
        // bold-14 見出しで種目リストの上に置く(欠落していた=2026-06-21 density393 横並びで発見)。
        Text("種目", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)

        // アコーディオン: 入力中の1種目だけ展開し、他は最小化(iOS ExerciseInputRow パリティ)。
        var expandedId by remember { mutableStateOf(state.drafts.firstOrNull()?.id) }
        androidx.compose.runtime.LaunchedEffect(state.drafts.size) {
            // 追加/削除で件数が変わったら最後の種目を開く(追加=新規を展開)。
            expandedId = state.drafts.lastOrNull()?.id
        }
        state.drafts.forEach { draft ->
            ExerciseDraftCard(
                draft = draft,
                canRemove = state.drafts.size > 1,
                expanded = expandedId == draft.id,
                onToggleExpand = { expandedId = if (expandedId == draft.id) null else draft.id },
                suggestions = suggestionsByCategory[draft.category].orEmpty(),
                onCategory = { cat -> onCategory(draft.id, cat) },
                onChange = { updated -> onUpdateDraft(draft.id) { updated } },
                onRemove = { onRemoveExercise(draft.id) },
                onAddSet = { onAddSet(draft.id) },
            )
        }

        TextButton(onClick = onAddExercise) {
            Icon(Icons.Filled.AddCircle, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(18.dp))
            Spacer(Modifier.size(6.dp))
            Text("種目を追加", color = palette.primaryDeep)
        }

        // 体調・周期(周期トラッキング ON のときだけ独立セクション。iOS Section「体調・周期」を体重の前に置く)。
        if (state.cycleTrackingEnabled) {
            Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
                Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("体調・周期", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("今日は生理日", color = palette.textPrimary, modifier = Modifier.weight(1f))
                        Switch(checked = state.menstrualToday, onCheckedChange = onMenstrualToday)
                    }
                }
            }
        }

        // 今日の体重(任意)。記録と同じ保存操作で永続化(iOS RecordEntryView パリティ)。
        Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("今日の体重 (任意)", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
                FilledField(
                    value = state.weightInput,
                    onValueChange = onWeightInput,
                    placeholder = "体重 (kg)",
                    modifier = Modifier.fillMaxWidth(),
                    fill = palette.chipBackground.copy(alpha = 0.5f),
                    corner = 12.dp,
                    borderColor = if (state.hasWeightInputButInvalid) palette.missed else null,
                    borderWidth = 1.5.dp,
                    paddingH = 12.dp, paddingV = 12.dp, fontSize = 17.sp, fontWeight = FontWeight.Normal,  // parity-allow: 入力フィールド本文サイズ(iOS TextField 該当pt準拠・density393照合済)
                    keyboardType = KeyboardType.Decimal,
                )
                // 無効な体重は理由を info アイコン付きで表示、正常時は前回値ヒント(iOS disabledReason / hint)。
                val reason = state.weightDisabledReason
                if (reason != null) {
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Filled.Info, contentDescription = null, tint = palette.missed, modifier = Modifier.size(14.dp))
                        Text(reason, color = palette.missed, style = AppType.caption)
                    }
                } else {
                    Text(
                        state.latestWeightKg?.let { "前回: ${"%.1f".format(it)} kg" }
                            ?: "体重を入れるとグラフに反映されます",
                        color = palette.textSecondary, style = AppType.caption,
                    )
                }
            }
        }

        // メモ(iOS Section「メモ」。カード内に複数行フィールド)。
        Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("メモ", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
                FilledField(
                    value = state.memo,
                    onValueChange = onMemo,
                    placeholder = "体調や気分など",
                    modifier = Modifier.fillMaxWidth(),
                    fill = palette.chipBackground.copy(alpha = 0.5f),
                    corner = 12.dp, paddingH = 12.dp, paddingV = 12.dp, fontSize = 17.sp, fontWeight = FontWeight.Normal,  // parity-allow: 入力フィールド本文サイズ(iOS TextField 該当pt準拠・density393照合済)
                    singleLine = false, minLines = 3, maxLines = 5,
                )
            }
        }

        Button(
            onClick = onSave,
            enabled = state.canSave,
            modifier = Modifier.fillMaxWidth(),
        ) {
            if (!state.isSaving) {
                Icon(Icons.Filled.CheckCircle, contentDescription = null, modifier = Modifier.size(18.dp))
                Spacer(Modifier.size(8.dp))
            }
            Text(if (state.isSaving) "保存中…" else "保存")
        }
        state.errorMessage?.let { Text(it, color = palette.missed, style = AppType.caption) }
        if (state.validExercises().isEmpty()) {
            Text("種目名を1つ以上入力してください", color = palette.textSecondary, style = AppType.caption)
        }
    }
}

/** 種目カード。iOS ExerciseInputRow パリティ: 折りたたみ(最小化)/展開、種類ラベル、カテゴリ、種目名、
 *  よく使う種目(空ヒント付き)、時間/回数/セット/重さ を1行、同じ種目でセット追加、種目メモ。 */
@Composable
private fun ExerciseDraftCard(
    draft: ExerciseDraft,
    canRemove: Boolean,
    expanded: Boolean,
    onToggleExpand: () -> Unit,
    suggestions: List<String> = emptyList(),
    onCategory: (WorkoutCategory) -> Unit,
    onChange: (ExerciseDraft) -> Unit,
    onRemove: () -> Unit,
    onAddSet: () -> Unit,
) {
    val palette = LocalAppPalette.current
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        if (!expanded) {
            // 最小化行: アイコン + 名前(未入力) + サマリ + chevron。タップで展開。
            Row(
                modifier = Modifier.fillMaxWidth().clickable { onToggleExpand() }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                Icon(categoryIcon(draft.category), contentDescription = null, tint = palette.primary, modifier = Modifier.size(20.dp))
                Column(Modifier.weight(1f)) {
                    Text(
                        draft.name.ifBlank { "種目名 未入力" },
                        color = if (draft.name.isBlank()) palette.textSecondary else palette.textPrimary,
                        style = AppType.body,
                    )
                    Text(collapsedSummary(draft), color = palette.textSecondary, style = AppType.caption)
                }
                Icon(Icons.Filled.KeyboardArrowDown, contentDescription = "展開", tint = palette.textSecondary, modifier = Modifier.size(20.dp))
            }
            return@Surface
        }
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // ヘッダ: 「種類」ラベル + 削除(trash) + 最小化(chevron up)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("種類", color = palette.textSecondary, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold))
                Spacer(Modifier.weight(1f))
                if (canRemove) {
                    Icon(
                        Icons.Filled.Delete, contentDescription = "種目を削除", tint = Color(0xFFD32F2F),  // parity-allow: iOS .red 相当の破壊的アクション色(削除)
                        modifier = Modifier.size(20.dp).clickable { onRemove() },
                    )
                    Spacer(Modifier.size(12.dp))
                }
                Icon(Icons.Filled.KeyboardArrowUp, contentDescription = "最小化", tint = palette.textSecondary, modifier = Modifier.size(20.dp).clickable { onToggleExpand() })
            }
            // カテゴリ選択(iOS: 選択=コーラル塗り+白 / 非選択=chipBackground@0.6 + primary@0.35 枠のカプセル)
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                WorkoutCategory.entries.forEach { cat ->
                    CategoryChip(cat, selected = draft.category == cat, onClick = { onCategory(cat) })
                }
            }
            // 種目名(ラベル + chipBackground@0.5 塗り + primary@0.45 1.5dp 枠の角丸フィールド。iOS ExerciseInputRow)
            Text("種目名", color = palette.textSecondary, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold))
            FilledField(
                value = draft.name,
                onValueChange = { onChange(draft.copy(name = it)) },
                placeholder = "例: スクワット",
                modifier = Modifier.fillMaxWidth(),
                fill = palette.chipBackground.copy(alpha = 0.5f),
                corner = 12.dp, borderColor = palette.primary.copy(alpha = 0.45f), borderWidth = 1.5.dp,
                paddingH = 12.dp, paddingV = 12.dp, fontSize = 16.sp,  // parity-allow: 入力フィールド本文サイズ(iOS TextField 該当pt準拠・density393照合済)
            )
            // よく使う種目(履歴+日本語デフォルト)。iOS は候補ありの時だけ見出し。
            if (suggestions.isNotEmpty()) {
                Text("よく使う種目", color = palette.textSecondary, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold))
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    suggestions.forEach { name -> SuggestionChip(name) { onChange(draft.copy(name = name)) } }
                }
            } else {
                Text("履歴がたまると、ここによく使う種目が出ます", color = palette.textSecondary, style = AppType.caption)
            }
            // 時間/回数/セット/重さ を1行(iOS 4列)。各列=ラベル上 + 同一スタイル/同一高さの chipBackground@0.6 角丸ボックス。
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.Top) {
                PickerColumn("時間 (分)", draft.minutes, minuteOptions, "分", Modifier.weight(1f)) { onChange(draft.copy(minutes = if (it == 0) "" else "$it")) }
                PickerColumn("回数", draft.reps, repOptions, "回", Modifier.weight(1f)) { onChange(draft.copy(reps = if (it == 0) "" else "$it")) }
                PickerColumn("セット", draft.sets, setOptions, "", Modifier.weight(1f)) { onChange(draft.copy(sets = if (it == 0) "" else "$it")) }
                // 重さ(kg): フリー入力。ピッカーと同じ高さ・同じ塗りに揃える(中央寄せ)。
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text("重さ (kg)", color = palette.textSecondary, maxLines = 1, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold))
                    FilledField(
                        value = draft.loadText,
                        onValueChange = { onChange(draft.copy(loadText = RecordUiState.clampDecimal(it))) },
                        placeholder = "0",
                        modifier = Modifier.fillMaxWidth(),
                        fill = palette.chipBackground.copy(alpha = 0.6f),
                        corner = 10.dp, paddingH = 10.dp, paddingV = 9.dp, fontSize = 15.sp,  // parity-allow: 入力フィールド本文サイズ(iOS TextField 該当pt準拠・density393照合済)
                        center = true, keyboardType = KeyboardType.Decimal,
                    )
                }
            }
            // 同じ種目でセットを追加(名前入力済の時だけ。iOS パリティ)
            if (draft.name.isNotBlank()) {
                TextButton(onClick = onAddSet, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                    Icon(Icons.Filled.AddCircle, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.size(4.dp))
                    Text("同じ種目でセットを追加", color = palette.primaryDeep)
                }
            }
            // 種目メモ(chipBackground@0.6 塗りの角丸フィールド。iOS パリティ)
            FilledField(
                value = draft.memo,
                onValueChange = { onChange(draft.copy(memo = it)) },
                placeholder = "種目メモ (例: 体調メモ、回数アップ等)",
                modifier = Modifier.fillMaxWidth(),
                fill = palette.chipBackground.copy(alpha = 0.6f),
                corner = 10.dp, paddingH = 10.dp, paddingV = 8.dp, fontSize = 17.sp, fontWeight = FontWeight.Normal,  // parity-allow: 入力フィールド本文サイズ(iOS TextField 該当pt準拠・density393照合済)
            )
        }
    }
}

/** 最小化行のサマリ「カテゴリ・30分・3回・3セット・10kg」。iOS collapsedSummary パリティ。 */
private fun collapsedSummary(draft: ExerciseDraft): String {
    val parts = mutableListOf(draft.category.displayName)
    draft.minutes.toIntOrNull()?.takeIf { it > 0 }?.let { parts += "${it}分" }
    draft.reps.toIntOrNull()?.takeIf { it > 0 }?.let { parts += "${it}回" }
    draft.sets.toIntOrNull()?.takeIf { it > 0 }?.let { parts += "${it}セット" }
    draft.loadText.toDoubleOrNull()?.takeIf { it > 0 }?.let { kg ->
        parts += if (kg % 1.0 == 0.0) "${kg.toInt()}kg" else "${kg}kg"
    }
    return parts.joinToString("・")
}

// iOS のピッカー選択肢: 時間 = 0..100 step5、回数 = 0..50、セット = 0..10(0 は「—」)。
private val minuteOptions = (0..100 step 5).toList()
private val repOptions = (0..50).toList()
private val setOptions = (0..10).toList()

/** 時間/回数/セットの列(ラベル上 + chipBackground@0.6 塗りの角丸ボックス + プルダウン)。iOS labeledPicker 相当。
 *  ボックスは重さフィールドと同じ塗り・角丸・縦パディングで**高さを揃える**(4列の不揃いを防ぐ)。 */
@Composable
private fun PickerColumn(label: String, value: String, options: List<Int>, unit: String, modifier: Modifier, onSelect: (Int) -> Unit) {
    val palette = LocalAppPalette.current
    var open by remember { mutableStateOf(false) }
    val current = value.toIntOrNull() ?: 0
    // iOS labeledPicker: 選択値・項目とも単位付き(例「30分」「3回」)。0 は「—」。
    fun display(n: Int) = if (n == 0) "—" else "$n$unit"
    Column(modifier, verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(label, color = palette.textSecondary, maxLines = 1, style = AppType.caption2.copy(fontWeight = FontWeight.SemiBold))
        Box {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(10.dp))
                    .background(palette.chipBackground.copy(alpha = 0.6f))
                    .clickable { open = true }
                    .padding(horizontal = 10.dp, vertical = 9.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    display(current),
                    color = if (current == 0) palette.textSecondary else palette.textPrimary,
                    style = AppType.body, maxLines = 1, modifier = Modifier.weight(1f),
                )
                Icon(Icons.Filled.UnfoldMore, contentDescription = null, tint = palette.textSecondary, modifier = Modifier.size(14.dp))
            }
            DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
                options.forEach { opt ->
                    DropdownMenuItem(
                        text = { Text(display(opt)) },
                        onClick = { onSelect(opt); open = false },
                    )
                }
            }
        }
    }
}

/** chipBackground 塗りのコンパクトな角丸入力欄(BasicTextField)。iOS の Form フィールド(塗り+角丸)を移植。
 *  Material OutlinedTextField(白地・固定高 ~56dp)は使わない(色も高さも iOS と不一致になるため)。 */
@Composable
private fun FilledField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    fill: Color,
    corner: androidx.compose.ui.unit.Dp = 10.dp,
    borderColor: Color? = null,
    borderWidth: androidx.compose.ui.unit.Dp = 1.5.dp,
    paddingH: androidx.compose.ui.unit.Dp = 10.dp,
    paddingV: androidx.compose.ui.unit.Dp = 9.dp,
    fontSize: androidx.compose.ui.unit.TextUnit = 15.sp,
    fontWeight: FontWeight = FontWeight.SemiBold,
    center: Boolean = false,
    keyboardType: KeyboardType = KeyboardType.Text,
    singleLine: Boolean = true,
    minLines: Int = 1,
    maxLines: Int = if (singleLine) 1 else 5,
) {
    val palette = LocalAppPalette.current
    val shape = RoundedCornerShape(corner)
    val align = if (center) TextAlign.Center else TextAlign.Start
    androidx.compose.foundation.text.BasicTextField(
        value = value,
        onValueChange = onValueChange,
        singleLine = singleLine,
        minLines = minLines,
        maxLines = maxLines,
        textStyle = androidx.compose.ui.text.TextStyle(color = palette.textPrimary, fontSize = fontSize, fontWeight = fontWeight, textAlign = align),
        keyboardOptions = KeyboardOptions(keyboardType = keyboardType),
        cursorBrush = androidx.compose.ui.graphics.SolidColor(palette.primary),
        modifier = modifier,
        decorationBox = { inner ->
            Box(
                Modifier
                    .fillMaxWidth()
                    .clip(shape)
                    .background(fill)
                    .then(if (borderColor != null) Modifier.border(borderWidth, borderColor, shape) else Modifier)
                    .padding(horizontal = paddingH, vertical = paddingV),
                contentAlignment = if (center) Alignment.Center else Alignment.CenterStart,
            ) {
                if (value.isEmpty()) {
                    Text(
                        placeholder, color = palette.textSecondary, fontSize = fontSize, fontWeight = fontWeight,
                        textAlign = align, modifier = if (center) Modifier.fillMaxWidth() else Modifier,
                    )
                }
                inner()
            }
        },
    )
}

/** カテゴリ選択カプセル。iOS: 選択=primary 塗り+白 / 非選択=chipBackground@0.6 + primary@0.35 1.2dp 枠。 */
@Composable
private fun CategoryChip(category: WorkoutCategory, selected: Boolean, onClick: () -> Unit) {
    val palette = LocalAppPalette.current
    val shape = RoundedCornerShape(50)
    Row(
        modifier = Modifier
            .clip(shape)
            .background(if (selected) palette.primary else palette.chipBackground.copy(alpha = 0.6f))
            .then(if (selected) Modifier else Modifier.border(1.2.dp, palette.primary.copy(alpha = 0.35f), shape))
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 9.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Icon(categoryIcon(category), contentDescription = null, tint = if (selected) Color.White else palette.textPrimary, modifier = Modifier.size(14.dp))
        Text(category.displayName, color = if (selected) Color.White else palette.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 1)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
    }
}

/** 候補種目チップ。iOS: chipBackground@0.6 カプセル + primary@0.25 1dp 枠(選択ハイライト無し、タップで入力)。 */
@Composable
private fun SuggestionChip(name: String, onClick: () -> Unit) {
    val palette = LocalAppPalette.current
    val shape = RoundedCornerShape(50)
    Box(
        modifier = Modifier
            .clip(shape)
            .background(palette.chipBackground.copy(alpha = 0.6f))
            .border(1.dp, palette.primary.copy(alpha = 0.25f), shape)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Text(name, color = palette.textPrimary, fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 1)  // parity-allow: Android カードセクション/チップ見出し適応(iOS Form header/chip 相当・density393照合済)
    }
}
