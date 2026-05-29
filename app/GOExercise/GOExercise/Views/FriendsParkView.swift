import SwiftUI

/// Phase 7.0 で導入した「猫公園」ビュー。
/// 既存のリスト型 (FriendsView) と切替可能。友達の猫アバターをグリッドに
/// 散らした 2D ビューで、今日達成は活発に、未達成は静かに表現する。
struct FriendsParkView: View {
    let friends: [FriendProfile]
    let onTap: (FriendProfile) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        // Park-like background: subtle green tint
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.96, blue: 0.88),
                    Color(red: 0.95, green: 0.97, blue: 0.92)
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(maxWidth: .infinity)

            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(friends) { friend in
                    parkAvatar(friend)
                }
            }
            .padding(20)
        }
    }

    private func parkAvatar(_ friend: FriendProfile) -> some View {
        let breed = FriendAvatarResolver.resolve(for: friend)
        let resolvedAsset = UIImage(named: breed.avatarAssetName) != nil
            ? breed.avatarAssetName
            : CatBreed.fallbackAvatarAssetName
        let isActive = friend.todayAchieved
        return Button {
            onTap(friend)
        } label: {
            VStack(spacing: 4) {
                ZStack(alignment: .top) {
                    // 影 (達成済みは大きく濃く)
                    Ellipse()
                        .fill(.black.opacity(isActive ? 0.18 : 0.10))
                        .frame(width: 60, height: 8)
                        .offset(y: 78)
                    Image(resolvedAsset)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(isActive ? 1.05 : 0.92)   // 達成済みは大きく
                        .opacity(isActive ? 1.0 : 0.72)       // 未達成は薄め
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                        .background(
                            Circle()
                                .fill(breed.tintColor.opacity(isActive ? 0.30 : 0.18))
                                .frame(width: 80, height: 80)
                        )
                        .overlay(alignment: .topTrailing) {
                            if friend.todayAchieved {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Palette.success)
                                    .background(Circle().fill(Palette.background).frame(width: 22, height: 22))
                                    .offset(x: 4, y: -2)
                            }
                        }
                }
                Text(friend.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 3) {
                    Text("🔥")
                        .font(.system(size: 10))
                    Text("\(friend.currentStreak)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(Palette.primaryDeep)
                        .monospacedDigit()
                }
            }
            .frame(height: 130)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(friend.displayName) \(friend.todayAchieved ? "今日達成" : "今日まだ"), 連続 \(friend.currentStreak) 日")
        .accessibilityIdentifier("park-friend-\(friend.friendCode)")
    }
}
