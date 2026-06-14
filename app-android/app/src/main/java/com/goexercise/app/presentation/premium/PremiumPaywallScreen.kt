package com.goexercise.app.presentation.premium

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import androidx.core.net.toUri
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.lifecycle.viewmodel.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.goexercise.app.data.billing.ProductIds
import com.goexercise.app.ui.theme.AppTheme
import com.goexercise.app.ui.theme.LocalAppPalette

/** ペイウォールを開いた文脈で見出しを出し分ける。iOS PremiumPaywallSheet.Context。 */
enum class PaywallContext(val headline: String) {
    Weight("体重タブの全機能を解放しよう"),
    Freeze("保険チケットを月4回に"),
    General("GOプレミアムで全機能を解放"),
}

private const val PRIVACY_URL = "https://torontojapan.github.io/everyday_training/privacy"
private const val TERMS_URL = "https://torontojapan.github.io/everyday_training/terms"

@Composable
fun PremiumPaywallRoute(
    context: PaywallContext = PaywallContext.General,
    onClose: () -> Unit = {},
    onPurchased: () -> Unit = {},
    viewModel: PremiumViewModel = hiltViewModel(),
) {
    val isPremium by viewModel.isPremiumActive.collectAsStateWithLifecycle()
    val trialEligible by viewModel.isTrialEligible.collectAsStateWithLifecycle()
    val isWorking by viewModel.isWorking.collectAsStateWithLifecycle()
    val error by viewModel.lastError.collectAsStateWithLifecycle()
    val prices by viewModel.prices.collectAsStateWithLifecycle()
    val activity = LocalContext.current.findActivity()

    // 購入/復元でプレミアムが有効になったら閉じる(購入完了は isPremiumActive の遷移で観測)。
    LaunchedEffect(isPremium) {
        if (isPremium) { onPurchased(); onClose() }
    }

    PremiumPaywallContent(
        context = context,
        prices = prices,
        trialEligible = trialEligible,
        isWorking = isWorking,
        error = error,
        onClose = onClose,
        onPurchase = { productId -> activity?.let { viewModel.purchase(it, productId) } },
        onRestore = viewModel::restore,
        onClearError = viewModel::clearError,
    )
}

