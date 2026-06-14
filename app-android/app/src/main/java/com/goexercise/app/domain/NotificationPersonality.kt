package com.goexercise.app.domain

/**
 * 通知の「性格」モード。iOS `NotificationPersonality` の移植(rawValue はクロスOS契約)。
 * - Quiet: 静かに待つ。連続が危ういときだけ夕方1通。
 * - Voice: ひとこと呼ぶ(既定)。朝+夕。
 * - FriendDriven: 友達が動いた時だけ(v1 は日常 push を抑制=quiet 相当に degrade)。
 */
enum class NotificationPersonality(val rawValue: String, val displayName: String, val hint: String) {
    Quiet("quiet", "静かに待つ", "連続が途切れそうな時だけそっと通知します"),
    Voice("voice", "ひとこと呼ぶ", "朝と夕にやさしく声をかけます(既定)"),
    FriendDriven("friendDriven", "友達が動いた時だけ", "日常の通知は控えめにします");

    companion object {
        val Default = Voice

        fun fromRaw(raw: String?): NotificationPersonality =
            entries.firstOrNull { it.rawValue == raw } ?: Default

        /** 友達機能 OFF のビルドでは FriendDriven を出さない。 */
        fun visibleCases(friendsEnabled: Boolean): List<NotificationPersonality> =
            if (friendsEnabled) entries.toList() else entries.filter { it != FriendDriven }
    }
}

/** 通知スロット(朝/夕)。iOS NotificationSlot 相当。 */
enum class NotificationSlot { Morning, Evening }
