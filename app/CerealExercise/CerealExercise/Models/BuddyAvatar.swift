import Foundation
import SwiftUI

/// 友達アバター用の猫の品種・毛色バリエーション。Phase 6.6 で
/// 「全部猫にしてほしい + ユーザーが選べるようにしてほしい」要望に応えて
/// 動物 10 種から猫 10 種類に置き換え。
///
/// 自分 (ホーム画面の主役) は CatStateView 経由でオレンジ猫を使うので、
/// 友達側のラインナップにはオレンジトラを意図的に入れない (重複回避)。
enum BuddyCat: String, CaseIterable, Identifiable, Sendable {
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

    var assetName: String { "buddy_\(rawValue)" }

    /// 円形背景の tint。各猫の主色味に寄せると馴染む。
    var tintColor: Color {
        switch self {
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
}

/// 友達ごとに「ユーザーが選んだ猫」を覚えておくシンプルな UserDefaults
/// ベースのストア。Mock 段階なので backend には書かない (将来 CloudKit
/// に移したら preferredBuddyCat フィールドを Profile に追加して同期する)。
@MainActor
final class FriendAvatarStore {
    static let shared = FriendAvatarStore()

    private let defaults: UserDefaults
    private let keyPrefix = "friend.buddyCat."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func chosen(for friendCode: String) -> BuddyCat? {
        guard let raw = defaults.string(forKey: keyPrefix + friendCode) else { return nil }
        return BuddyCat(rawValue: raw)
    }

    func set(_ cat: BuddyCat?, for friendCode: String) {
        let key = keyPrefix + friendCode
        if let cat {
            defaults.set(cat.rawValue, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

enum FriendAvatarResolver {
    /// ユーザーが明示的に選んだ猫があればそれを使う。なければ friendCode
    /// から決定論的にデフォルトを当てる。これで新規友達でも「とりあえず
    /// 何かしらのアバター」が表示され、後から自由に変更できる。
    @MainActor
    static func resolve(for friendCode: String,
                        store: FriendAvatarStore = .shared) -> BuddyCat {
        if let chosen = store.chosen(for: friendCode) {
            return chosen
        }
        return defaultAvatar(for: friendCode)
    }

    /// 安定 hash (FNV-1a 32-bit) で deterministic に選ぶ。Swift の
    /// hashValue はプロセス毎にランダムなので使えない。
    static func defaultAvatar(for friendCode: String) -> BuddyCat {
        let hash = stableHash(friendCode)
        let all = BuddyCat.allCases
        return all[hash % all.count]
    }

    private static func stableHash(_ string: String) -> Int {
        var hash: UInt32 = 0x811c9dc5
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return Int(hash & 0x7fffffff)
    }
}
