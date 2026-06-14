package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
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
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
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
    StreakShareContent(
        streak = state.streak,
        breed = state.breed,
        gradient = state.gradient,
        onSelectGradient = viewModel::setGradient,
        onBack = onBack,
    )
}

/** ステートレスなシェア本体。カード画像をプレビューし、共有 chooser を開く。 */
@Composable
fun StreakShareContent(
    streak: Int,
    breed: CatBreed,
    gradient: com.goexercise.app.domain.ShareCardGradient = com.goexercise.app.domain.ShareCardGradient.Default,
    onSelectGradient: (com.goexercise.app.domain.ShareCardGradient) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val level = StreakLevel.of(streak)
    // 提示ごとに固定のポーズ seed(プレビューと実シェアで同じハッピーポーズが出るよう共有)。
    val poseSeed = rememberSaveable { (0..9999).random() }

    // プレビューは共有と同一の Canvas レンダラから生成(WYSIWYG)。1080×1440 の描画は重いので
    // Default ディスパッチャで生成し、完了まで null(スピナー表示)。streak/breed 変化時のみ再生成。
    val preview by produceState<ImageBitmap?>(initialValue = null, streak, breed, poseSeed, gradient) {
        value = withContext(Dispatchers.Default) {
            StreakShareImageRenderer.render(context, streak, breed, poseSeed, gradient).asImageBitmap()
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

        // 背景グラデーション ピッカー(5種・選択は永続化)。iOS パリティ。
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            com.goexercise.app.domain.ShareCardGradient.entries.forEach { g ->
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(
                            androidx.compose.ui.graphics.Brush.linearGradient(g.colors.map { androidx.compose.ui.graphics.Color(it) }),
                        )
                        .then(
                            if (g == gradient) Modifier.border(3.dp, palette.primaryDeep, CircleShape)
                            else Modifier.border(1.dp, palette.textSecondary.copy(alpha = 0.3f), CircleShape),
                        )
                        .clickable { onSelectGradient(g) },
                )
            }
        }

        Button(
            onClick = { scope.launch { StreakShareImageRenderer.share(context, streak, breed, poseSeed, gradient) } },
            modifier = Modifier.fillMaxWidth(),
            enabled = streak > 0,
        ) {
            Text(if (streak > 0) "SNSでシェア" else "まず1日記録してみよう")
        }

        // 写真に保存(端末ギャラリーへ。iOS saveToPhotos パリティ)。
        if (streak > 0) {
            fun doSave() {
                scope.launch {
                    val ok = StreakShareImageRenderer.saveToGallery(context, streak, breed, poseSeed, gradient)
                    android.widget.Toast.makeText(
                        context,
                        if (ok) "写真に保存しました" else "保存に失敗しました",
                        android.widget.Toast.LENGTH_SHORT,
                    ).show()
                }
            }
            // API 28- は MediaStore への書き込みに WRITE_EXTERNAL_STORAGE が要る(Codex 指摘)。Q+ は権限不要。
            val saveLauncher = androidx.activity.compose.rememberLauncherForActivityResult(
                androidx.activity.result.contract.ActivityResultContracts.RequestPermission(),
            ) { granted ->
                if (granted) doSave()
                else android.widget.Toast.makeText(context, "保存には写真へのアクセス許可が必要です", android.widget.Toast.LENGTH_SHORT).show()
            }
            TextButton(
                onClick = {
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q ||
                        context.checkSelfPermission(android.Manifest.permission.WRITE_EXTERNAL_STORAGE) == android.content.pm.PackageManager.PERMISSION_GRANTED
                    ) {
                        doSave()
                    } else {
                        saveLauncher.launch(android.Manifest.permission.WRITE_EXTERNAL_STORAGE)
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("写真に保存", color = palette.primaryDeep) }
        }

        TextButton(onClick = onBack) {
            Text("閉じる", color = palette.textSecondary)
        }
    }
}
