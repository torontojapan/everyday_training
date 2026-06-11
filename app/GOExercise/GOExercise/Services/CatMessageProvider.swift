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
            [
                "今日も1分だけやってみよ？",
                "今日も少しだけ体を動かしてみよ？",
                "おはよう。気が向いたら一緒にやろ？",
                "ストレッチ1つから始めても OK だよ",
                "今日もそばにいるよ。マイペースで",
                "朝の体、起こしてあげよ？"
            ]
        case .worriedNoon:
            [
                "そろそろ一緒に体を動かそ？",
                "無理しなくていいから、ちょっとだけやろ？",
                "今のうちに、1種目だけでも",
                "お昼の合間に、ストレッチどう？",
                "1分でいいから、はじめてみない？",
                "気軽にいこ。続けることが大事だよ"
            ]
        case .beggingNight:
            [
                "今日の連続記録、まだ守れるよ",
                "あと少しで今日の記録が残せるよ",
                "1種目だけ、お願い…!",
                "寝る前にストレッチだけでも OK だよ",
                "焦らなくていい、1分で十分だよ",
                "今日のぶん、まだ間に合うよ"
            ]
        case .celebrating:
            [
                "今日も達成！えらい！",
                "1分でも続けたのがすごいよ",
                "今日の記録、ちゃんと残せたね",
                "いい感じ！また明日も待ってるね",
                "やったね、お疲れさま",
                "今日の自分、最高だよ",
                "ちゃんとできた、それがすごい",
                "がんばった分、ご褒美時間だね",
                "今日もえらい、ほんとに",
                "また明日も、ちょっとだけ一緒に"
            ]
        case .streakExtended:
            [
                "連続記録更新！すごいよ",
                "今日も続いたね。大成功！",
                "いい流れ、ちゃんと守れたね",
                "新記録おめでとう ✨",
                "ここまで続いたの、ほんとにすごい",
                "コツコツが力になってるね",
                "今日のおかげでまた1日伸びたよ",
                "この調子で、また明日も会お？"
            ]
        case .resting:
            [
                "今日は回復日だね",
                "休むことも継続の一部だよ",
                "明日に向けて整えよう",
                "無理しないのも大事だよ",
                "ゆっくりしていいよ、おつかれさま",
                "体を休めるのも立派な習慣",
                "今日はリセットの日。気にしないで",
                "また明日、待ってるね"
            ]
        case .encouraging:
            [
                "今日からまた一緒に始めよ？",
                "少しだけ体を動かしてみない？",
                "今ならまだ間に合うよ",
                "気にしない気にしない、また今日から",
                "1分でいいよ、はじめの一歩",
                "焦らなくていい、自分のペースで",
                "今日が新しいスタートだね",
                "やる気の波は誰でもあるよ、大丈夫"
            ]
        }

        return CatMessage(emoji: state.emoji, text: pickedMessage(from: messages, seedDate: seedDate, calendar: calendar))
    }

    static func message(for status: DailyStatus, time: DayTime, seedDate: Date = Date(), calendar: Calendar = .current) -> CatMessage {
        let messages: [String]

        switch status {
        // rescued(フリーズ救済日)が「今日」のステータスになることは通常ないが、
        // 達成扱いの日として同じ祝福系メッセージに寄せる。
        case .todayAchieved, .achieved, .rescued:
            messages = [
                "今日も達成！えらい！",
                "1分でも続けたのがすごいよ",
                "今日の記録、ちゃんと残せたね",
                "いい感じ！また明日も待ってるね",
                "やったね、お疲れさま",
                "今日の自分、最高だよ",
                "がんばった分、ご褒美時間だね",
                "ちゃんとできた、それがすごい",
                "今日もえらい、ほんとに"
            ]
        case .rest:
            messages = [
                "今日は回復日だね",
                "休むことも継続の一部だよ",
                "明日に向けて整えよう",
                "無理しないのも大事だよ",
                "ゆっくりしていいよ、おつかれさま",
                "体を休めるのも立派な習慣",
                "今日はリセットの日。気にしないで",
                "また明日、待ってるね"
            ]
        case .todayPending:
            messages = pendingMessages(for: time)
        case .missed:
            messages = [
                "今日からまた一緒に始めよ？",
                "少しだけ体を動かしてみない？",
                "今週の流れ、守っていこ？",
                "気にしない気にしない、また今日から",
                "1分でいいよ、はじめの一歩",
                "焦らなくていい、自分のペースで",
                "今日が新しいスタートだね",
                "やる気の波は誰でもあるよ、大丈夫"
            ]
        case .future:
            messages = [
                "明日も少しだけ待ってるね",
                "次の運動も一緒にやろ？",
                "また明日、ちょっとだけ",
                "あさってもよろしくね",
                "次のタイミングで会お？",
                "そのうちまた一緒にやろ"
            ]
        }

        return CatMessage(emoji: "🐱", text: pickedMessage(from: messages, seedDate: seedDate, calendar: calendar))
    }

    private static func pickedMessage(from messages: [String], seedDate: Date, calendar: Calendar) -> String {
        // 空配列だと messages[0] が範囲外クラッシュになる。旧コードの
        // `messages.isEmpty ? 0 : ...` は index を 0 にするだけでアクセス自体は
        // 防げていなかった (3 LLM 監査)。空なら安全なフォールバック文言を返す。
        guard !messages.isEmpty else { return "今日もそばにいるよ" }
        let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
        return messages[abs(day) % messages.count]
    }

    private static func pendingMessages(for time: DayTime) -> [String] {
        switch time {
        case .morning:
            [
                "今日も1分だけやってみよ？",
                "今日も少しだけ体を動かしてみよ？",
                "おはよう。気が向いたら一緒にやろ？",
                "ストレッチ1つから始めても OK だよ",
                "今日もそばにいるよ。マイペースで",
                "朝の体、起こしてあげよ？"
            ]
        case .noon:
            [
                "そろそろ一緒に体を動かそ？",
                "無理しなくていいから、ちょっとだけやろ？",
                "今のうちに、1種目だけでも",
                "お昼の合間に、ストレッチどう？",
                "1分でいいから、はじめてみない？",
                "気軽にいこ。続けることが大事だよ"
            ]
        case .evening:
            [
                "今日の記録、まだ待ってるよ",
                "今ならまだ間に合うよ",
                "夕方のうちに1分だけ、どう？",
                "今日のぶん、残しておこ？",
                "お疲れさま。ストレッチ1つでも OK",
                "夜になる前に、ちょこっとやろ？"
            ]
        case .night:
            [
                "今日の連続記録、まだ守れるよ",
                "1分だけでも記録しよ？",
                "寝る前にストレッチだけでも OK だよ",
                "焦らなくていい、1分で十分だよ",
                "今日のぶん、まだ間に合うよ",
                "1種目だけ、お願い…!"
            ]
        }
    }
}
