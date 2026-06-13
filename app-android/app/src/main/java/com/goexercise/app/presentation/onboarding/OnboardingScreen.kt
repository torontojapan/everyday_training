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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.lifecycle.compose.collectAsStateWithLifecycle
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
    viewModel: OnboardingViewModel? = null,
) {
    val palette = LocalAppPalette.current
    // 回転/Activity 再生成でも選択を保持(rememberSaveable は enum 不可なので rawValue を保存)。
    var selectedRaw by rememberSaveable { mutableStateOf(initialBreed.rawValue) }
    val selected = CatBreed.fromRaw(selectedRaw)
    // 2ステップ: 0=猫選択 / 1=サインイン(任意)。iOS の2ステップ ウィザード パリティ(#15)。
    var step by rememberSaveable { mutableStateOf(0) }

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
        Text(
            if (step == 0) "一緒にがんばる猫を選ぼう" else "記録をバックアップしよう",
            fontSize = 18.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary,
        )
        Text(
            // 猫種は「初回は全解放・以降の変更はプレミアム(or 紹介⭐10)」。オンボで「いつでも変更」と
            // 誤誘導すると有料ゲートに不意打ちされるため、iOS UserCatPicker と同じく制限を明記する。
            if (step == 0) "選んだ猫はホーム画面・達成演出・友達一覧で使われます。今だけ全種類から自由に選べます(あとで種類を変えるにはプレミアムが必要)。"
            else "Apple か Google で連携すると、機種変更や再インストールでも記録が戻ります(あとで設定からでも可)。",
            fontSize = 13.sp, color = palette.textSecondary,
        )

      if (step == 0) {
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

        if (viewModel != null && com.goexercise.app.AppFeatureFlags.isReferralActive) {
            val accepted by viewModel.inviteAccepted.collectAsStateWithLifecycle()
            if (accepted) {
                Text("招待コードを適用しました！", color = palette.primaryDeep)
            } else {
                val inviteCode by viewModel.inviteCode.collectAsStateWithLifecycle()
                val submitting by viewModel.inviteSubmitting.collectAsStateWithLifecycle()
                val inviteErr by viewModel.inviteError.collectAsStateWithLifecycle()
                com.goexercise.app.presentation.referral.InviteCodeField(
                    code = inviteCode,
                    onCodeChange = viewModel::onInviteCodeChange,
                    isSubmitting = submitting,
                    onSubmit = viewModel::submitInvite,
                )
                inviteErr?.let { Text(it, color = MaterialTheme.colorScheme.error) }
            }
        }

        Spacer(Modifier.height(4.dp))
        Button(
            onClick = { step = 1 },
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            Text("つぎへ", color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
      } else {
        // ステップ2: サインイン→バックアップ自動ON(任意・スキップ可)。実機でのみ動作(emulator不可)。
        val context = androidx.compose.ui.platform.LocalContext.current
        val linking = viewModel?.isLinkingAccount?.collectAsStateWithLifecycle()?.value ?: false
        val linkErr = viewModel?.linkError?.collectAsStateWithLifecycle()?.value
        Button(
            onClick = { viewModel?.linkApple(context) { onFinish(selected) } },
            enabled = !linking,
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("Apple で連携してはじめる", color = Color.White, fontWeight = FontWeight.Bold) }
        Button(
            onClick = { viewModel?.linkGoogle(context) { onFinish(selected) } },
            enabled = !linking,
            colors = ButtonDefaults.buttonColors(containerColor = palette.primaryDeep),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("Google で連携してはじめる", color = Color.White, fontWeight = FontWeight.Bold) }
        androidx.compose.material3.TextButton(
            onClick = { onFinish(selected) },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("あとで(スキップ)", color = palette.textSecondary) }
        linkErr?.let { Text(it, color = MaterialTheme.colorScheme.error, fontSize = 12.sp) }
      }
        Spacer(Modifier.height(8.dp))
    }
}
