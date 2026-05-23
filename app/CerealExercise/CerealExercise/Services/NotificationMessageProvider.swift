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
            messages = [
                "🐱「今週いい感じだよ。今日も続けよ？」",
                "🐱「あと少しで今週の達成率が上がるよ」",
                "🐱「今週の流れ、守っていこ？」"
            ]
        } else if slot == .evening || currentStreak > 0 {
            messages = [
                "🐱「今日の連続記録、まだ守れるよ」",
                "🐱「あと少しで今日の記録が残せるよ」",
                "🐱「今日の記録、まだ待ってるよ」"
            ]
        } else {
            messages = [
                "🐱「今日の運動、そろそろ一緒にやろ？」",
                "🐱「1分だけでも記録しよ？」",
                "🐱「今日も少しだけ体を動かしてみよ？」",
                "🐱「無理しなくていいから、ちょっとだけやろ？」"
            ]
        }

        let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
        let slotOffset = slot == .morning ? 0 : 1
        let index = abs(day + slotOffset) % messages.count
        return messages[index]
    }
}
