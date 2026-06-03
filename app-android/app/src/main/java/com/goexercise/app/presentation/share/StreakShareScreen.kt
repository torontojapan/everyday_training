package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.hilt.navigation.compose.hiltViewModel
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.StreakLevel
import com.goexercise.app.share.StreakShareImageRenderer
import com.goexercise.app.ui.theme.LocalAppPalette

/** シェア画面のエントリ。VM から連続日数/猫種を購読して [StreakShareContent] に渡す。 */
@Composable
fun StreakShareRoute(
    onBack: () -> Unit = {},
    viewModel: StreakShareViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    StreakShareContent(streak = state.streak, breed = state.breed, onBack = onBack)
}

/** ステートレスなシェア本体。カード画像をプレビューし、共有 chooser を開く。 */
@Composable
fun StreakShareContent(streak: Int, breed: CatBreed, onBack: () -> Unit = {}) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    val level = StreakLevel.of(streak)

    // プレビューは共有と同一の Canvas レンダラから生成(WYSIWYG)。streak/breed 変化時のみ再生成。
    val preview = remember(streak, breed) {
        StreakShareImageRenderer.render(context, streak, breed).asImageBitmap()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Text(
            level.headline,
            color = palette.textPrimary,
            fontWeight = FontWeight.Bold,
            fontSize = 22.sp,
            modifier = Modifier.padding(top = 12.dp),
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(24.dp)),
        ) {
            Image(
                bitmap = preview,
                contentDescription = "${streak}日連続のシェア画像",
                contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Button(
            onClick = { StreakShareImageRenderer.share(context, streak, breed) },
            modifier = Modifier.fillMaxWidth(),
            enabled = streak > 0,
        ) {
            Text(if (streak > 0) "SNSでシェア" else "まず1日記録してみよう")
        }

        TextButton(onClick = onBack) {
            Text("閉じる", color = palette.textSecondary)
        }
    }
}
