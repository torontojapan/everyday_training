import SwiftUI

/// 猫キャラの輪郭を **どのテーマ背景でも立たせる** 二重シャドウ。
///
/// ビジュアル監査(docs/CAT_ART_AUDIT.md §B-3)で判明した不具合の是正:
/// - 明るい猫(white 等)が明テーマ(peach/sky/sunshine/forest)に溶け、頭の輪郭が消えて
///   「透過ミス」に見える → **暗いソフトシャドウ**で縁を立てる。
/// - 暗い猫(black/tuxedo)が midnight(暗)テーマに沈んで消える → **白いソフトグロー**で縁を立てる。
///
/// 2方向のシャドウを重ねることで、明暗どちらの背景でもシルエットが分離する(片方は無背景なら効かず無害)。
/// 透過 PNG の alpha 形状に沿ってシャドウが落ちるため、四角い影ではなく猫の輪郭に沿う。
private struct CatSilhouetteContrastModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: Color.black.opacity(0.22), radius: 3, x: 0, y: 1.5) // 明背景での分離
            .shadow(color: Color.white.opacity(0.50), radius: 3, x: 0, y: 0)   // 暗背景での分離
    }
}

extension View {
    /// 猫キャラ画像に背景非依存の輪郭コントラストを与える([CatSilhouetteContrastModifier])。
    func catSilhouetteContrast() -> some View {
        modifier(CatSilhouetteContrastModifier())
    }
}
