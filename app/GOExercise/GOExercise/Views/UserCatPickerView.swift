import SwiftUI

/// 自分のキャラを 11 種類から選ぶ画面。
/// 初回起動時は「アプリへようこそ」モードで全画面表示、設定画面からの
/// 呼び出し時は普通のシートとして表示する。
struct UserCatPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(StoreKitManager.self) private var storeKit
    @Environment(ReferralStore.self) private var referralStore
    @Environment(FriendsStore.self) private var friendsStore
    @State private var prefs = UserCatPreferences.shared
    @State private var selected: CatBreed
    @State private var showPaywall = false
    @State private var inviteCode = ""
    @State private var isSubmittingInvite = false
    @State private var inviteAccepted = false
    let isOnboarding: Bool

    private var referralUnlocked: Bool {
        ReferralReward.isBreedUnlocked(starBadges: referralStore.summary.starBadges)
    }

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
                            Text(AppFeatureFlags.friendsEnabled
                                 ? "選んだ猫はホーム画面・達成演出・友達一覧で使われます。あとから設定でいつでも変更できます。"
                                 : "選んだ猫はホーム画面・達成演出で使われます。あとから設定でいつでも変更できます。")
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

                    if isOnboarding && AppFeatureFlags.isReferralActive {
                        Group {
                            if inviteAccepted {
                                Label("招待コードを適用しました!", systemImage: "checkmark.seal.fill")
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.primaryDeep)
                            } else {
                                InviteCodeField(code: $inviteCode, isSubmitting: isSubmittingInvite) {
                                    submitInvite()
                                }
                            }
                            if let err = referralStore.lastError, !inviteAccepted {
                                Text(err).font(Typography.caption).foregroundStyle(.red)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                    }
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
                        if CatBreedAccess.isLocked(selected, current: prefs.myCat, isPremium: storeKit.isPremiumActive, referralUnlocked: referralUnlocked) {
                            selected = prefs.myCat
                        }
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
            .sheet(isPresented: $showPaywall) {
                PremiumPaywallSheet(store: storeKit, context: .general)
            }
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
        let locked = CatBreedAccess.isLocked(breed, current: prefs.myCat, isPremium: storeKit.isPremiumActive, referralUnlocked: referralUnlocked)
        return Button {
            if locked { showPaywall = true } else { selected = breed }
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
                        .opacity(locked ? 0.45 : 1)
                    if locked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                    }
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
        .accessibilityLabel(locked ? "\(breed.displayName)(プレミアムで解放)" : breed.displayName)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("user-cat-\(breed.rawValue)")
    }

    private func submitInvite() {
        isSubmittingInvite = true
        referralStore.lastError = nil
        Task {
            // 招待コード入力には匿名サインインが必要(能動操作なので opt-in に合致)。
            await friendsStore.ensureSignedIn()
            let ok = await referralStore.submitCode(inviteCode)
            isSubmittingInvite = false
            if ok { inviteAccepted = true }
        }
    }
}
