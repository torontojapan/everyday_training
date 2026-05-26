import ActivityKit
import Foundation

/// Phase 7.0 Step 4: Live Activity (Dynamic Island + Lock Screen) で
/// 1 日中ユーザーのそばに猫を置くための ActivityKit データ型。
/// メインアプリ + Widget extension 両方からアクセスするため、
/// 両 target の sources に含める。
struct CatActivityAttributes: ActivityAttributes {
    typealias ContentState = State

    /// 1 日中変化していく可変部分。Activity.update(...) で書き換える。
    struct State: Codable, Hashable {
        var todayAchieved: Bool
        var currentStreak: Int
        var hoursLeftToday: Int
        /// 表示する猫の状態 (CatState.rawValue)。
        var catStateRaw: String
        /// ユーザーが選んでいる猫種 (CatBreed.rawValue)。
        var catBreedRaw: String
    }

    /// activity 開始時に固定される。猫種は途中で変えてもこの activity の
    /// 寿命中は state 更新で反映する想定なので、開始時刻だけ持つ。
    var startedAt: Date
}
