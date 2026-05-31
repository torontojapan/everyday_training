import Foundation

/// アプリ自体を友達/SNS にシェアする際の URL とメッセージを集約。
///
/// 各 View 側 (FriendsView / SettingsView) のコードは一切触らない。
///
/// App Store 数値ID = 6774551663 (2026-05-31 審査提出時に判明)。
/// `shareURL` は App Store の製品ページを直接指す。
enum AppSharingConfig {
    /// シェアに使う遷移先。SNS / メール / メッセージ に貼られて、タップした人
    /// が App Store の製品ページに飛ぶ。
    static let shareURL = URL(string: "https://apps.apple.com/jp/app/id6774551663")!

    /// シェアに添える本文。Twitter / LINE / メール本文などで共通利用。
    /// 80 文字以内: SNS でツイート長制限・LINE のプレビュー切れに収まる目安。
    static let shareMessage = "ねこ達とゆる〜く運動習慣をつくる『GO エクササイズ』。一緒にやろう！"

    /// SwiftUI `ShareLink` の subject。メール送信時の件名にも使われる。
    static let shareSubject = "GO エクササイズ"
}
