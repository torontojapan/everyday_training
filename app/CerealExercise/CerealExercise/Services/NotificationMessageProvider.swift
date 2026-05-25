import Foundation

enum NotificationSlot: Sendable {
    case morning
    case evening
}

enum NotificationMessageProvider {
    static func message(
        for slot: NotificationSlot,
        currentStreak: Int,
        weeklyProgressRate: Double,
        seedDate: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let messages: [String]

        if weeklyProgressRate >= 0.5 {
            // 今週の達成率が良好。維持を促すトーン。
            messages = [
                "🐱「今週いい感じだよ。今日も続けよ？」",
                "🐱「あと少しで今週の達成率が上がるよ」",
                "🐱「今週の流れ、守っていこ？」",
                "🐱「いい調子。今日もちょこっとやろ？」",
                "🐱「今週のがんばり、まだ伸ばせるね」",
                "🐱「このペース、続けたら週末いい気分だよ」",
                "🐱「今日もちょっとだけ、いつもの調子で」",
                "🐱「今週の自分、すでにえらいよ」",
                "🐱「いい流れ、もう一日プラスしてみよ？」"
            ]
        } else if slot == .evening || currentStreak > 0 {
            // 連続記録がある or 夜の時間帯。途切れさせない方向で励ます。
            messages = [
                "🐱「今日の連続記録、まだ守れるよ」",
                "🐱「あと少しで今日の記録が残せるよ」",
                "🐱「今日の記録、まだ待ってるよ」",
                "🐱「1分だけでも続けたら連続記録キープだよ」",
                "🐱「今日のぶん、まだ間に合うよ」",
                "🐱「お疲れさま。ストレッチ1つで OK だよ」",
                "🐱「寝る前に1種目だけ、どう？」",
                "🐱「今日も会えてうれしい。記録残そ？」",
                "🐱「焦らなくていい、自分のペースで残そ」"
            ]
        } else {
            // 連続記録なし + 朝。やさしく誘うトーン。
            messages = [
                "🐱「今日の運動、そろそろ一緒にやろ？」",
                "🐱「1分だけでも記録しよ？」",
                "🐱「今日も少しだけ体を動かしてみよ？」",
                "🐱「無理しなくていいから、ちょっとだけやろ？」",
                "🐱「ストレッチ1つでも OK だよ」",
                "🐱「今日も一緒に体動かそ？」",
                "🐱「軽くでいいから、はじめてみよ」",
                "🐱「やる気が出ないときほど、1分だけ」",
                "🐱「気が向いたタイミングで OK だよ」",
                "🐱「今日もそばにいるよ、待ってるね」"
            ]
        }

        let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
        let slotOffset = slot == .morning ? 0 : 1
        let index = abs(day + slotOffset) % messages.count
        return messages[index]
    }
}
