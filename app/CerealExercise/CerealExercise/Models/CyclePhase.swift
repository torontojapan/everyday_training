import SwiftUI

/// 月経周期の 4 相モデル。Renpho / Withings / クルー 等の女性向け健康アプリで
/// 標準採用されている分類。体重変動の生理的背景を可視化するために使う。
///
/// - **黄体期 (luteal)** は水分貯留で 1〜2kg 一時増する時期。
///   ここを示すことで「太った」と誤解する demotivation を防ぐ。
enum CyclePhase: String, Sendable, Equatable, CaseIterable {
    case menstrual    // 月経期 (実際に出血している日)
    case follicular   // 卵胞期 (月経後〜排卵前)
    case ovulation    // 排卵期 (中央付近の数日窓)
    case luteal       // 黄体期 (排卵後〜次月経まで)

    var displayName: String {
        switch self {
        case .menstrual:  return "月経期"
        case .follicular: return "卵胞期"
        case .ovulation:  return "排卵期"
        case .luteal:     return "黄体期"
        }
    }

    /// 一言メモ。legend やヘルプテキストでの簡易説明に使う。
    /// 黄体期は体重変動の文脈で重要なので意図的に「水分」に触れる。
    var hint: String {
        switch self {
        case .menstrual:  return "出血のある期間"
        case .follicular: return "心身が安定しやすい時期"
        case .ovulation:  return "中央付近の数日"
        case .luteal:     return "水分貯留で体重が一時増えやすい"
        }
    }

    /// Chart の背景帯で使う色 (低 opacity)。チャート上の体重ラインを邪魔しない。
    var tint: Color {
        switch self {
        case .menstrual:  return Color(red: 0.92, green: 0.45, blue: 0.50) // 落ち着いた赤
        case .follicular: return Color(red: 0.55, green: 0.78, blue: 0.62) // 爽やかな緑
        case .ovulation:  return Color(red: 0.95, green: 0.78, blue: 0.30) // 注目の黄
        case .luteal:     return Color(red: 0.78, green: 0.58, blue: 0.85) // 落ち着いた紫
        }
    }
}
