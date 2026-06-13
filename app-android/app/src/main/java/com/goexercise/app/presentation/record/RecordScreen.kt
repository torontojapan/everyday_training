package com.goexercise.app.presentation.record

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.LaunchedEffect
import com.goexercise.app.domain.WorkoutCategory
import com.goexercise.app.ui.theme.LocalAppPalette

/** Record ルートのエントリ。保存完了は one-shot イベントで onSaved、戻るで onBack。 */
@Composable
fun RecordRoute(
    onSaved: () -> Unit = {},
    onBack: () -> Unit = {},
    viewModel: RecordViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    LaunchedEffect(Unit) {
        viewModel.saved.collect { onSaved() }
    }
    RecordContent(
        state = state,
        onBack = onBack,
        onCategory = viewModel::setCategory,
        onMemo = viewModel::setMemo,
        onUpdateDraft = viewModel::updateDraft,
        onAddExercise = viewModel::addExercise,
        onRemoveExercise = viewModel::removeExercise,
        onAddSet = viewModel::addSet,
        onSave = viewModel::save,
    )
}

@Composable
fun RecordContent(
    state: RecordUiState,
    onBack: () -> Unit = {},
    onCategory: (String, WorkoutCategory) -> Unit = { _, _ -> },
    onMemo: (String) -> Unit = {},
    onUpdateDraft: (String, (ExerciseDraft) -> ExerciseDraft) -> Unit = { _, _ -> },
    onAddExercise: () -> Unit = {},
    onRemoveExercise: (String) -> Unit = {},
    onAddSet: (String) -> Unit = {},
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
            TextButton(onClick = onBack) { Text("戻る") }
            Text("記録する", fontWeight = FontWeight.Bold, fontSize = 20.sp, color = palette.textPrimary)
        }

        state.drafts.forEach { draft ->
            ExerciseDraftCard(
                draft = draft,
                canRemove = state.drafts.size > 1,
                onCategory = { cat -> onCategory(draft.id, cat) },
                onChange = { updated -> onUpdateDraft(draft.id) { updated } },
                onRemove = { onRemoveExercise(draft.id) },
                onAddSet = { onAddSet(draft.id) },
            )
        }

        TextButton(onClick = onAddExercise) { Text("＋ 種目を追加") }

        OutlinedTextField(
            value = state.memo,
            onValueChange = onMemo,
            label = { Text("メモ(任意)") },
            modifier = Modifier.fillMaxWidth(),
        )

        Button(
            onClick = onSave,
            enabled = state.canSave,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(if (state.isSaving) "保存中…" else "保存する")
        }
        state.errorMessage?.let { Text(it, color = palette.missed, fontSize = 12.sp) }
        if (state.validExercises().isEmpty()) {
            Text("種目名を1つ以上入力してください", color = palette.textSecondary, fontSize = 12.sp)
        }
    }
}

@Composable
private fun ExerciseDraftCard(
    draft: ExerciseDraft,
    canRemove: Boolean,
    onCategory: (WorkoutCategory) -> Unit,
    onChange: (ExerciseDraft) -> Unit,
    onRemove: () -> Unit,
    onAddSet: () -> Unit,
) {
    val palette = LocalAppPalette.current
    Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            // 種目ごとのカテゴリ選択(複数カテゴリ混在可)。
            Row(
                modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                WorkoutCategory.entries.forEach { cat ->
                    FilterChip(selected = draft.category == cat, onClick = { onCategory(cat) }, label = { Text(cat.displayName) })
                }
            }
            OutlinedTextField(
                value = draft.name,
                onValueChange = { onChange(draft.copy(name = it)) },
                label = { Text("種目名") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                NumberField("分", draft.minutes, RecordUiState.minutesMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(minutes = it)) }
                NumberField("回数", draft.reps, RecordUiState.countMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(reps = it)) }
                NumberField("セット", draft.sets, RecordUiState.countMaxDigits, Modifier.weight(1f)) { onChange(draft.copy(sets = it)) }
            }
            // 重さ(kg)フリー入力(ダンベル等の負荷。小数可)。iOS パリティ。
            OutlinedTextField(
                value = draft.loadText,
                onValueChange = { onChange(draft.copy(loadText = RecordUiState.clampDecimal(it))) },
                label = { Text("重さ (kg)") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                modifier = Modifier.fillMaxWidth(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                TextButton(onClick = onAddSet) { Text("＋ 同じ種目でセットを追加") }
                if (canRemove) {
                    TextButton(onClick = onRemove) { Text("削除") }
                }
            }
        }
    }
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
