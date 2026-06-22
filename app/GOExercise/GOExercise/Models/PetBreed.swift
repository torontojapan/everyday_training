import Foundation
import SwiftUI

/// キャラの種別(猫 / 犬)。ピッカー上部のセグメント切替に使う。
enum PetSpecies: String, CaseIterable, Identifiable, Codable, Sendable {
    case cat
    case dog

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cat: return "猫"
        case .dog: return "犬"
        }
    }
}

/// 犬の種類(5 種)。`CatBreed` と同じ API 面を持ち、asset は `dog_<breed>_<state>`。
/// 猫と同じ 10 ポーズ(7 state + happy2/happy3/shaker)を全種そろえる。
enum DogBreed: String, CaseIterable, Identifiable, Codable, Sendable {
    case shiba        // 柴犬
    case chihuahua    // チワワ
    case toypoodle    // トイプードル
    case golden       // ゴールデンレトリバー
    case bulldog      // ブルドッグ
    case dachshund    // ミニチュアダックスフンド
    case corgi        // ウェルシュ・コーギー
    case schnauzer    // ミニチュアシュナウザー
    case pomeranian   // ポメラニアン

    var id: String { rawValue }

    /// 円形背景の tint。各犬種の主色味に寄せる。
    var tintColor: Color {
        switch self {
        case .shiba:     return Color(red: 0.88, green: 0.55, blue: 0.30)
        case .chihuahua: return Color(red: 0.85, green: 0.68, blue: 0.45)
        case .toypoodle: return Color(red: 0.92, green: 0.82, blue: 0.65)
        case .golden:    return Color(red: 0.95, green: 0.72, blue: 0.35)
        case .bulldog:   return Color(red: 0.88, green: 0.80, blue: 0.70)
        case .dachshund: return Color(red: 0.70, green: 0.42, blue: 0.28)
        case .corgi:     return Color(red: 0.90, green: 0.62, blue: 0.38)
        case .schnauzer: return Color(red: 0.55, green: 0.55, blue: 0.58)
        case .pomeranian:return Color(red: 0.95, green: 0.70, blue: 0.40)
        }
    }

    var displayName: String {
        switch self {
        case .shiba:     return "柴犬"
        case .chihuahua: return "チワワ"
        case .toypoodle: return "トイプードル"
        case .golden:    return "ゴールデン"
        case .bulldog:   return "ブルドッグ"
        case .dachshund: return "ダックス"
        case .corgi:     return "コーギー"
        case .schnauzer: return "シュナウザー"
        case .pomeranian:return "ポメラニアン"
        }
    }

    func assetName(for state: CatState) -> String { "dog_\(rawValue)_\(state.rawValue)" }
    var avatarAssetName: String { "dog_\(rawValue)_waitingMorning" }
    var shakerAssetName: String { "dog_\(rawValue)_waitingMorning_shaker" }

    /// 生成漏れ時のフォールバック。まず同 state の柴犬 → 最終的に orange 猫(必ず存在)。
    static func fallbackAssetName(for state: CatState) -> String { "dog_shiba_\(state.rawValue)" }
    static var fallbackAvatarAssetName: String { "dog_shiba_waitingMorning" }
}

/// ユーザーが選べるキャラ。猫(11 種)か犬(5 種)のどちらか。
/// `CatBreed` と同一の API 面を露出して、描画側(CatStateView / 共有カード等)が
/// `myCat` を `myPet` に置き換えるだけで犬も描けるようにする。
enum PetBreed: Hashable, Codable, Sendable, Identifiable {
    case cat(CatBreed)
    case dog(DogBreed)

    var id: String { storageValue }

    var species: PetSpecies {
        switch self {
        case .cat: return .cat
        case .dog: return .dog
        }
    }

    static let `default`: PetBreed = .cat(.orange)

    // MARK: - CatBreed と同一の描画 API

    var displayName: String {
        switch self {
        case .cat(let b): return b.displayName
        case .dog(let b): return b.displayName
        }
    }

