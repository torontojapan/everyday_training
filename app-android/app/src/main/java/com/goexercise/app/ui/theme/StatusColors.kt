package com.goexercise.app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.goexercise.app.domain.DailyStatus

/** DailyStatus → 表示色。週/月カレンダー共通。LocalAppPalette のトークンに写像。 */
@Composable
fun colorForStatus(status: DailyStatus): Color = with(LocalAppPalette.current) {
    when (status) {
        DailyStatus.TodayAchieved -> primary
        DailyStatus.Achieved -> success
        // 救済(○)は休養・フリーズと同系の緑(iOS 配色: 運動=赤強調 / 休養・救済=緑系 / 未達成=青)。
        DailyStatus.Rescued -> restDay
        DailyStatus.Rest -> restDay
        DailyStatus.Missed -> missed
        DailyStatus.TodayPending -> secondary
        DailyStatus.Future -> chipBackground
    }
}
