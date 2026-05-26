import SwiftUI

/// 友達 (本人以外) のアバター表示。ユーザーが選んだ猫があればそれを、
/// なければ friendCode から決定論的に選ばれた default を表示。
struct FriendAvatarView: View {
    let friendCode: String
    var size: CGFloat = 44
    var showsDecorationBorder: Bool = false
    var decorationTier: Int = 0

    private var cat: BuddyCat { FriendAvatarResolver.resolve(for: friendCode) }

    var body: some View {
        ZStack {
            Circle()
                .fill(cat.tintColor.opacity(0.30))
                .frame(width: size, height: size)
            Image(cat.assetName)
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
        .accessibilityLabel("友達のアバター \(cat.displayName)")
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

/// 猫 10 種類を 5×2 グリッドで表示する選択シート。
/// 「友達ごとに自分の好みのアバターを当てる」ための UI。
struct BuddyCatPickerSheet: View {
    let friendCode: String
    let friendDisplayName: String
    @Environment(\.dismiss) private var dismiss
    @State private var selected: BuddyCat

    init(friendCode: String, friendDisplayName: String) {
        self.friendCode = friendCode
        self.friendDisplayName = friendDisplayName
        _selected = State(initialValue: FriendAvatarResolver.resolve(for: friendCode))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\(friendDisplayName) に当てる猫を選んでください。")
                        .font(Typography.body)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 12) {
                        ForEach(BuddyCat.allCases) { cat in
                            catCell(cat)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(Palette.background)
            .navigationTitle("アバターを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("決定") {
                        FriendAvatarStore.shared.set(selected, for: friendCode)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("buddy-cat-confirm")
                }
            }
        }
    }

    private func catCell(_ cat: BuddyCat) -> some View {
        let isSelected = selected == cat
        return Button {
            selected = cat
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(cat.tintColor.opacity(0.30))
                        .frame(width: 64, height: 64)
                    Image(cat.assetName)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.10)
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                }
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Palette.primaryDeep : .clear, lineWidth: 3)
                        .frame(width: 64, height: 64)
                }
                Text(cat.displayName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Palette.primaryDeep : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(cat.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("buddy-cat-\(cat.rawValue)")
    }
}
