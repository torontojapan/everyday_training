package com.goexercise.app.domain

import java.time.LocalDate

/**
 * リマインダー通知のメッセージ(純粋関数)。iOS `NotificationMessageProvider` の移植。
 * 性格(トーン)・連続日数・今週の達成率・スロット(朝/夕)で文言を出し分け、
 * 発火日の日番号で日替わりローテーションする(同じ文言が連日続かない)。
 * 絵文字は猫・犬どちらの相棒でも違和感のない肉球 🐾 に統一(犬種追加に伴い 🐱 から変更)。
 */
object NotificationMessageProvider {

    private data class ToneMessages(
        val goodWeek: List<String>,
        val keepStreak: List<String>,
        val gentle: List<String>,
    )

    // 静かに待つ: 1 通前提の最小トーン。
    private val quiet = listOf(
        "🐾「今日まだ間に合うよ。1分だけ」",
        "🐾「ふと思い出したら、また会いに来てね」",
        "🐾「気が向いたら 1 種目だけ残そ？」",
        "🐾「無理しなくていい、ちょっとだけ」",
    )

    // ひとこと呼ぶ(やさしい標準)。
    private val voice = ToneMessages(
        goodWeek = listOf(
            "🐾「今週いい感じだよ。今日も続けよ？」",
            "🐾「あと少しで今週の達成率が上がるよ」",
            "🐾「今週の流れ、守っていこ？」",
            "🐾「いい調子。今日もちょこっとやろ？」",
            "🐾「今週のがんばり、まだ伸ばせるね」",
            "🐾「このペース、続けたら週末いい気分だよ」",
            "🐾「今日もちょっとだけ、いつもの調子で」",
            "🐾「今週の自分、すでにえらいよ」",
            "🐾「いい流れ、もう一日プラスしてみよ？」",
        ),
        keepStreak = listOf(
            "🐾「今日の連続記録、まだ守れるよ」",
            "🐾「あと少しで今日の記録が残せるよ」",
            "🐾「今日の記録、まだ待ってるよ」",
            "🐾「1分だけでも続けたら連続記録キープだよ」",
            "🐾「今日のぶん、まだ間に合うよ」",
            "🐾「お疲れさま。ストレッチ1つで OK だよ」",
            "🐾「寝る前に1種目だけ、どう？」",
            "🐾「今日も会えてうれしい。記録残そ？」",
            "🐾「焦らなくていい、自分のペースで残そ」",
        ),
        gentle = listOf(
            "🐾「今日の運動、そろそろ一緒にやろ？」",
            "🐾「1分だけでも記録しよ？」",
            "🐾「今日も少しだけ体を動かしてみよ？」",
            "🐾「無理しなくていいから、ちょっとだけやろ？」",
            "🐾「ストレッチ1つでも OK だよ」",
            "🐾「今日も一緒に体動かそ？」",
            "🐾「軽くでいいから、はじめてみよ」",
            "🐾「やる気が出ないときほど、1分だけ」",
            "🐾「気が向いたタイミングで OK だよ」",
            "🐾「今日もそばにいるよ、待ってるね」",
        ),
    )

    // 元気いっぱい。
    private val cheer = ToneMessages(
        goodWeek = listOf(
            "🐾「今週サイコー！この勢いでいっちゃお〜！」",
            "🐾「ノリノリだね♪ 今日もパパッとやっちゃお！」",
            "🐾「最高の流れ！もう1個できたら神✨」",
            "🐾「今週かがやいてる！このまま続けよ〜！」",
            "🐾「いいねいいね！今日もハイタッチしよ！」",
            "🐾「絶好調！週末まで駆け抜けよ〜！」",
        ),
        keepStreak = listOf(
            "🐾「連続キープいくよ〜！今日もファイト！」",
            "🐾「あと1分でクリア！いっけぇ〜！」",
            "🐾「今日のキミも輝ける！記録残そ〜♪」",
            "🐾「ラストスパート！1種目でバッチリ！」",
            "🐾「ねぇねぇ、今日のぶんやっちゃお！わくわく！」",
            "🐾「寝る前にエイッと1個！気持ちいいよ〜！」",
        ),
        gentle = listOf(
            "🐾「おはよ〜！今日も一緒に体動かそ〜！」",
            "🐾「1分でいいから、レッツゴー！」",
            "🐾「今日のワクワク、運動から始めよ♪」",
            "🐾「ストレッチ1つでも 100点満点！」",
            "🐾「やる気スイッチ、ポチッと押しちゃお！」",
            "🐾「軽〜くでOK！はじめちゃお〜！」",
        ),
    )