    var tintColor: Color {
        switch self {
        case .cat(let b): return b.tintColor
        case .dog(let b): return b.tintColor
        }
    }

    func assetName(for state: CatState) -> String {
        switch self {
        case .cat(let b): return b.assetName(for: state)
        case .dog(let b): return b.assetName(for: state)
        }
    }

    var avatarAssetName: String {
        switch self {
        case .cat(let b): return b.avatarAssetName
        case .dog(let b): return b.avatarAssetName
        }
    }

    var shakerAssetName: String {
        switch self {
        case .cat(let b): return b.shakerAssetName
        case .dog(let b): return b.shakerAssetName
        }
    }

    /// 種別に応じた state フォールバック asset(同種の既定 → 最終 orange 猫)。
    func fallbackAssetName(for state: CatState) -> String {
        switch self {
        case .cat: return CatBreed.fallbackAssetName(for: state)
        case .dog: return DogBreed.fallbackAssetName(for: state)
        }
    }

    /// shaker 画像の解決。1) 当該キャラの shaker → 2) 当該キャラの avatar → 3) 同種フォールバック。
    func resolvedShakerAssetName(exists: (String) -> Bool) -> String {
        if exists(shakerAssetName) { return shakerAssetName }
        if exists(avatarAssetName) { return avatarAssetName }
        switch self {
        case .cat: return "cat_orange_waitingMorning_shaker"
        case .dog: return "dog_shiba_waitingMorning_shaker"
        }
    }

    /// 共有カード用ハッピーポーズ(celebrating/happy2/happy3)を seed で決定的に1つ選ぶ。
    func randomHappyPoseAsset(seed: Int, exists: (String) -> Bool) -> String {
        let prefix: String
        switch self {
        case .cat(let b): prefix = "cat_\(b.rawValue)"
        case .dog(let b): prefix = "dog_\(b.rawValue)"
        }
        let candidates = CatBreed.happyPoseSuffixes
            .map { "\(prefix)_\($0)" }
            .filter(exists)
        guard !candidates.isEmpty else {
            return species == .dog ? "dog_shiba_celebrating" : "cat_orange_celebrating"
        }
        return candidates[abs(seed) % candidates.count]
    }

    // MARK: - 永続化(UserDefaults 文字列)

    /// "cat:orange" / "dog:shiba" 形式。
    var storageValue: String {
        switch self {
        case .cat(let b): return "cat:\(b.rawValue)"
        case .dog(let b): return "dog:\(b.rawValue)"
        }
    }

    /// 友達公開プロフィール(Supabase `my_cat_breed` text 列)に載せる文字列。
    /// 猫は**従来どおり素の rawValue**("orange")で旧クライアント互換を保ち、
    /// 犬だけ "dog:shiba" 形式にする(旧クライアントはパース不能→既定猫にフォールバック=破綻なし)。
    /// 列追加マイグレーション不要でそのまま犬対応できる。
    var friendBreedString: String {
        switch self {
        case .cat(let b): return b.rawValue
        case .dog(let b): return "dog:\(b.rawValue)"
        }
    }

    init?(storageValue raw: String) {
        let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else {
            // 旧形式(prefix 無し = 猫の rawValue のみ)からの移行救済。
            if let cat = CatBreed(rawValue: raw) { self = .cat(cat); return }
            return nil
        }
        switch parts[0] {
        case "cat": if let b = CatBreed(rawValue: parts[1]) { self = .cat(b); return }
        case "dog": if let b = DogBreed(rawValue: parts[1]) { self = .dog(b); return }
        default: break
        }
        return nil
    }
}

/// キャラ選択のロック判定(課金解放)。猫犬どちらにも効く `CatBreedAccess` の汎用版。
/// 無料は「今のキャラ」以外ロック。紹介⭐10解放 or プレミアムで全解放。
enum PetBreedAccess {
    static func isLocked(_ breed: PetBreed, current: PetBreed,
                         isPremium: Bool, referralUnlocked: Bool = false) -> Bool {
        !isPremium && !referralUnlocked && breed != current
    }
}
