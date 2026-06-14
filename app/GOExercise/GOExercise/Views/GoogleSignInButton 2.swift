import SwiftUI

/// Google サインインボタン (公式ブランドガイドライン準拠の体裁)。
///
/// Apple は `ASAuthorizationAppleIDButton` ([[AppleIDButton]]) を使うが、Google には
/// SDK 非依存の標準ボタンが無いため、ガイドライン (白背景 / 1pt ニュートラル枠 / 角丸 /
/// 4色 "G" ロゴを左 / テキスト中央 / 最小高さ 40pt) に沿って自前で組む。
///
/// - Note: 厳密なブランド準拠には**公式の "G" ロゴアセット**を使う必要がある。ここではアセット
///   非同梱でビルドできるよう [[GoogleGMark]] でロゴを描画している。出荷前にキー所有者が
///   公式アセットへ差し替えること (Supabase/redirect 設定と同じ「キー所有者作業」)。
struct GoogleSignInButton: View {
    /// ボタン文言 (例: 「Google でバックアップ」「Google で復元」)。
    var title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color(red: 0.118, green: 0.118, blue: 0.118)) // #1F1F1F
                HStack {
                    GoogleGMark()
                        .frame(width: 18, height: 18)
                    Spacer()
                }
                .padding(.leading, 14)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(red: 0.455, green: 0.463, blue: 0.475), lineWidth: 1) // #747775
            )
        }
        .buttonStyle(.plain)
    }
}

/// Google の 4色 "G" マーク (近似描画)。出荷前に公式アセットへ差し替え推奨。
/// 4色のリング弧 (赤=上, 黄=左, 緑=下, 青=右) と青の横バーで "G" を構成する。
struct GoogleGMark: View {
    private static let blue = Color(red: 0.259, green: 0.522, blue: 0.957)   // #4285F4
    private static let red = Color(red: 0.918, green: 0.263, blue: 0.208)    // #EA4335
    private static let yellow = Color(red: 0.984, green: 0.737, blue: 0.020) // #FBBC05
    private static let green = Color(red: 0.204, green: 0.659, blue: 0.325)  // #34A853

    var body: some View {
        Canvas { ctx, size in
            let lineWidth = size.width * 0.26
            let radius = (size.width - lineWidth) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            func arc(from start: Double, to end: Double, color: Color) {
                var path = Path()
                path.addArc(center: center, radius: radius,
                            startAngle: .degrees(start), endAngle: .degrees(end),
                            clockwise: false)
                ctx.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            }
            // 角度は時計回り (y 下向き座標)。0°=右, 90°=下。
            arc(from: -45, to: 45, color: Self.blue)    // 右
            arc(from: 45, to: 135, color: Self.green)   // 下
            arc(from: 135, to: 225, color: Self.yellow) // 左
            arc(from: 225, to: 315, color: Self.red)    // 上

            // 青の横バー (G の内側の棒): 中心から右へ。
            var bar = Path()
            let barHeight = lineWidth
            bar.addRect(CGRect(x: center.x - lineWidth * 0.1,
                               y: center.y - barHeight / 2,
                               width: radius + lineWidth / 2 + lineWidth * 0.1,
                               height: barHeight))
            ctx.fill(bar, with: .color(Self.blue))
        }
        .accessibilityHidden(true)
    }
}
