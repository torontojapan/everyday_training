package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
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
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.domain.CatBreed
import com.goexercise.app.domain.MonthlyReviewBuilder
import com.goexercise.app.share.HighlightShareImageRenderer
import com.goexercise.app.ui.theme.LocalAppPalette
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** ハイライト共有画面のエントリ。VM から集計済み Review/猫種を購読して本体に渡す。 */
@Composable
fun HighlightShareRoute(
    onBack: () -> Unit = {},
    viewModel: HighlightShareViewModel = hiltViewModel(),
) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    HighlightShareContent(
        review = state.review,
        kind = state.kind,
        breed = state.breed,
        streakLabel = state.streakLabel,
        gradient = state.gradient,
        onSelectGradient = viewModel::setGradient,
        onBack = onBack,
    )
}

/** ステートレス本体。カード画像をプレビューし、共有 chooser / 写真に保存を提供する。 */
@Composable
fun HighlightShareContent(
    review: MonthlyReviewBuilder.Review?,
    kind: HighlightShareImageRenderer.Kind,
    breed: CatBreed,
    streakLabel: String,
    gradient: com.goexercise.app.domain.ShareCardGradient? = null,
    onSelectGradient: (com.goexercise.app.domain.ShareCardGradient) -> Unit = {},
    onBack: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val poseSeed = rememberSaveable { (0..9999).random() }

    // プレビュー(共有と同一の Canvas レンダラから生成。WYSIWYG)。review/gradient 確定後のみ描画。
    val preview by produceState<ImageBitmap?>(initialValue = null, review, breed, poseSeed, gradient) {
        val r = review
        value = if (r == null) null else withContext(Dispatchers.Default) {
            HighlightShareImageRenderer.render(context, r, kind, breed, streakLabel, poseSeed, gradient).asImageBitmap()
        }
    }

    Column(
        modifier = Modifier.fillMaxSize().background(palette.background).padding(horizontal = 20.dp, vertical = 12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(kind.title, color = palette.textPrimary, fontWeight = FontWeight.Bold, fontSize = 22.sp)

        // プレビューは残り領域に収まるよう Fit でスケール(全画面比カードを縮小表示)。
        // これにより下のグラデ選択 + ボタンが常に1画面に収まる(以前は全画面化でピッカーが画面外だった)。
        Box(modifier = Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            preview?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "${kind.title}のシェア画像",
                    contentScale = ContentScale.Fit,
                    modifier = Modifier.fillMaxSize().clip(RoundedCornerShape(24.dp)),
                )
            } ?: CircularProgressIndicator(color = palette.primaryDeep)
        }

        // 背景グラデ ピッカー(5種・選択は永続化。再タップで種別既定色へ)。iOS ShareGradientPicker パリティ。
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            com.goexercise.app.domain.ShareCardGradient.entries.forEach { g ->
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(androidx.compose.ui.graphics.Brush.linearGradient(g.colors.map { androidx.compose.ui.graphics.Color(it) }))
                        .then(
                            if (g == gradient) Modifier.border(3.dp, palette.primaryDeep, CircleShape)
                            else Modifier.border(1.dp, palette.textSecondary.copy(alpha = 0.3f), CircleShape),
                        )
                        .clickable { onSelectGradient(g) },
                )
            }
        }

        if (review != null) {
            Button(
                onClick = { scope.launch { HighlightShareImageRenderer.share(context, review, kind, breed, streakLabel, poseSeed, gradient) } },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("SNSで共有")
            }

            // 写真に保存(端末ギャラリーへ。iOS saveToPhotos パリティ)。
            fun doSave() {
                scope.launch {
                    val ok = HighlightShareImageRenderer.saveToGallery(context, review, kind, breed, streakLabel, poseSeed, gradient)
                    android.widget.Toast.makeText(
                        context,
                        if (ok) "写真に保存しました" else "保存に失敗しました",
                        android.widget.Toast.LENGTH_SHORT,
                    ).show()
                }
            }
            // API 28- は MediaStore 書き込みに WRITE_EXTERNAL_STORAGE が要る。Q+ は権限不要(StreakShare と同方針)。
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
