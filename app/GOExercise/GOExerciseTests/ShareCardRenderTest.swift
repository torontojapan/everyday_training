import SwiftUI
import XCTest
@testable import GOExercise

/// 共有カード(StreakShareCard)を書き出しと同条件(fillFrame=true, 600×1300 @3x)で実描画し
/// PNG 添付する。保存/共有画像で内容(キャラ・文字)が背景に対して小さく見える問題の
/// 1.5 倍拡大を目視検証するための golden。
@MainActor
final class ShareCardRenderTest: XCTestCase {
    private func shoot<V: View>(_ view: V, _ name: String) {
        let card = view.frame(width: ShareCardLayout.canvas.width, height: ShareCardLayout.canvas.height)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(ShareCardLayout.canvas)
        guard let img = renderer.uiImage, let data = img.pngData() else {
            XCTFail("render failed: \(name)"); return
        }
        let att = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        att.name = name; att.lifetime = .keepAlways
        add(att)
        print("SHOT \(name) \(Int(img.size.width))x\(Int(img.size.height))")
    }

    func testRenderStreakShareCardExport() {
        shoot(StreakShareCard(streak: 1, appName: "GO エクササイズ", fillFrame: true), "streak_card_export")
    }
}
