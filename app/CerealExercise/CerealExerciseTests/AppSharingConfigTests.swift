import Foundation
import Testing
@testable import CerealExercise

/// AppSharingConfig は SwiftUI 側の参照先 1 箇所に集約しているため、
/// URL が壊れた・空メッセージになったケースの「気付けないリリース事故」を防ぐ。
struct AppSharingConfigTests {
    @Test
    func shareURL_isHTTPS_andValid() {
        let url = AppSharingConfig.shareURL
        #expect(url.scheme == "https", "シェア URL は HTTPS でなければならない (\(url))")
        #expect(url.host?.isEmpty == false, "host が空ではいけない (\(url))")
    }

    @Test
    func shareMessage_isNonEmpty_andReasonableLength() {
        let msg = AppSharingConfig.shareMessage
        #expect(!msg.isEmpty)
        // SNS プレビューや LINE トーク表示で切れにくい目安: 140 文字以内。
        #expect(msg.count <= 140, "シェア本文は SNS の表示切れを避けるため 140 字以内 (現在 \(msg.count))")
    }

    @Test
    func shareSubject_isNonEmpty() {
        #expect(!AppSharingConfig.shareSubject.isEmpty)
    }
}
