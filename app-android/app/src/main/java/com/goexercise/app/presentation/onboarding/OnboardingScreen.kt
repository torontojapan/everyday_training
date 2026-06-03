package com.goexercise.app.presentation.onboarding

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.CatState
import com.goexercise.app.ui.components.CatAvatar
import com.goexercise.app.ui.components.CatImage
import com.goexercise.app.ui.theme.LocalAppPalette

/**
 * 初回起動の「ようこそ」オンボーディング。一緒にがんばる猫を 11 種から選ぶ。iOS `UserCatPickerView`
 * (isOnboarding) の移植。選んだ猫はホーム/達成演出/友達アバターで使われる(あとから設定で変更可)。
 */
@Composable
fun OnboardingScreen(
    initialBreed: CatBreed = CatBreed.Default,
    onFinish: (CatBreed) -> Unit,
) {
    val palette = LocalAppPalette.current
    // 回転/Activity 再生成でも選択を保持(rememberSaveable は enum 不可なので rawValue を保存)。
    var selectedRaw by rememberSaveable { mutableStateOf(initialBreed.rawValue) }
    val selected = CatBreed.fromRaw(selectedRaw)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Spacer(Modifier.height(8.dp))
        Text("ようこそ 🐾", fontSize = 24.sp, fontWeight = FontWeight.Black, color = palette.textPrimary)
        Text("一緒にがんばる猫を選ぼう", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
        Text(
            "選んだ猫はホーム画面・達成演出・友達一覧で使われます。あとから設定でいつでも変更できます。",
            fontSize = 13.sp, color = palette.textSecondary,
        )

        // 選択中の猫の大プレビュー
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            CatImage(breed = selected, state = CatState.WaitingMorning, modifier = Modifier.size(160.dp))
        }
        Text(selected.displayName, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = palette.primaryDeep, modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)

        // 11 種グリッド(4 列)
        CatBreed.entries.chunked(4).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { breed ->
                    Column(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(12.dp))
                            .then(if (breed == selected) Modifier.border(2.dp, palette.primary, RoundedCornerShape(12.dp)) else Modifier)
                            .clickable { selectedRaw = breed.rawValue }
                            .padding(vertical = 6.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        CatAvatar(breed = breed, size = 56.dp)
                        Text(breed.displayName, fontSize = 10.sp, color = palette.textPrimary, maxLines = 1)
                    }
                }
                repeat(4 - row.size) { Box(Modifier.weight(1f)) }
            }
        }

        Spacer(Modifier.height(4.dp))
        Button(
            onClick = { onFinish(selected) },
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            Text("この猫ではじめる", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(8.dp))
    }
}
