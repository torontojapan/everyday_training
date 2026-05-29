import SwiftUI

/// 友達 (本人以外) のアバター表示。相手が設定している猫を表示する。
struct FriendAvatarView: View {
    let friend: FriendProfile
    var size: CGFloat = 44
    var showsDecorationBorder: Bool = false

    private var breed: CatBreed { FriendAvatarResolver.resolve(for: friend) }

    private var resolvedAsset: String {
        UIImage(named: breed.avatarAssetName) != nil
            ? breed.avatarAssetName
            : CatBreed.fallbackAvatarAssetName
    }

    var body: some View {
        ZStack {
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
            if showsDecorationBorder, friend.decorationTier > 0 {
                Circle()
                    .strokeBorder(decorationBorderColor, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel("\(friend.displayName) のアバター \(breed.displayName)")
    }

    private var decorationBorderColor: Color {
        switch friend.decorationTier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return .clear
        }
    }
}
