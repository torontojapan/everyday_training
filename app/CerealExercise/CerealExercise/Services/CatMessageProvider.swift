import Foundation

enum DayTime: Sendable {
    case morning
    case noon
    case evening
    case night

    init(date: Date, calendar: Calendar = .current) {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11: self = .morning
        case 11..<16: self = .noon
        case 16..<21: self = .evening
        default: self = .night
        }
    }
}

struct CatMessage: Equatable, Sendable {
    let emoji: String
    let text: String
}

enum CatMessageProvider {
    static func message(for state: CatState, seedDate: Date = Date(), calendar: Calendar = .current) -> CatMessage {
        let messages: [String] = switch state {
        case .waitingMorning:
            ["今日も1分だけやってみよ？", "今日も少しだけ体を動かしてみよ？"]
        case .worriedNoon:
            ["そろそろ一緒に体を動かそ？", "無理しなくていいから、ちょっとだけやろ？"]
        case .beggingNight:
            ["今日の連続記録、まだ守れるよ", "あと少しで今日の記録が残せるよ"]
        case .celebrating:
            ["今日も達成！えらい！", "1分でも続けたのがすごいよ", "今日の記録、ちゃんと残せたね", "いい感じ！また明日も待ってるね"]
        case .streakExtended:
            ["連続記録更新！すごいよ", "今日も続いたね。大成功！", "いい流れ、ちゃんと守れたね"]
        case .resting:
            ["今日は回復日だね", "休むことも継続の一部だよ", "明日に向けて整えよう", "無理しないのも大事だよ"]
        case .encouraging:
            ["今日からまた一緒に始めよ？", "少しだけ体を動かしてみない？", "今ならまだ間に合うよ"]
        }

        return CatMessage(emoji: state.emoji, text: pickedMessage(from: messages, seedDate: seedDate, calendar: calendar))
    }

    static func message(for status: DailyStatus, time: DayTime, seedDate: Date = Date(), calendar: Calendar = .current) -> CatMessage {
        let messages: [String]

        switch status {
        case .todayAchieved, .achieved:
            messages = [
                "今日も達成！えらい！",
                "1分でも続けたのがすごいよ",
                "今日の記録、ちゃんと残せたね",
                "いい感じ！また明日も待ってるね"
            ]
        case .rest:
            messages = [
                "今日は回復日だね",
                "休むことも継続の一部だよ",
                "明日に向けて整えよう",
                "無理しないのも大事だよ"
            ]
        case .todayPending:
            messages = pendingMessages(for: time)
        case .missed:
            messages = [
                "今日からまた一緒に始めよ？",
                "少しだけ体を動かしてみない？",
                "今週の流れ、守っていこ？"
            ]
        case .future:
            messages = [
                "明日も少しだけ待ってるね",
                "次の運動も一緒にやろ？"
            ]
        }

        return CatMessage(emoji: "🐱", text: pickedMessage(from: messages, seedDate: seedDate, calendar: calendar))
    }

    private static func pickedMessage(from messages: [String], seedDate: Date, calendar: Calendar) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
        let index = messages.isEmpty ? 0 : abs(day) % messages.count
        return messages[index]
    }

    private static func pendingMessages(for time: DayTime) -> [String] {
        switch time {
        case .morning:
            ["今日も1分だけやってみよ？", "今日も少しだけ体を動かしてみよ？"]
        case .noon:
            ["そろそろ一緒に体を動かそ？", "無理しなくていいから、ちょっとだけやろ？"]
        case .evening:
            ["今日の記録、まだ待ってるよ", "今ならまだ間に合うよ"]
        case .night:
            ["今日の連続記録、まだ守れるよ", "1分だけでも記録しよ？"]
        }
    }
}
