import Foundation
import SwiftUI

/// 友達アバター用の動物バリエーション。本人 (自分) は CatStateView で
/// オレンジ猫が出るので、友達側はこの 10 種類からランダムに割り当てる。
/// 全 asset は同じスポーティーキャラスタイル (Phase 6.5 で Codex 生成)。
enum BuddyAvatar: String, CaseIterable, Sendable {
    case dog, rabbit, panda, fox, koala, tiger, frog, wolf, lion, monkey

    var assetName: String { "buddy_\(rawValue)" }

    /// 円形背景に乗せる時の色味。各動物の主な色味に合わせると馴染む。
    var tintColor: Color {
        switch self {
        case .dog:    return Color(red: 0.95, green: 0.78, blue: 0.55)   // 柴犬の薄茶
        case .rabbit: return Color(red: 0.95, green: 0.92, blue: 0.95)   // ほぼ白
        case .panda:  return Color(red: 0.85, green: 0.85, blue: 0.88)   // 薄灰
        case .fox:    return Color(red: 1.00, green: 0.75, blue: 0.55)   // 赤系オレンジ
        case .koala:  return Color(red: 0.75, green: 0.78, blue: 0.82)   // グレー
        case .tiger:  return Color(red: 1.00, green: 0.78, blue: 0.55)   // オレンジ + 黒
        case .frog:   return Color(red: 0.70, green: 0.90, blue: 0.65)   // 緑
        case .wolf:   return Color(red: 0.80, green: 0.82, blue: 0.85)   // 銀グレー
        case .lion:   return Color(red: 0.98, green: 0.85, blue: 0.55)   // 黄金
        case .monkey: return Color(red: 0.88, green: 0.75, blue: 0.60)   // 茶
        }
    }

    /// 日本語のキャラクター名 (デバッグ / アクセシビリティ用)。
    var displayName: String {
        switch self {
        case .dog:    return "いぬ"
        case .rabbit: return "うさぎ"
        case .panda:  return "パンダ"
        case .fox:    return "きつね"
        case .koala:  return "コアラ"
        case .tiger:  return "とら"
        case .frog:   return "かえる"
        case .wolf:   return "オオカミ"
        case .lion:   return "ライオン"
        case .monkey: return "サル"
        }
    }
}

enum BuddyAvatarResolver {
    /// friendCode を hash して 10 種類から deterministic に動物を選ぶ。
    /// 同じ friendCode は常に同じ動物に解決されるので、一覧でも詳細でも
    /// 同じアバターになる + サーバーへ何も書かなくても再現可能。
    static func avatar(for friendCode: String) -> BuddyAvatar {
        let hash = stableHash(friendCode)
        let all = BuddyAvatar.allCases
        return all[hash % all.count]
    }

    /// FNV-1a 32-bit hash. Swift の Int.hashValue はプロセス毎にランダム
    /// salt 付きで再現性がないため、独自の安定 hash を使う。
    private static func stableHash(_ string: String) -> Int {
        var hash: UInt32 = 0x811c9dc5
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x01000193
        }
        return Int(hash & 0x7fffffff)
    }
}
