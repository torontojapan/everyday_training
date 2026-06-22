package com.goexercise.app.domain

/**
 * 通知の「性格」モード。iOS `NotificationPersonality` の移植(rawValue はクロスOS契約)。
 * - Quiet: 静かに待つ。連続が危ういときだけ夕方1通。
 * - Voice: ひとこと呼ぶ(既定)。朝+夕。
 * - FriendDriven: 友達が動いた時だけ(v1 は日常 push を抑制=quiet 相当に degrade)。
 */
enum class NotificationPersonality(val rawValue: String, val displayName: String, val hint: String) {
    // hint は iOS NotificationPersonality.hint に一致させる(2026-06-19 パリティ)。
    Quiet("quiet", "静かに待つ", "通知は最小限。週末の最後の砦だけ。"),
    Voice("voice", "ひとこと呼ぶ", "朝と夕方、相棒からやさしくひとこと (デフォルト)"),
    Cheer("cheer", "元気いっぱい", "明るくテンション高めに応援してくれる"),
    Spartan("spartan", "スパルタ", "厳しめ・熱血に背中を押してくれる"),
    Cool("cool", "クール", "淡々と、大人っぽく声をかけてくれる"),
    Tsundere("tsundere", "ツンデレ", "照れ隠し気味に、気にかけてくれる"),
    FriendDriven("friendDriven", "友達が動いた時だけ", "友達が達成したときだけ反応する");

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
