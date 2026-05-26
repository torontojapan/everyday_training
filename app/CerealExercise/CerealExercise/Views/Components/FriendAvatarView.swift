import SwiftUI

/// 友達 (本人以外) のアバター表示。friendCode から決定論的に動物が選ばれ、
/// その動物の tint 色に合った円形背景に乗せる。
struct FriendAvatarView: View {
    let friendCode: String
    var size: CGFloat = 44
    var showsDecorationBorder: Bool = false
    var decorationTier: Int = 0

    private var avatar: BuddyAvatar { BuddyAvatarResolver.avatar(for: friendCode) }

    var body: some View {
        ZStack {
            Circle()
                .fill(avatar.tintColor.opacity(0.30))
                .frame(width: size, height: size)
            Image(avatar.assetName)
                .resizable()
                .scaledToFill()
                .scaleEffect(1.10)
                .frame(width: size, height: size)
                .clipShape(Circle())
        }
        .overlay {
            if showsDecorationBorder, decorationTier > 0 {
                Circle()
                    .strokeBorder(decorationBorderColor, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityLabel("友達のアバター \(avatar.displayName)")
    }

    private var decorationBorderColor: Color {
        switch decorationTier {
        case 1: return Palette.primary
        case 2: return Palette.settingsAccent
        case 3: return Color(red: 0.90, green: 0.60, blue: 0.20)
        case 4: return Color(red: 1.00, green: 0.82, blue: 0.30)
        default: return .clear
        }
    }
}
