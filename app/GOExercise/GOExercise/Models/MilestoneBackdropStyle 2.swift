import Foundation

/// 画面全体の達成背景パラメータ(純ロジック)。**現在の連続日数**駆動。
/// `CatRank` の rank/richness/metalKind を流用し、グラデ深さ・グロー・粒子数・最上位の微動を導出する。
struct MilestoneBackdropStyle: Equatable {
    /// 0..11。0 = 装飾なし。
    let rank: Int
    /// グラデの深さ 0..1。
    let richness: Double
    /// 中心グローの濃さ 0..1。
    let glowOpacity: Double
    /// きらめき粒子の数(0..24)。
    let sparkleCount: Int
    /// 最上位(rank>=10)のみ淡い光の帯をゆっくり動かす。
    let animated: Bool
    /// 色帯のメタル種別。rank0 は nil。
    let metalKind: MetalKind?

    init(streak: Int) {
        let r = CatRank(currentStreak: streak)
        self.rank = r.rank
        self.richness = r.richness
        // 3LLM検証: 365/500 の黄色が眩しすぎる指摘を反映し控えめに。
        self.glowOpacity = r.richness * 0.42
        self.sparkleCount = r.rank == 0 ? 0 : min(4 + r.rank * 2, 24)
        self.animated = r.rank >= 10
        self.metalKind = r.metalKind
    }
}
