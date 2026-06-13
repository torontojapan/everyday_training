package com.goexercise.app.presentation.friends

/**
 * 応援トーストの文言(純粋関数)。送信完了/受信のいずれも「入力した一言(message)があればそれを、
 * 無ければ kind ラベルを」反映する。iOS FriendDetailView「『text』を送りました」/受信トースト相当。
 * 文言を 1 か所に集約し [CheerToastTest] で機械的に担保する。
 */
object CheerToast {
    /** 送信完了トースト。message 優先、無ければ kind ラベル。 */
    fun sent(kindEmoji: String, kindLabel: String, recipientName: String, message: String?): String {
        val body = message?.takeIf { it.isNotBlank() } ?: kindLabel
        return "$kindEmoji $recipientName に「$body」を送りました"
    }

    /** 受信トースト。message 優先、無ければ kind ラベル。 */
    fun received(emoji: String, senderName: String, kindLabel: String, message: String?): String {
        val body = message?.takeIf { it.isNotBlank() } ?: kindLabel
        return "$emoji $senderName から「$body」"
    }
}
