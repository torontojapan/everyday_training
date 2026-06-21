import Foundation

struct WidgetSnapshot: Codable, Equatable, Sendable {
    let generatedAt: Date
    let todayAchieved: Bool
    let isRestDay: Bool
    let currentStreak: Int
    let weeklyAchieved: Int
    let weeklyTotal: Int
    /// 今週(月→日)の7日分の状態。ウィジェット/ライブアクティビティの「今週ストリップ」用。
    /// 古いスナップショットに無い場合は decode 時に空配列で許容(描画側で 7 個に補完)。
    let weeklyStatuses: [DailyStatus]
    let catState: String
    let message: String
    let nightDeadlineHoursLeft: Int

    enum CodingKeys: String, CodingKey {
        case generatedAt, todayAchieved, isRestDay, currentStreak, weeklyAchieved, weeklyTotal
        case weeklyStatuses, catState, message, nightDeadlineHoursLeft
    }

    init(generatedAt: Date, todayAchieved: Bool, isRestDay: Bool, currentStreak: Int,
         weeklyAchieved: Int, weeklyTotal: Int, weeklyStatuses: [DailyStatus] = [],
         catState: String, message: String, nightDeadlineHoursLeft: Int) {
        self.generatedAt = generatedAt
        self.todayAchieved = todayAchieved
        self.isRestDay = isRestDay
        self.currentStreak = currentStreak
        self.weeklyAchieved = weeklyAchieved
        self.weeklyTotal = weeklyTotal
        self.weeklyStatuses = weeklyStatuses
        self.catState = catState
        self.message = message
        self.nightDeadlineHoursLeft = nightDeadlineHoursLeft
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        generatedAt = try c.decode(Date.self, forKey: .generatedAt)
        todayAchieved = try c.decode(Bool.self, forKey: .todayAchieved)
        isRestDay = try c.decode(Bool.self, forKey: .isRestDay)
        currentStreak = try c.decode(Int.self, forKey: .currentStreak)
        weeklyAchieved = try c.decode(Int.self, forKey: .weeklyAchieved)
        weeklyTotal = try c.decode(Int.self, forKey: .weeklyTotal)
        weeklyStatuses = try c.decodeIfPresent([DailyStatus].self, forKey: .weeklyStatuses) ?? []
        catState = try c.decode(String.self, forKey: .catState)
        message = try c.decode(String.self, forKey: .message)
        nightDeadlineHoursLeft = try c.decode(Int.self, forKey: .nightDeadlineHoursLeft)
    }

    /// タイムラインの各 entry は同一スナップショットを使い回すため、生成日と異なる「翌日以降」の
    /// entry では当日状態(達成/休養/締切)が古くなる。日付が変わった entry は「新しい日・未記録」
    /// として描画し直す(監査 P1: 翌朝までウィジェットが「達成済み」で固着し、記録誘導チップが
    /// 隠れてしまう。書込み側は同じ date-blind 対策を既に持つ=表示側の漏れ)。
    /// 連続日数は「昨日まで」基準なので据え置く。週次カウントは月曜跨ぎでわずかに甘くなるが据え置く。
    func projected(to entryDate: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        guard !calendar.isDate(entryDate, inSameDayAs: generatedAt) else { return self }
        // 新しい日はまだ未記録。時間帯で待機/心配/お願いの表情とメッセージを選ぶ(資格情報不要な近似)。
        let hour = calendar.component(.hour, from: entryDate)
        let state: CatState
        let msg: String
        switch hour {
        case ..<11:   state = .waitingMorning; msg = "今日も体を動かそう"
        case 11..<18: state = .worriedNoon;    msg = "まだ間に合うよ、1分だけでも"
        default:      state = .beggingNight;   msg = "寝る前に1分だけでも"
        }
        let startOfDay = calendar.startOfDay(for: entryDate)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? entryDate
        let endOfDay = calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? entryDate
        let hoursLeft = max(0, calendar.dateComponents([.hour], from: entryDate, to: endOfDay).hour ?? 0)
        return WidgetSnapshot(
            generatedAt: generatedAt,    // 生成時刻は保持(次回 app 更新で正しく上書きされる)
            todayAchieved: false,
            isRestDay: false,
            currentStreak: currentStreak,
            weeklyAchieved: weeklyAchieved,
            weeklyTotal: weeklyTotal,
            weeklyStatuses: weeklyStatuses,   // 週ストリップは据え置き(翌日でも今週の達成は不変)
            catState: state.rawValue,
            message: msg,
            nightDeadlineHoursLeft: hoursLeft
        )
    }

    static func make(
        generatedAt: Date,
        todayAchieved: Bool,
        isRestDay: Bool,
        currentStreak: Int,
        weeklyAchieved: Int,
        weeklyTotal: Int,
        weeklyStatuses: [DailyStatus] = [],
        catState: CatState,
        message: String,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        let startOfDay = calendar.startOfDay(for: generatedAt)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? generatedAt
        let endOfDay = calendar.date(byAdding: .minute, value: -1, to: tomorrow) ?? generatedAt
        let hoursLeft = max(0, calendar.dateComponents([.hour], from: generatedAt, to: endOfDay).hour ?? 0)

        return WidgetSnapshot(
            generatedAt: generatedAt,
            todayAchieved: todayAchieved,
            isRestDay: isRestDay,
            currentStreak: currentStreak,
            weeklyAchieved: weeklyAchieved,
            weeklyTotal: weeklyTotal,
            weeklyStatuses: weeklyStatuses,
            catState: catState.rawValue,
            message: message,
            nightDeadlineHoursLeft: hoursLeft
        )
    }
}