@Composable
fun PremiumPaywallContent(
    context: PaywallContext,
    prices: Map<String, String>,
    trialEligible: Boolean = true,
    isWorking: Boolean,
    error: String?,
    onClose: () -> Unit = {},
    onPurchase: (String) -> Unit = {},
    onRestore: () -> Unit = {},
    onClearError: () -> Unit = {},
) {
    val palette = LocalAppPalette.current
    val ctx = LocalContext.current
    var selected by remember { mutableStateOf(ProductIds.PREMIUM_YEARLY) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.background)
            .verticalScroll(rememberScrollState())
            .padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("GOプレミアム", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
            Spacer(Modifier.weight(1f))
            TextButton(onClick = onClose) { Text("✕", fontSize = 18.sp, color = palette.textSecondary) }
        }

        // トライアル適格による出し分け文言は PaywallCopy に集約(誤「14日間無料」表示=審査リスク回避)。
        val copy = PaywallCopy.strings(trialEligible)

        // ヘッダー
        Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("👑", fontSize = 48.sp)
            Text(context.headline, fontSize = 20.sp, fontWeight = FontWeight.Black, color = palette.textPrimary, textAlign = TextAlign.Center)
            Text(
                copy.subhead,
                fontSize = 13.sp, color = palette.textSecondary, textAlign = TextAlign.Center,
            )
        }

        // 特典
        Surface(color = palette.surface, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                benefit("⚖️", "体重の記録 + 推移グラフ(日 / 週 / 月)", palette)
                benefit("📈", "週次 / 月次レポート + トレンドライン", palette)
                benefit("🌙", "周期オーバーレイで体調と体重を重ねて可視化", palette)
                benefit("🎯", "目標 / BMI / 達成リング / 進捗バー", palette)
                benefit("❄️", "保険チケット 月4回(無料は月1回)", palette)
                benefit("✨", "減量ご褒美マイルストーン(-3 / -5 / -10 kg)", palette)
            }
        }

        // プラン選択
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            planCard(ProductIds.PREMIUM_YEARLY, "年額", "${prices[ProductIds.PREMIUM_YEARLY]} / 年", "実質 約¥317/月 ・ 月額より約34%お得", "おすすめ", selected == ProductIds.PREMIUM_YEARLY, palette) { selected = ProductIds.PREMIUM_YEARLY }
            planCard(ProductIds.PREMIUM_MONTHLY, "月額", "${prices[ProductIds.PREMIUM_MONTHLY]} / 月", "まずは気軽に", null, selected == ProductIds.PREMIUM_MONTHLY, palette) { selected = ProductIds.PREMIUM_MONTHLY }
        }

        // 購入ボタン
        Button(
            onClick = { onPurchase(selected) },
            enabled = !isWorking,
            colors = ButtonDefaults.buttonColors(containerColor = palette.primary),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) {
            if (isWorking) {
                CircularProgressIndicator(color = androidx.compose.ui.graphics.Color.White, modifier = Modifier.size(20.dp))
            } else {
                Text(copy.cta, fontSize = 16.sp, fontWeight = FontWeight.Black, color = androidx.compose.ui.graphics.Color.White)
            }
        }

        if (error != null) {
            Surface(color = palette.chipBackground, shape = RoundedCornerShape(8.dp), modifier = Modifier.fillMaxWidth()) {
                Row(Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(error, fontSize = 12.sp, color = palette.primaryDeep, modifier = Modifier.weight(1f))
                    TextButton(onClick = onClearError) { Text("閉じる", fontSize = 12.sp, color = palette.primaryDeep) }
                }
            }
        }

        TextButton(onClick = onRestore, enabled = !isWorking, modifier = Modifier.align(Alignment.CenterHorizontally)) {
            Text("購入を復元", fontSize = 14.sp, fontWeight = FontWeight.SemiBold, color = palette.primary)
        }

        // サブスク開示(審査必須: 価格・周期・自動更新・トライアル後課金・解約方法)
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
            Text("サブスクリプションについて", fontSize = 12.sp, fontWeight = FontWeight.Black, color = palette.textPrimary)
            disclosure(copy.autoRenewDisclosure, palette)
            disclosure("・自動更新: 期間終了の24時間前までに解約しない限り自動で更新されます", palette)
            disclosure("・解約方法: Google Play ストア > メニュー > 定期購入 からいつでも解約できます", palette)
            disclosure("・料金は Google Play アカウントに請求されます", palette)
            copy.freeTrialCancelNote?.let { disclosure(it, palette) }
        }

        // 法務リンク
        Row(horizontalArrangement = Arrangement.spacedBy(16.dp), modifier = Modifier.align(Alignment.CenterHorizontally)) {
            legalLink("利用規約", TERMS_URL, ctx, palette)
            legalLink("プライバシーポリシー", PRIVACY_URL, ctx, palette)
        }
        Spacer(Modifier.height(8.dp))
    }
}

@Composable
private fun benefit(icon: String, text: String, palette: AppTheme) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(icon, fontSize = 18.sp)
        Text(text, fontSize = 14.sp, color = palette.textPrimary, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun planCard(
    productId: String,
    title: String,
    price: String,
    caption: String,
    badge: String?,
    selected: Boolean,
    palette: AppTheme,
    onClick: () -> Unit,
) {
    Surface(
        color = if (selected) palette.primary.copy(alpha = 0.08f) else palette.surface,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .border(
                width = if (selected) 2.dp else 1.dp,
                color = if (selected) palette.primary else palette.primary.copy(alpha = 0.15f),
                shape = RoundedCornerShape(16.dp),
            )
            .clickable(onClick = onClick),
    ) {
        Row(Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Text(if (selected) "🔘" else "⚪", fontSize = 18.sp)
            Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(title, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = palette.textPrimary)
                    if (badge != null) {
                        Surface(color = palette.primary, shape = RoundedCornerShape(50)) {
                            Text(badge, fontSize = 10.sp, fontWeight = FontWeight.Black, color = androidx.compose.ui.graphics.Color.White, modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp))
                        }
                    }
                }
                Text(caption, fontSize = 12.sp, color = palette.textSecondary)
            }
            Text(price, fontSize = 14.sp, fontWeight = FontWeight.Black, color = palette.primaryDeep)
        }
    }
}

@Composable
private fun disclosure(text: String, palette: AppTheme) {
    Text(text, fontSize = 11.sp, color = palette.textSecondary)
}

@Composable
private fun legalLink(label: String, url: String, ctx: Context, palette: AppTheme) {
    Text(
        label,
        fontSize = 12.sp,
        fontWeight = FontWeight.SemiBold,
        color = palette.primary,
        textDecoration = TextDecoration.Underline,
        modifier = Modifier.clickable {
            runCatching { ctx.startActivity(Intent(Intent.ACTION_VIEW, url.toUri())) }
        },
    )
}

/** Compose の LocalContext から Activity を辿る(launchBillingFlow に必要)。 */
private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
