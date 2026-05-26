import Foundation

/// Phase 6.7 で「友達のアバター = その友達が設定している猫」の方針に
/// 変更。ユーザー側で各友達のアバターを選ぶ仕組み (BuddyAvatarStore /
/// BuddyCatPickerSheet) は廃止し、相手の `FriendProfile.myCatBreed` を
/// そのまま参照するだけのシンプルな resolver に縮小した。
enum FriendAvatarResolver {
    /// 相手が CloudKit (or Mock) に登録している猫を返す。未設定の場合は
    /// friendCode から決定論的に default を当てる (こちらは旧友達 / 古い
    /// payload の救済用)。
    static func resolve(for friend: FriendProfile) -> CatBreed {
        if let breed = friend.myCatBreed { return breed }
        return defaultBreed(for: friend.friendCode)
    }

    static func defaultBreed(for friendCode: String) -> CatBreed {
        let hash = stableHash(friendCode)
        let all = CatBreed.allCases
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
