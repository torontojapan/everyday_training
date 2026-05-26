import SwiftUI

/// ホーム画面の背景にゆっくり漂うパーティクル。時刻に応じて色とモチーフが
/// 変わり、達成済みのときは追加で紙吹雪を散らす。
///
/// 重要: `TimelineView(.animation)` で 1 fps 単位の連続描画を行う。
/// reduceMotion が有効なら静止画 (1 フレームだけ) に切り替える。
struct AmbientParticlesView: View {
    let hour: Int
    let isCelebrating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 各 particle は seed に基づく固定の軌道を持つ。フレームごとに
        // 位置/透明度を再計算するため state を持たず、純関数で描画する。
        TimelineView(.animation(minimumInterval: reduceMotion ? .infinity : 1.0 / 30.0,
                                paused: false)) { ctx in
            Canvas { gc, size in
                let now = ctx.date.timeIntervalSinceReferenceDate
                drawAmbient(in: gc, size: size, now: now)
                if isCelebrating {
                    drawConfetti(in: gc, size: size, now: now)
                }
            }
        }
    }

    // MARK: - Ambient (時刻ごとのモチーフ)

    /// 朝はピンクの花びら、昼はクリームの泡、夕方はオレンジの葉っぱ、夜は星。
    private func drawAmbient(in gc: GraphicsContext, size: CGSize, now: TimeInterval) {
        let palette = ambientPalette
        let count = 18
        for i in 0..<count {
            // 各 particle の擬似ランダムな性質 (seed 固定)。
            let seed = Double(i) * 13.37
            let baseX = (sin(seed * 1.13).truncatingRemainder(dividingBy: 1) + 1) * 0.5 * size.width
            // y は下から上にゆっくり昇る (周期 18-30 秒)
            let period = 18 + (i % 12).double
            let phase = (now / period + seed).truncatingRemainder(dividingBy: 1.0)
            let y = size.height * (1.0 - phase)
            // 横揺れ
            let wobble = sin(now * 0.6 + seed) * 24
            let x = baseX + wobble
            // 透明度: 中央付近で 1、上下端でフェードアウト
            let alpha = sin(phase * .pi) * 0.55
            // サイズ: 各 particle で 8-18pt
            let radius = 8.0 + (i % 5).double * 2

            let color = palette[i % palette.count].opacity(alpha)
            let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
            switch ambientShape {
            case .circle:
                gc.fill(Path(ellipseIn: rect), with: .color(color))
            case .star:
                gc.fill(starPath(in: rect, points: 5), with: .color(color))
            case .leaf:
                gc.fill(leafPath(in: rect), with: .color(color))
            case .petal:
                gc.fill(leafPath(in: rect), with: .color(color))
            }
        }
    }

    private var ambientPalette: [Color] {
        switch hour {
        case 5..<11:   // 朝: ピーチピンク + 桜
            return [
                Color(red: 1.0, green: 0.78, blue: 0.78),
                Color(red: 1.0, green: 0.88, blue: 0.85),
                Color(red: 1.0, green: 0.72, blue: 0.65),
            ]
        case 11..<16:  // 昼: クリーム + 淡黄
            return [
                Color(red: 1.0, green: 0.94, blue: 0.78),
                Color(red: 1.0, green: 0.90, blue: 0.70),
                Color(red: 0.98, green: 0.85, blue: 0.65),
            ]
        case 16..<21:  // 夕方: オレンジ + 紅葉
            return [
                Color(red: 1.0, green: 0.65, blue: 0.40),
                Color(red: 1.0, green: 0.75, blue: 0.45),
                Color(red: 0.95, green: 0.55, blue: 0.30),
            ]
        default:       // 夜: 銀 + 薄青の星
            return [
                Color(red: 0.85, green: 0.88, blue: 0.95),
                Color(red: 0.70, green: 0.78, blue: 0.90),
                Color(red: 0.95, green: 0.95, blue: 0.85),
            ]
        }
    }

    private enum AmbientShape { case circle, star, leaf, petal }

    private var ambientShape: AmbientShape {
        switch hour {
        case 5..<11:  return .petal
        case 11..<16: return .circle
        case 16..<21: return .leaf
        default:      return .star
        }
    }

    // MARK: - Celebration confetti

    /// 達成済みのときだけ追加で散らす紙吹雪。鮮やかな色で楽しさを足す。
    private func drawConfetti(in gc: GraphicsContext, size: CGSize, now: TimeInterval) {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.55, blue: 0.40),
            Color(red: 1.0, green: 0.78, blue: 0.30),
            Color(red: 0.55, green: 0.78, blue: 1.0),
            Color(red: 0.75, green: 0.55, blue: 1.0),
            Color(red: 0.55, green: 0.85, blue: 0.55),
        ]
        let count = 14
        for i in 0..<count {
            let seed = Double(i) * 7.7
            let baseX = (cos(seed * 0.61).truncatingRemainder(dividingBy: 1) + 1) * 0.5 * size.width
            let period = 8 + (i % 6).double
            let phase = (now / period + seed * 0.3).truncatingRemainder(dividingBy: 1.0)
            let y = size.height * phase
            let wobble = sin(now * 1.2 + seed) * 40
            let x = baseX + wobble
            // 落ちながらフェードアウト
            let alpha = (1.0 - phase) * 0.7

            let w = 9.0
            let h = 4.0
            let rotation = now * 1.5 + seed
            var path = Path(CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
            path = path.applying(.init(rotationAngle: rotation).concatenating(.init(translationX: x, y: y)))
            gc.fill(path, with: .color(colors[i % colors.count].opacity(alpha)))
        }
    }

    // MARK: - Shape helpers

    private func starPath(in rect: CGRect, points: Int) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.45
        for i in 0..<(points * 2) {
            let r = i.isMultiple(of: 2) ? outer : inner
            let theta = Double(i) * .pi / Double(points) - .pi / 2
            let x = center.x + r * cos(theta)
            let y = center.y + r * sin(theta)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    private func leafPath(in rect: CGRect) -> Path {
        // 葉っぱ風: 上下に尖った楕円
        var path = Path()
        let cx = rect.midX
        let cy = rect.midY
        let rx = rect.width / 2
        let ry = rect.height / 2
        path.move(to: CGPoint(x: cx, y: cy - ry))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy + ry),
                          control: CGPoint(x: cx + rx, y: cy))
        path.addQuadCurve(to: CGPoint(x: cx, y: cy - ry),
                          control: CGPoint(x: cx - rx, y: cy))
        path.closeSubpath()
        return path
    }
}

private extension Int {
    var double: Double { Double(self) }
}
