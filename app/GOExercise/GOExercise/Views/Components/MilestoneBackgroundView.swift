import SwiftUI

/// 猫の「後ろ」に敷く達成背景。overlay 不具合(顔の上に重ねる)を避けるため、
/// 必ず猫画像より下のレイヤーに置くこと。tier0 / 画像未存在なら透明(何も描かない)。
struct MilestoneBackgroundView: View {
    let totalAchievedDays: Int

    var body: some View {
        if let name = MilestoneBackground(totalAchievedDays: totalAchievedDays).assetName,
           UIImage(named: name) != nil {
            Image(name)
                .resizable()
                .scaledToFill()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}
