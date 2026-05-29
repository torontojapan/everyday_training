import SwiftUI

/// 自分のキャラを 11 種類から選ぶ画面。
/// 初回起動時は「アプリへようこそ」モードで全画面表示、設定画面からの
/// 呼び出し時は普通のシートとして表示する。
struct UserCatPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prefs = UserCatPreferences.shared
    @State private var selected: CatBreed
    let isOnboarding: Bool

    init(isOnboarding: Bool = false) {
        self.isOnboarding = isOnboarding
        _selected = State(initialValue: UserCatPreferences.shared.myCat)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isOnboarding {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("一緒にがんばる猫を選ぼう")
                                .font(Typography.title)
                                .foregroundStyle(Palette.textPrimary)
                            Text("選んだ猫はホーム画面・達成演出・友達一覧で使われます。あとから設定でいつでも変更できます。")
                                .font(Typography.body)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    // Big preview of the currently-selected breed (animated by Code)
                    catPreview

                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 14) {
                        ForEach(CatBreed.allCases) { breed in
                            cell(breed)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 20)
            }
            .background(Palette.background)
            .navigationTitle(isOnboarding ? "ようこそ" : "自分のキャラを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル") { dismiss() }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isOnboarding ? "はじめる" : "決定") {
                        prefs.myCat = selected
                        if isOnboarding {
                            Analytics.track(.onboardingCompleted)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("user-cat-confirm")
                }
            }
            .interactiveDismissDisabled(isOnboarding)   // onboarding は閉じれない
        }
    }

    private var catPreview: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [selected.tintColor.opacity(0.50), selected.tintColor.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 160, height: 160)
                Image(selected.avatarAssetName)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(1.05)
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
            }
            Text(selected.displayName)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func cell(_ breed: CatBreed) -> some View {
        let isSelected = selected == breed
        return Button {
            selected = breed
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(breed.tintColor.opacity(0.30))
                        .frame(width: 64, height: 64)
                    Image(breed.avatarAssetName)
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
                Text(breed.displayName)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? Palette.primaryDeep : Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(breed.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("user-cat-\(breed.rawValue)")
    }
}
