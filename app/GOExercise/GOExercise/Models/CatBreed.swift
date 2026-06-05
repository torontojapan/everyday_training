import Foundation
import SwiftUI

/// 猫の種類。自分用 (UserCatPreferences) + 友達 (FriendProfile.myCatBreed)
/// の両方で使う共通 enum。orange は Phase 6.3 で導入した既存の主役猫、
/// それ以外 10 種類は Phase 6.7 で全 7 状態 × 10 breeds を生成して追加。
enum CatBreed: String, CaseIterable, Identifiable, Codable, Sendable {
    case orange       // 既存: オレンジトラ (デフォルト)
    case black
    case white
    case gray
    case calico
    case silvertabby
    case browntabby
    case siamese
    case tuxedo
    case persian
    case scottish

    var id: String { rawValue }

    /// 円形背景の tint。各猫の主色味に寄せる。
    var tintColor: Color {
        switch self {
        case .orange:      return Color(red: 1.00, green: 0.65, blue: 0.35)
        case .black:       return Color(red: 0.30, green: 0.30, blue: 0.32)
        case .white:       return Color(red: 0.95, green: 0.95, blue: 0.97)
        case .gray:        return Color(red: 0.65, green: 0.70, blue: 0.75)
        case .calico:      return Color(red: 1.00, green: 0.80, blue: 0.55)
        case .silvertabby: return Color(red: 0.75, green: 0.78, blue: 0.82)
        case .browntabby:  return Color(red: 0.75, green: 0.55, blue: 0.38)
        case .siamese:     return Color(red: 0.92, green: 0.86, blue: 0.75)
        case .tuxedo:      return Color(red: 0.35, green: 0.35, blue: 0.38)
        case .persian:     return Color(red: 0.93, green: 0.88, blue: 0.78)
        case .scottish:    return Color(red: 0.70, green: 0.75, blue: 0.80)
        }
    }

    var displayName: String {
        switch self {
        case .orange:      return "オレンジトラ"
        case .black:       return "黒猫"
        case .white:       return "白猫"
        case .gray:        return "グレー猫"
        case .calico:      return "三毛猫"
        case .silvertabby: return "サバトラ"
        case .browntabby:  return "茶トラ"
        case .siamese:     return "シャム"
        case .tuxedo:      return "ハチワレ"
        case .persian:     return "ペルシャ"
        case .scottish:    return "スコティッシュ"
        }
    }

    /// `cat_<breed>_<state>` 形式の asset 名を返す。例: cat_orange_celebrating。
    /// CatStateView がここから「ユーザーの猫 × 今の気持ち」を解決する。
    func assetName(for state: CatState) -> String {
        "cat_\(rawValue)_\(state.rawValue)"
    }

    /// 一覧 / 詳細 / ランキング用の単一アバター画像。waitingMorning を
    /// デフォルトポーズとして使う (一番中性的な表情)。
    var avatarAssetName: String {
        "cat_\(rawValue)_waitingMorning"
    }

    /// 達成日数に応じたアイテム付きアバター asset 名。アイテムは単一ポーズ
    /// (waitingMorning)のアバターにのみ焼き込む(ホームの大猫には付けない=案A)。
    func avatarAssetName(totalAchievedDays days: Int) -> String {
        let suffix = MilestoneItem(totalAchievedDays: days).assetSuffix
        return "cat_\(rawValue)_waitingMorning\(suffix)"
    }

    /// 該当アセットが見つからない場合のフォールバック用 asset 名。
    /// Phase 6.7 で 70 画像中いくつか生成漏れがあった場合、orange の
    /// 同 state を代わりに表示することで「画像が出ない」のを防ぐ。
    /// （後から生成し直して差し替えると自動的に正しい breed が出る）
    static func fallbackAssetName(for state: CatState) -> String {
        "cat_orange_\(state.rawValue)"
    }

    static var fallbackAvatarAssetName: String {
        "cat_orange_waitingMorning"
    }
}

/// ユーザー自身が選んだ猫種を覚えておくシンプルなストア。
@MainActor
@Observable
final class UserCatPreferences {
    static let key = "user.myCat"
    static let shared = UserCatPreferences()

    private let defaults: UserDefaults

    /// 選択した猫。未選択 (onboarding 未完了) なら orange をデフォルトに。
    var myCat: CatBreed {
        didSet { defaults.set(myCat.rawValue, forKey: Self.key) }
    }

    /// onboarding を完了したかどうかの判定。raw value が defaults に
    /// 書き込まれているか = 1度でも明示的に選んだか で見る。
    var hasCompletedOnboarding: Bool {
        defaults.string(forKey: Self.key) != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.key), let breed = CatBreed(rawValue: raw) {
            self.myCat = breed
        } else {
            self.myCat = .orange   // 初期 default
        }
    }
}
