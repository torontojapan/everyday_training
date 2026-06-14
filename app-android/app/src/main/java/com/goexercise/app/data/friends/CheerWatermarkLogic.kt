package com.goexercise.app.data.friends

import com.goexercise.app.domain.friends.ReceivedCheer

/**
 * 受信応援 watermark の前進ロジック(純粋関数)。iOS unseenReceivedCheers と同型。
 * ネットワーク([SupabaseFriendsService])/永続層([CheerWatermarkStore])から切り離し、
 * 「過去の蓄積を出さない・同じ応援を二度出さない」不変条件を JVM 単体テストで担保する。
 */
object CheerWatermarkLogic {

    data class Outcome(
        /** 今回トースト表示する未読応援(createdAt 昇順)。 */
        val unseen: List<ReceivedCheer>,
        /** 次回比較に使う新しい watermark(epoch ms)。 */
        val newWatermark: Long,
    )

    /**
     * @param lastSeen 前回チェック時刻(epoch ms)。null=初回。
     * @param now 初回起点に使う現在時刻(epoch ms)。
     * @param candidates 自分宛の受信応援候補(順不同でよい)。
     *
     * - 初回(lastSeen==null): 何も出さず watermark を [now] に置く(過去の蓄積を一気に出さない)。
     * - 以降: watermark **より後**(strictly greater)の応援だけを surface し、watermark を
     *   surface した最新 createdAt まで前進する(同じ応援を二度出さない)。新着が無ければ据え置き。
     */
    fun evaluate(lastSeen: Long?, now: Long, candidates: List<ReceivedCheer>): Outcome {
        if (lastSeen == null) return Outcome(emptyList(), now)
        val unseen = candidates
            .filter { it.createdAtEpochMs > lastSeen }
            .sortedBy { it.createdAtEpochMs }
        if (unseen.isEmpty()) return Outcome(emptyList(), lastSeen)
        return Outcome(unseen, unseen.last().createdAtEpochMs)
    }
}
