import SwiftUI

/// `MetalKind` を SwiftUI の色・グラデーションに変換する。
/// spec の RGB を正本にし、`+`/`-` は明度 ±8% で表現。
enum MetalStyle {
    /// 代表色(チップ枠・アイコン色など単色が要る箇所)。
    static func baseColor(_ kind: MetalKind) -> Color {
        let (r, g, b, lum) = components(kind)
        return adjust(r: r, g: g, b: b, brightness: lum)
    }

    /// カプセル塗り用の金属グラデ(明→暗で立体感)。rainbow は別途 `isRainbow` で分岐。
    static func fillGradient(_ kind: MetalKind) -> LinearGradient {
        let (r, g, b, lum) = components(kind)
        let hi = adjust(r: r, g: g, b: b, brightness: lum + 0.10)
        let lo = adjust(r: r, g: g, b: b, brightness: lum - 0.10)
        return LinearGradient(colors: [hi, lo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// rank11 の虹。角度グラデ(アニメは呼び出し側、reduceMotion で静止)。
    static let rainbowColors: [Color] = [
        Color(red: 1.00, green: 0.42, blue: 0.42),
        Color(red: 1.00, green: 0.80, blue: 0.42),
        Color(red: 0.55, green: 0.85, blue: 0.45),
        Color(red: 0.40, green: 0.78, blue: 0.95),
        Color(red: 0.62, green: 0.48, blue: 0.95),
        Color(red: 1.00, green: 0.42, blue: 0.42)
    ]

    static func isRainbow(_ kind: MetalKind) -> Bool { kind == .rainbow }

    /// (base R,G,B, 明度補正) — `+`/`-` は最後の値で ±0.08。
    private static func components(_ kind: MetalKind) -> (Double, Double, Double, Double) {
        switch kind {
        case .bronze:     return (0.80, 0.52, 0.25,  0.0)
        case .bronzePlus: return (0.80, 0.52, 0.25,  0.08)
        case .silver:     return (0.74, 0.76, 0.80,  0.0)
        case .silverPlus: return (0.74, 0.76, 0.80,  0.08)
        case .goldMinus:  return (1.00, 0.80, 0.42, -0.08)
        case .gold:       return (1.00, 0.80, 0.42,  0.0)
        case .goldPlus:   return (1.00, 0.80, 0.42,  0.08)
        case .platinum:   return (0.88, 0.90, 0.96,  0.0)
        case .rainbow:    return (1.00, 0.80, 0.42,  0.0)
        }
    }

    /// 明度を ±delta して clamp。
    private static func adjust(r: Double, g: Double, b: Double, brightness delta: Double) -> Color {
        func c(_ v: Double) -> Double { min(1, max(0, v + delta)) }
        return Color(red: c(r), green: c(g), blue: c(b))
    }
}
