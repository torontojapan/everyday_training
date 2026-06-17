package com.goexercise.app.presentation.share

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
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
    onBack: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val poseSeed = rememberSaveable { (0..9999).random() }

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
            kind.title,
            color = palette.textPrimary,
            fontWeight = FontWeight.Bold,
            fontSize = 22.sp,
            modifier = Modifier.padding(top = 12.dp),
        )

        // プレビュー(共有と同一の Canvas レンダラから生成。WYSIWYG)。review 確定後のみ描画。
        val preview by produceState<ImageBitmap?>(initialValue = null, review, breed, poseSeed) {
            val r = review
            value = if (r == null) {
                null
            } else {
                withContext(Dispatchers.Default) {
                    HighlightShareImageRenderer.render(context, r, kind, breed, streakLabel, poseSeed).asImageBitmap()
                }
            }
        }

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(1080f / 2340f) // スマホ全画面比。生成前もカードの場所を確保。
                .clip(RoundedCornerShape(24.dp)),
            contentAlignment = Alignment.Center,
        ) {
            preview?.let { bmp ->
                Image(
                    bitmap = bmp,
                    contentDescription = "${kind.title}のシェア画像",
                    contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth(),
                )
            } ?: CircularProgressIndicator(color = palette.primaryDeep)
        }

        if (review != null) {
            Button(
                onClick = { scope.launch { HighlightShareImageRenderer.share(context, review, kind, breed, streakLabel, poseSeed) } },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("SNSでシェア")
            }

            // 写真に保存(端末ギャラリーへ。iOS saveToPhotos パリティ)。
            fun doSave() {
                scope.launch {
                    val ok = HighlightShareImageRenderer.saveToGallery(context, review, kind, breed, streakLabel, poseSeed)
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
