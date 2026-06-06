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
    /// 3LLM採点(C1: flat/candy 指摘)を受け振れ幅を ±0.16 に広げて金属の陰影を強調。
    static func fillGradient(_ kind: MetalKind) -> LinearGradient {
        let (r, g, b, lum) = components(kind)
        let hi = adjust(r: r, g: g, b: b, brightness: lum + 0.16)
        let lo = adjust(r: r, g: g, b: b, brightness: lum - 0.16)
        return LinearGradient(colors: [hi, lo], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// rank11 の虹。角度グラデ(アニメは呼び出し側、reduceMotion で静止)。
    /// 3LLM採点(C2: pastel 指摘)を受け彩度を上げてビビッドに。
    static let rainbowColors: [Color] = [
        Color(red: 1.00, green: 0.28, blue: 0.34),
        Color(red: 1.00, green: 0.72, blue: 0.16),
        Color(red: 0.38, green: 0.82, blue: 0.32),
        Color(red: 0.16, green: 0.68, blue: 0.98),
        Color(red: 0.56, green: 0.34, blue: 0.96),
        Color(red: 1.00, green: 0.28, blue: 0.34)
    ]

    static func isRainbow(_ kind: MetalKind) -> Bool { kind == .rainbow }

    /// (base R,G,B, 明度補正) — `+`/`-` は最後の値で ±0.08。
    /// 3LLM採点(A1/C2: bronze↔gold 近すぎ・platinum 退色・tier 不明瞭)を反映して
    /// 各メタルの色相/明度を引き離す: bronze=赤茶 / silver=ニュートラル鋼 /
    /// gold=高彩度黄 / platinum=冷たい青白(白金。silver より明るく青寄りで上位感)。
    private static func components(_ kind: MetalKind) -> (Double, Double, Double, Double) {
        switch kind {
        case .bronze:     return (0.74, 0.45, 0.20,  0.0)
        case .bronzePlus: return (0.74, 0.45, 0.20,  0.08)
        case .silver:     return (0.62, 0.66, 0.71,  0.0)
        case .silverPlus: return (0.62, 0.66, 0.71,  0.08)
        case .goldMinus:  return (1.00, 0.76, 0.24, -0.06)
        case .gold:       return (1.00, 0.76, 0.24,  0.0)
        case .goldPlus:   return (1.00, 0.76, 0.24,  0.08)
        case .platinum:   return (0.72, 0.80, 0.94,  0.0)
        case .rainbow:    return (1.00, 0.76, 0.24,  0.0)
        }
    }

    /// 明度を ±delta して clamp。
    private static func adjust(r: Double, g: Double, b: Double, brightness delta: Double) -> Color {
        func c(_ v: Double) -> Double { min(1, max(0, v + delta)) }
        return Color(red: c(r), green: c(g), blue: c(b))
    }
}