    // スパルタ。
    private val spartan = ToneMessages(
        goodWeek = listOf(
            "🐾「今週いいぞ！ここで緩めるな、もう1本！」",
            "🐾「妥協は明日の自分への借金だ。今日も刻め」",
            "🐾「波に乗ってる。きっちり仕上げにいくぞ！」",
            "🐾「やればできるじゃないか。続けてこそ本物だ」",
            "🐾「今週の貯金、まだ増やせる。行くぞ！」",
            "🐾「ここまで来たら止まる理由はない。前へ！」",
        ),
        keepStreak = listOf(
            "🐾「連続を切らすな！今日の1本、死守だ」",
            "🐾「言い訳の前に体を動かせ。それだけだ」",
            "🐾「記録は待ってる。だが今日中だぞ」",
            "🐾「眠る前に1種目。約束は守るよな？」",
            "🐾「ここで止まったら今までが台無しだ。やれ！」",
            "🐾「1分でいい。やらない理由を探すな」",
        ),
        gentle = listOf(
            "🐾「ぐだぐだ言うな、まず1分動け！」",
            "🐾「やる気は動いてから出る。さあ始めろ！」",
            "🐾「今日の自分を超えるのは今日の自分だ。行け」",
            "🐾「軽くでいい、だが必ずやる。それが流儀だ」",
            "🐾「準備運動でも上等だ。立ち上がれ！」",
            "🐾「迷ってる時間で1種目終わるぞ。やれ！」",
        ),
    )

    // クール。
    private val cool = ToneMessages(
        goodWeek = listOf(
            "🐾「今週の達成率、悪くない。続けよう」",
            "🐾「順調だ。今日の1件で、さらに伸びる」",
            "🐾「いいペースだ。淡々と積み上げよう」",
            "🐾「数字は嘘をつかない。今日も1件」",
            "🐾「流れはできている。あとは継続だけ」",
            "🐾「悪くない一週間。仕上げにいこう」",
        ),
        keepStreak = listOf(
            "🐾「連続記録、今日まで。あと1件で継続」",
            "🐾「まだ間に合う。1分で十分だ」",
            "🐾「今日の記録、残しておこう」",
            "🐾「焦りは不要。確実に1件だけ」",
            "🐾「就寝前に1種目。それで十分だ」",
            "🐾「途切れさせる理由は、特にないはずだ」",
        ),
        gentle = listOf(
            "🐾「今日の運動、そろそろ始めよう」",
            "🐾「1分でいい。記録を1件」",
            "🐾「軽く動かすだけでいい。始めよう」",
            "🐾「気負わなくていい。淡々と1件」",
            "🐾「ストレッチでも記録になる」",
            "🐾「やる気は要らない。動けば十分だ」",
        ),
    )

    // ツンデレ。
    private val tsundere = ToneMessages(
        goodWeek = listOf(
            "🐾「今週わりと頑張ってるじゃん…別に褒めてないけど」",
            "🐾「いい感じ…まあ、続けたら認めてあげる」",
            "🐾「調子いいね。べ、別に嬉しくなんかないし」",
            "🐾「ここまで来たなら最後までやりなよ。心配してないけど」",
            "🐾「悪くないペース…ふん、今日もやれば？」",
            "🐾「今週の頑張り、ちょっとだけ見直した。ちょっとだけね」",
        ),
        keepStreak = listOf(
            "🐾「連続切れても…別に困らないけど、やれば？」",
            "🐾「まだ間に合うよ。待ってないけど待ってる」",
            "🐾「今日の記録、残さないの？…早くしてよね」",
            "🐾「1分くらいできるでしょ。し、心配して損した」",
            "🐾「寝る前に1個。やったら…まあ、えらいけど」",
            "🐾「ここで止めるとか、もったいないんだからね」",
        ),
        gentle = listOf(
            "🐾「動かないの？…別に一緒にやりたいわけじゃ」",
            "🐾「1分だけでも…ま、やってあげてもいいよ」",
            "🐾「今日もサボる気？…ちょっとだけやろ」",
            "🐾「ストレッチくらい付き合ってあげる。感謝してよね」",
            "🐾「見ててほしいわけじゃ…早く始めなよ」",
            "🐾「やる気ないの？…ふん、こっち来なよ」",
        ),
    )

    private fun tone(personality: NotificationPersonality): ToneMessages = when (personality) {
        NotificationPersonality.Cheer -> cheer
        NotificationPersonality.Spartan -> spartan
        NotificationPersonality.Cool -> cool
        NotificationPersonality.Tsundere -> tsundere
        else -> voice // Voice / FriendDriven / Quiet(quiet は上流で別処理)は標準トーン。
    }

    fun message(
        slot: NotificationSlot,
        personality: NotificationPersonality = NotificationPersonality.Voice,
        currentStreak: Int,
        weeklyProgressRate: Double,
        seedDate: LocalDate,
    ): String {
        val day = seedDate.toEpochDay().toInt()
        if (personality == NotificationPersonality.Quiet) {
            return quiet[Math.floorMod(day, quiet.size)]
        }
        val t = tone(personality)
        val messages = when {
            weeklyProgressRate >= 0.5 -> t.goodWeek
            slot == NotificationSlot.Evening || currentStreak > 0 -> t.keepStreak
            else -> t.gentle
        }
        val slotOffset = if (slot == NotificationSlot.Morning) 0 else 1
        return messages[Math.floorMod(day + slotOffset, messages.size)]
    }
}
