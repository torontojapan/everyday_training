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

/**
 * DailyStatus → 表示色。週ストリップ/友達週ストリップ共通(iOS WeeklyCalendarView / FriendWeekStripView と同値)。
 * ★iOS は固定 RGB を**低不透明度**で背景に重ねる(やわらかいパステル)。以前 Android は同 RGB を
 *  全不透明で塗っていたため鮮やかすぎ、iOS と色が違って見えた(ユーザー指摘 2026-06-19)。iOS の alpha を移植:
 *  今日=primary@0.95 / 達成@0.65 / 休養@0.60 / 救済@0.35 / 未達@0.32 / 未来=secondary@0.45。
 */
@Composable
fun colorForStatus(status: DailyStatus): Color = with(LocalAppPalette.current) {
    when (status) {
        // iOS は「今日」セルを status 不問で primary@0.95 にする(isToday が status 判定より優先)。
        DailyStatus.TodayAchieved -> primary.copy(alpha = 0.95f)
        DailyStatus.TodayPending -> primary.copy(alpha = 0.95f)
        DailyStatus.Achieved -> AchievedColor.copy(alpha = 0.65f)  // 運動した日=赤
        DailyStatus.Rest -> RestColor.copy(alpha = 0.60f)          // 休養=緑系
        DailyStatus.Rescued -> RestColor.copy(alpha = 0.35f)       // フリーズ救済(○)=緑系・淡め
        DailyStatus.Missed -> MissedColor.copy(alpha = 0.32f)      // 未達成=青
        DailyStatus.Future -> secondary.copy(alpha = 0.45f)        // 未来=淡いセカンダリ
    }
}
