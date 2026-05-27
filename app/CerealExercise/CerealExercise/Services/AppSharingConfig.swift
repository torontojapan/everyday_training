import Foundation

/// アプリ自体を友達/SNS にシェアする際の URL とメッセージを集約。
///
/// **Apple Developer 加入後の差し替え手順**:
/// `shareURL` を `https://apps.apple.com/app/id<ID>` に変更するだけ。
/// 各 View 側 (FriendsView / SettingsView) のコードは一切触らない。
///
/// 現状: GitHub Pages のランディングを指す。ランディング側で iOS UA を検出して
/// 自動で App Store に redirect するように更新する余地も残してある。
enum AppSharingConfig {
    /// シェアに使う遷移先。SNS / メール / メッセージ に貼られて、タップした人
    /// がインストール画面 (将来: App Store 直接) に飛ぶ。
    static let shareURL = URL(string: "https://torontojapan.github.io/everyday_training/")!

    /// シェアに添える本文。Twitter / LINE / メール本文などで共通利用。
    /// 80 文字以内: SNS でツイート長制限・LINE のプレビュー切れに収まる目安。
    static let shareMessage = "ねこ達とゆる〜く運動習慣をつくる『GOエクササイズ』。一緒にやろう！"

    /// SwiftUI `ShareLink` の subject。メール送信時の件名にも使われる。
    static let shareSubject = "GOエクササイズ"
}
