import Foundation

/// 小節目(minor)イベント。割り込まない軽量演出のトリガ。
enum RankUpEvent: Equatable {
    case rankUp(to: Int)       // CatRank 閾値を跨いで上がった
    case weekly(streak: Int)   // 連続が新しい7の倍数に達した(大節目に未該当時)
}

/// 前回 rank と前回処理済み週次を `UserDefaults` に保持し、上昇分のみ返す純ロジック。
/// リセット(連続0)後の再上昇でも再発火する(保存値が現在値を上回ったら追従して下げる)。
struct RankUpDetector {
    private let defaults: UserDefaults
    private let rankKey = "rankup.lastRank"
    private let weeklyKey = "rankup.lastWeeklyMultiple" // 直近で発火した「7の倍数」値

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    /// 現在の連続日数を渡し、発火すべき小節目イベント群を返す。状態は副作用で更新。
    func evaluate(currentStreak: Int) -> [RankUpEvent] {
        var events: [RankUpEvent] = []
        let streak = max(0, currentStreak)
        let newRank = CatRank(currentStreak: streak).rank
        let lastRank = defaults.object(forKey: rankKey) as? Int ?? 0

        if newRank > lastRank {
            events.append(.rankUp(to: newRank))
        }
        if newRank != lastRank {
            defaults.set(newRank, forKey: rankKey) // 上昇・下降どちらも追従
        }

        let currentMultiple = (streak / 7) * 7 // 7未満は0
        let lastMultiple = defaults.object(forKey: weeklyKey) as? Int ?? 0
        if currentMultiple >= 7, currentMultiple > lastMultiple {
            events.append(.weekly(streak: currentMultiple))
        }
        if currentMultiple != lastMultiple {
            defaults.set(currentMultiple, forKey: weeklyKey)
        }
        return events
    }

}
