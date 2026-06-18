package com.goexercise.app.presentation.record

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.ui.theme.LocalAppPalette

/** 記録完了画面のエントリ。直近の連続日数/猫種/状態を購読して祝福を出す。iOS RecordCompletionView 相当。 */
@Composable
fun RecordCompletionRoute(
    onDone: () -> Unit = {},
    onRecordAgain: () -> Unit = {},
    viewModel: RecordCompletionViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    RecordCompletionContent(
        streak = state.streak,
        breed = state.breed,
        catState = state.catState,
        onDone = onDone,
        onRecordAgain = onRecordAgain,
    )
}

/** 記録直後の祝福(祝福猫 + 称賛リボン + 連続日数ヒーロー + もう一種目/ホームに戻る)。iOS パリティ。 */
@Composable
fun RecordCompletionContent(
    streak: Int,
    breed: CatBreed,
    catState: CatState,
    onDone: () -> Unit = {},
    onRecordAgain: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    // 称賛リボン(iOS praiseRibbons と同文)。提示ごとに固定。
    val ribbon = rememberSaveable { praiseRibbons.random() }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp, Alignment.CenterVertically),
    ) {
        // 祝福の猫(達成/連続更新)。
        com.goexercise.app.ui.components.CatImage(
            breed = breed,
            state = catState,
            modifier = Modifier.size(220.dp),
            useShaker = false,
        )
        // 称賛リボン。
        Text(ribbon, fontSize = 26.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep)
        // 連続日数ヒーロー(一番のごほうび)。
        if (streak > 0) {
            Text("$streak 日連続", fontSize = 34.sp, fontWeight = FontWeight.Black, color = palette.textPrimary)
        }
        Text("記録しました。今日もよくがんばったね。", fontSize = 14.sp, color = palette.textSecondary)

        Spacer(Modifier.height(8.dp))
        OutlinedButton(onClick = onRecordAgain, modifier = Modifier.fillMaxWidth()) {
            Text("＋ もう一種目を記録する")
        }
        Button(onClick = onDone, modifier = Modifier.fillMaxWidth()) {
            Text("ホームに戻る")
        }
    }
}

private val praiseRibbons = listOf(
    "お見事！", "ナイス継続！", "今日もえらい！", "素晴らしい！", "やったね！", "完璧！", "天才！", "コツコツ最強！",
)
