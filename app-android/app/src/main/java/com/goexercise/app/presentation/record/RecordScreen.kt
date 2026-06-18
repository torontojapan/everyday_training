package com.goexercise.app.presentation.record

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Button
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.LaunchedEffect
import com.goexercise.app.domain.WorkoutCategory
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
            Text("今日の記録", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = palette.textPrimary)
        }

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

        // 今日の体重(任意)+ 生理日トグル。記録と同じ保存操作で永続化(iOS RecordEntryView パリティ)。
        Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("今日の体重 (任意)", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
                OutlinedTextField(
                    value = state.weightInput,
                    onValueChange = onWeightInput,
                    label = { Text("体重 (kg)") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                Text(
                    state.latestWeightKg?.let { "前回: ${"%.1f".format(it)} kg" }
                        ?: "体重を入れるとグラフに反映されます",
                    color = palette.textSecondary, fontSize = 12.sp,
                )
                if (state.cycleTrackingEnabled) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("今日は生理日", color = palette.textPrimary, modifier = Modifier.weight(1f))
                        Switch(checked = state.menstrualToday, onCheckedChange = onMenstrualToday)
                    }
                }
            }
        }

        Text("メモ", color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        OutlinedTextField(
            value = state.memo,
            onValueChange = onMemo,
            placeholder = { Text("体調や気分など") },
            modifier = Modifier.fillMaxWidth(),
        )

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
        state.errorMessage?.let { Text(it, color = palette.missed, fontSize = 12.sp) }
        if (state.validExercises().isEmpty()) {
            Text("種目名を1つ以上入力してください", color = palette.textSecondary, fontSize = 12.sp)
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
                        fontWeight = FontWeight.SemiBold,
                    )
                    Text(collapsedSummary(draft), color = palette.textSecondary, fontSize = 12.sp)
                }
                Icon(Icons.Filled.KeyboardArrowDown, contentDescription = "展開", tint = palette.textSecondary, modifier = Modifier.size(20.dp))
            }
            return@Surface
        }
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // ヘッダ: 「種類」ラベル + 削除(trash) + 最小化(chevron up)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text("種類", color = palette.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.weight(1f))
                if (canRemove) {
                    Icon(
                        Icons.Filled.Delete, contentDescription = "種目を削除", tint = Color(0xFFD32F2F),
                        modifier = Modifier.size(20.dp).clickable { onRemove() },
                    )
                    Spacer(Modifier.size(12.dp))
                }
                Icon(Icons.Filled.KeyboardArrowUp, contentDescription = "最小化", tint = palette.textSecondary, modifier = Modifier.size(20.dp).clickable { onToggleExpand() })
            }
            // カテゴリ選択(コーラル塗り+白文字/白アイコン)
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                WorkoutCategory.entries.forEach { cat ->
                    FilterChip(
                        selected = draft.category == cat,
                        onClick = { onCategory(cat) },
                        label = { Text(cat.displayName) },
                        leadingIcon = { Icon(categoryIcon(cat), contentDescription = null, modifier = Modifier.size(16.dp)) },
                        colors = androidx.compose.material3.FilterChipDefaults.filterChipColors(
                            selectedContainerColor = palette.primary,
                            selectedLabelColor = Color.White,
                            selectedLeadingIconColor = Color.White,
                        ),
                    )
                }
            }
            // 種目名(ラベル + フィールド)
            Text("種目名", color = palette.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            OutlinedTextField(
                value = draft.name,
                onValueChange = { onChange(draft.copy(name = it)) },
                placeholder = { Text("例: スクワット") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            // よく使う種目(履歴+日本語デフォルト)。空ならヒント。
            Text("よく使う種目", color = palette.textSecondary, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
            if (suggestions.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    suggestions.forEach { name ->
                        FilterChip(
                            selected = draft.name == name,
                            onClick = { onChange(draft.copy(name = name)) },
                            label = { Text(name) },
                        )
                    }
                }
            } else {
                Text("履歴がたまると、ここによく使う種目が出ます", color = palette.textSecondary, fontSize = 12.sp)
            }
            // 時間/回数/セット/重さ を1行(iOS 4列パリティ)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                NumberField("時間 (分)", draft.minutes, RecordUiState.minutesMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(minutes = it)) }
                NumberField("回数", draft.reps, RecordUiState.countMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(reps = it)) }
                NumberField("セット", draft.sets, RecordUiState.countMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(sets = it)) }
                OutlinedTextField(
                    value = draft.loadText,
                    onValueChange = { onChange(draft.copy(loadText = RecordUiState.clampDecimal(it))) },
                    label = { Text("重さ") },
                    placeholder = { Text("0") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.weight(1f),
                )
            }
            // 同じ種目でセットを追加(名前入力済の時だけ。iOS パリティ)
            if (draft.name.isNotBlank()) {
                TextButton(onClick = onAddSet, contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp)) {
                    Icon(Icons.Filled.AddCircle, contentDescription = null, tint = palette.primaryDeep, modifier = Modifier.size(16.dp))
                    Spacer(Modifier.size(4.dp))
                    Text("同じ種目でセットを追加", color = palette.primaryDeep)
                }
            }
            // 種目メモ
            OutlinedTextField(
                value = draft.memo,
                onValueChange = { onChange(draft.copy(memo = it)) },
                placeholder = { Text("種目メモ (例: 体調メモ、回数アップ等)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
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

@Composable
private fun NumberField(label: String, value: String, maxDigits: Int, modifier: Modifier, onValueChange: (String) -> Unit) {
    OutlinedTextField(
        value = value,
        onValueChange = { input -> onValueChange(RecordUiState.clampDigits(input, maxDigits)) },
        label = { Text(label) },
        singleLine = true,
        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        modifier = modifier,
    )
}
