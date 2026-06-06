import SwiftUI

/// 友達 (本人以外) のアバター表示。相手が設定している猫を表示する。
struct FriendAvatarView: View {
    let friend: FriendProfile
    var size: CGFloat = 44
    var showsDecorationBorder: Bool = false

    private var breed: CatBreed { FriendAvatarResolver.resolve(for: friend) }

    private var resolvedAsset: String {
        // アバターアイテム画像(MilestoneItem: オレンジ専用 shaker/crown)は退役。
        // 達成段階は decorationBorder リング(tier 色)で表現する。
        if UIImage(named: breed.avatarAssetName) != nil { return breed.avatarAssetName }
        return CatBreed.fallbackAvatarAssetName
    }

    var body: some View {
        ZStack {
            // 達成背景は画像カードを廃止(ホームの MilestoneBackdrop に一本化)。
            // 友達アバターは小さい文脈なので背景なし(猫種 tint の円のみ)に簡素化。
            Circle()
                .fill(breed.tintColor.opacity(0.30))
                .frame(width: size, height: size)
            Image(resolvedAsset)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.10)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .overlay {
            if showsDecorationBorder {
                // 称号 (CatRank) があればメタル色リング、無ければ friendCode 由来の識別色リング。
                // 同じ猫種が並んでも一目で区別でき、称号ランクとも両立する (トンマナ維持の細リング)。
                if friend.rank.rank > 0, let metal = friend.rank.metalKind {
                    Circle()
                        .strokeBorder(metalRingColor(metal), lineWidth: 2)
                        .frame(width: size, height: size)
                } else {
                    Circle()
                        .strokeBorder(Self.identityRingColor(for: friend.friendCode), lineWidth: 1.5)
                        .frame(width: size, height: size)
                }
            }
        }
        .accessibilityLabel("\(friend.displayName) のアバター \(breed.displayName)")
    }

    /// friendCode から決定論的に色相を導く (同じ猫種でも一目で区別するための識別リング)。
    /// 0.0..<1.0 の hue を返す純粋関数 (テスト可能)。
    /// FNV-1a (32bit) で位置依存ハッシュにし、アナグラム衝突や hue 候補の偏りを避ける。
    static func identityRingHue(for code: String) -> Double {
        var hash: UInt32 = 2166136261
        for scalar in code.unicodeScalars {
            hash ^= scalar.value
            hash = hash &* 16777619
        }
        return Double(hash % 360) / 360.0
    }

    /// 識別リングの色。彩度・明度は控えめにしてトンマナ (peach 系) を壊さない。
    static func identityRingColor(for code: String) -> Color {
        Color(hue: identityRingHue(for: code), saturation: 0.40, brightness: 0.80)
            .opacity(0.55)
    }

    private func metalRingColor(_ kind: MetalKind) -> Color {
        MetalStyle.isRainbow(kind) ? Color(red: 1.0, green: 0.80, blue: 0.42) : MetalStyle.baseColor(kind)
    }
}
