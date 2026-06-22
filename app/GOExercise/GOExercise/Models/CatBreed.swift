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
    case kijitora     // キジトラ(茶黒の縞)

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
        case .kijitora:    return Color(red: 0.58, green: 0.50, blue: 0.40)
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
        case .kijitora:    return "キジトラ"
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

    /// プロテインシェイカーを持つ待機ポーズの asset 名。例: cat_black_waitingMorning_shaker。
    /// 達成段階と無関係に「運動記録の前後」で出すフレーバー(spec E)。
    var shakerAssetName: String {
        "cat_\(rawValue)_waitingMorning_shaker"
    }

    /// shaker 画像の解決。存在チェック `exists` を注入してフォールバックする(テスト可能)。
    /// 1) 当該猫種の shaker → 2) 当該猫種の通常 waitingMorning → 3) orange shaker。
    /// 画像欠落でも必ず何か返るので破綻しない。
    func resolvedShakerAssetName(exists: (String) -> Bool) -> String {
        if exists(shakerAssetName) { return shakerAssetName }
        if exists(avatarAssetName) { return avatarAssetName }
        return "cat_orange_waitingMorning_shaker"
    }

    /// 共有カード用のハッピーポーズ候補(celebrating + 追加ハッピーポーズ)。
    /// 実在する asset だけを候補にするので、一部猫種で画像が欠けても安全。
    static let happyPoseSuffixes = ["celebrating", "happy2", "happy3"]

    /// 共有カードに出すハッピーポーズ asset 名を `seed` で決定的に1つ選ぶ。
    /// シート提示ごとに seed を変えれば「毎回ランダムなポーズ」になり、
    /// 同一提示内では seed 固定で再レンダリングしてもブレない。
    /// 当該猫種で実在する候補のみから選び、皆無なら orange の celebrating にフォールバック。
    func randomHappyPoseAsset(seed: Int, exists: (String) -> Bool) -> String {
        let candidates = Self.happyPoseSuffixes
            .map { "cat_\(rawValue)_\($0)" }
            .filter(exists)
        guard !candidates.isEmpty else { return "cat_orange_celebrating" }
        return candidates[abs(seed) % candidates.count]
    }
}

/// ユーザー自身が選んだ猫種を覚えておくシンプルなストア。
@MainActor
@Observable
final class UserCatPreferences {
    static let key = "user.myCat"
    static let petKey = "user.myPet"
    static let shared = UserCatPreferences()

    private let defaults: UserDefaults

    /// 選んだキャラ(猫 or 犬)。アプリ内の自分キャラ描画はすべてこれを使う。
    var myPet: PetBreed {
        didSet {
            defaults.set(myPet.storageValue, forKey: Self.petKey)
            // 友達公開プロフィール(myCatBreed)は当面 猫種のみ対応。猫を選んだ時だけ
            // myCat も更新し、犬選択時は直近の猫種を維持(=友達には猫が見える)。
            if case .cat(let b) = myPet { myCat = b }
        }
    }

    /// 友達公開プロフィール / ウィジェット用の猫種(従来互換)。犬選択時も猫として据え置く。
    var myCat: CatBreed {
        didSet { defaults.set(myCat.rawValue, forKey: Self.key) }
    }

    /// onboarding を完了したか。myPet か myCat のどちらかが書かれていれば完了。
    var hasCompletedOnboarding: Bool {
        defaults.string(forKey: Self.petKey) != nil || defaults.string(forKey: Self.key) != nil
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // myCat(従来キー)を先に復元(ローカルへ。全 stored property 初期化前に self を読まない)。
        let initialCat: CatBreed
        if let raw = defaults.string(forKey: Self.key), let breed = CatBreed(rawValue: raw) {
            initialCat = breed
        } else {
            initialCat = .orange   // 初期 default
        }
        self.myCat = initialCat
        // myPet を復元。未保存(既存ユーザー)なら myCat から移行。
        if let raw = defaults.string(forKey: Self.petKey), let pet = PetBreed(storageValue: raw) {
            self.myPet = pet
        } else {
            self.myPet = .cat(initialCat)
        }
    }
}
