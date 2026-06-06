import Foundation

/// 達成日数で決まる「画面全体の達成背景」のパラメータ(純ロジック)。
/// tier は既存 `MilestoneBackground` を流用し、グラデの深さ・グロー・粒子数・最上位の微動を導出する。
struct MilestoneBackdropStyle: Equatable {
    /// 0 = 装飾なし、1..11(`MilestoneBackground.thresholds.count`)。
    let tier: Int
    /// グラデの深さ 0..1。
    let richness: Double
    /// 中心グローの濃さ 0..1。
    let glowOpacity: Double
    /// きらめき粒子の数(0..24)。
    let sparkleCount: Int
    /// 最上位(365日〜)のみ、淡い光の帯をゆっくり動かす。
    let animated: Bool

    init(totalAchievedDays days: Int) {
        let t = MilestoneBackground(totalAchievedDays: days).tier
        self.tier = t
        let maxTier = Double(MilestoneBackground.thresholds.count) // 11
        self.richness = min(1, Double(t) / maxTier)
        self.glowOpacity = richness * 0.55
        self.sparkleCount = t == 0 ? 0 : min(4 + t * 2, 24)
        self.animated = t >= 10
    }
}
