import Foundation

/// 受信応援 watermark の前進ロジック(純粋関数)。Android `CheerWatermarkLogic` と同型。
/// ネットワーク/UserDefaults から切り離し、「過去の蓄積を出さない・同じ応援を二度出さない」
/// 不変条件を XCTest で担保する(`SupabaseFriendsService.unseenReceivedCheers` から利用)。
enum CheerWatermarkLogic {
    struct Outcome: Equatable {
        /// 今回トースト表示する未読応援(createdAt 昇順)。
        let unseen: [ReceivedCheer]
        /// 次回比較に使う新しい watermark。
        let newWatermark: Date
    }

    /// - Parameters:
    ///   - lastSeen: 前回チェック時刻。nil=初回。
    ///   - now: 初回起点に使う現在時刻。
    ///   - candidates: 自分宛の受信応援候補(順不同でよい)。
    /// - 初回(lastSeen==nil): 何も出さず watermark を `now` に置く(過去の蓄積を一気に出さない)。
    /// - 以降: watermark **より後**(strictly greater)の応援だけを surface し、watermark を
    ///   surface した最新 createdAt まで前進する(新着が無ければ据え置き)。
    static func evaluate(lastSeen: Date?, now: Date, candidates: [ReceivedCheer]) -> Outcome {
        guard let lastSeen else { return Outcome(unseen: [], newWatermark: now) }
        let unseen = candidates
            .filter { $0.createdAt > lastSeen }
            .sorted { $0.createdAt < $1.createdAt }
        guard let newest = unseen.map(\.createdAt).max() else {
            return Outcome(unseen: [], newWatermark: lastSeen)
        }
        return Outcome(unseen: unseen, newWatermark: newest)
    }
}
