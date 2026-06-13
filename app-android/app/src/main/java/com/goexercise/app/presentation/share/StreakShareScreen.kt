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
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
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
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

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
    val scope = rememberCoroutineScope()
    val level = StreakLevel.of(streak)
    // 提示ごとに固定のポーズ seed(プレビューと実シェアで同じハッピーポーズが出るよう共有)。
    val poseSeed = rememberSaveable { (0..9999).random() }

    // プレビューは共有と同一の Canvas レンダラから生成(WYSIWYG)。1080×1440 の描画は重いので
    // Default ディスパッチャで生成し、完了まで null(スピナー表示)。streak/breed 変化時のみ再生成。
    val preview by produceState<ImageBitmap?>(initialValue = null, streak, breed, poseSeed) {
        value = withContext(Dispatchers.Default) {
            StreakShareImageRenderer.render(context, streak, breed, poseSeed).asImageBitmap()
        }
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
                .aspectRatio(1080f / 1440f) // 生成前もカードの場所を確保(レイアウトのガタつき防止)。
                .clip(RoundedCornerShape(24.dp)),
            contentAlignment = Alignment.Center,
        ) {
            preview?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "${streak}日連続のシェア画像",
                    contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth(),
                )
            } ?: CircularProgressIndicator(color = palette.primaryDeep)
        }

        Button(
            onClick = { scope.launch { StreakShareImageRenderer.share(context, streak, breed, poseSeed) } },
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
