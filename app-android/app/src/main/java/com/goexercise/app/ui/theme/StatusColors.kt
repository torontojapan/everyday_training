package com.goexercise.app.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.goexercise.app.domain.DailyStatus

// カレンダーの達成/休養/未達成は意味の固定色(テーマ非依存)。iOS MonthlyCalendarView と同値:
//   運動した日=赤強調 / 休養・フリーズ救済=緑系 / 未達成=青。
// 旧実装は palette トークン(success=緑/restDay=青/missed=赤)へ写像していたため3色とも意図と逆だった。
private val AchievedColor = Color(0xFFED544C) // iOS achieved (0.93,0.33,0.30)
private val RestColor = Color(0xFF5CA666)     // iOS rest/rescued (0.36,0.65,0.40)
private val MissedColor = Color(0xFF618CE6)   // iOS missed (0.38,0.55,0.90)

/** DailyStatus → 表示色。週/月カレンダー共通。達成/休養/未達成は iOS と同じ固定セマンティック色。 */
@Composable
fun colorForStatus(status: DailyStatus): Color = with(LocalAppPalette.current) {
    when (status) {
        DailyStatus.TodayAchieved -> primary   // 今日かつ達成=ブランド強調
        DailyStatus.Achieved -> AchievedColor  // 運動した日=赤
        DailyStatus.Rescued -> RestColor       // フリーズ救済(○)=緑系
        DailyStatus.Rest -> RestColor          // 休養=緑系
        DailyStatus.Missed -> MissedColor      // 未達成=青
        DailyStatus.TodayPending -> secondary
        DailyStatus.Future -> chipBackground
    }
}
