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
    @State private var selected: PetBreed
    /// 上部セグメント(猫 / 犬)。選択中キャラの species を初期値にする。
    @State private var species: PetSpecies
    @State private var showPaywall = false
    @State private var inviteCode = ""
    @State private var isSubmittingInvite = false
    @State private var inviteAccepted = false
    /// オンボーディングで猫選択の後に表示するバックアップ用サインインステップ。
    @State private var showBackupStep = false
    let isOnboarding: Bool

    private var referralUnlocked: Bool {
        // 現サインインアカウントの friend_code と summary の由来アカウントが一致する場合のみ解放。
        // 切替/復元直後(未 refresh)に前アカウントの星で有料猫を解放させない
        // (Codex指摘: 口座跨ぎの stale entitlement)。
        referralStore.isBreedUnlocked(forAccount: friendsStore.profile?.friendCode)
    }

    init(isOnboarding: Bool = false) {
        self.isOnboarding = isOnboarding
        let pet = UserCatPreferences.shared.myPet
        _selected = State(initialValue: pet)
        _species = State(initialValue: pet.species)
    }

    /// 現在のセグメント(猫/犬)で表示する候補一覧。
    private var breedsForSpecies: [PetBreed] {
        switch species {
        case .cat: return CatBreed.allCases.map { PetBreed.cat($0) }
        case .dog: return DogBreed.selectable.map { PetBreed.dog($0) }   // アーカイブ(ブルドッグ)除外
        }
    }

    var body: some View {
        // オンボーディングで猫選択後はバックアップ用サインインへ。連携が有効でない
        // ビルドではスキップ(従来どおり猫選択のみで完了)。
        if isOnboarding && showBackupStep {
            backupStep
        } else {
            catPickerBody
        }
    }

    /// オンボーディングが2ステップ(猫選択 → バックアップ)かどうか。
    /// 連携が無効なビルドでは1ステップ(猫選択のみ)になるのでステップ表示も出さない。
    private var isTwoStepOnboarding: Bool {
        isOnboarding && SupabaseConfig.isAccountLinkingEnabled
    }

    /// 両ステップ共通のヘッダー。ステップ表示(2ステップ時のみ)+ 大見出し + 補足。
    @ViewBuilder
    private func onboardingHeader(step: Int, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if isTwoStepOnboarding {
                Text("ステップ \(step) / 2")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(Palette.primaryDeep)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Palette.primary.opacity(0.14), in: Capsule())
            }
            Text(title)
                .font(Typography.title)
                .foregroundStyle(Palette.textPrimary)
            Text(subtitle)
                .font(Typography.body)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - ステップ1: 猫選択

    private var catPickerBody: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isOnboarding {
                        onboardingHeader(
                            step: 1,
                            title: "一緒にがんばる相棒を選ぼう",
                            subtitle: AppFeatureFlags.friendsEnabled
                                ? "選んだ相棒はホーム画面・達成演出・友達一覧で使われます。今だけ全種類から自由に選べます(あとで種類を変えるにはプレミアムが必要)。"
                                : "選んだ相棒はホーム画面・達成演出で使われます。今だけ全種類から自由に選べます(あとで種類を変えるにはプレミアムが必要)。"
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    }

                    // Big preview of the currently-selected breed (animated by Code)
                    catPreview

                    // 猫 / 犬 のセグメント切替。切替で同 species の現在選択を維持、
                    // 別 species なら先頭種を仮選択する。
                    Picker("種別", selection: $species) {
                        ForEach(PetSpecies.allCases) { sp in
                            Text(sp.displayName).tag(sp)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("pet-species-segment")
                    .onChange(of: species) { _, newSpecies in
                        if selected.species != newSpecies {
                            selected = breedsForSpecies.first ?? .default
                        }
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible()), GridItem(.flexible()),
                        GridItem(.flexible()), GridItem(.flexible())
                    ], spacing: 14) {
                        ForEach(breedsForSpecies) { breed in
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
            .navigationTitle(isOnboarding ? "" : "自分のキャラを選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            // オンボーディングはアクションを下部に固定(2画面で配置を統一)。
            .safeAreaInset(edge: .bottom) {
                if isOnboarding {
                    PrimaryButton(isTwoStepOnboarding ? "つぎへ" : "はじめる", systemImage: "arrow.right") {
                        advanceFromCatSelection()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .accessibilityIdentifier("user-cat-confirm")
                }
            }
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("キャンセル") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("決定") {
                            commitSelectedCat()
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("user-cat-confirm")
                    }
                }
            }
            .interactiveDismissDisabled(isOnboarding)   // onboarding は閉じれない
            .sheet(isPresented: $showPaywall) {
                PremiumPaywallSheet(store: storeKit, context: .general)
            }
        }
    }

    /// 選択中の猫を確定して保存。初期設定では何でも選べる。確定後の再選択(設定)では
    /// ロック中の猫は無効化して現状維持(=種類変更にはプレミアムが必要)。
    private func commitSelectedCat() {
        if !isOnboarding,
           PetBreedAccess.isLocked(selected, current: prefs.myPet, isPremium: storeKit.isPremiumActive, referralUnlocked: referralUnlocked) {
            selected = prefs.myPet
        }
        prefs.myPet = selected
    }

    private func advanceFromCatSelection() {
        commitSelectedCat()
        // 連携が有効ならバックアップステップへ。無効ビルドはそのまま完了。
        if isTwoStepOnboarding {
            showBackupStep = true
        } else {
            completeOnboarding()
        }
    }

    // MARK: - ステップ2: バックアップ(猫選択と同じレイアウト言語で統一)

    /// 猫選択の後の「機種変更でも記録を引き継ぐ?」ステップ(任意・スキップ可)。
    /// サインインした人は記録バックアップが自動 ON になり、以後どの端末でも復元できる。
    private var backupStep: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    onboardingHeader(
                        step: 2,
                        title: "機種変更でも記録を引き継ぐ",
                        subtitle: "Apple または Google でサインインすると、運動・体重・体調の記録が自動でバックアップされ、機種変更(iPhone↔Android)や再インストールでも元に戻せます。メールやパスワードは不要です。"
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                    // ステップ1と同じ猫ヒーローを置いて、2画面の連続性を出す。
                    catPreview

                    AccountBackupSignIn(onFinished: { _ in completeOnboarding() }, showsSkip: true)
                        .padding(.horizontal, 20)

                    Text("あとから設定 →「アカウントとバックアップ」でも有効にできます。")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 20)
            }
            .background(Palette.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 猫選択へ戻れるように(ウィザードの一貫性)。
                ToolbarItem(placement: .topBarLeading) {
                    Button("もどる") { showBackupStep = false }
                        .accessibilityIdentifier("backup-step-back")
                }
            }
            .interactiveDismissDisabled(true)
        }
    }

    private func completeOnboarding() {
        Analytics.track(.onboardingCompleted)
        dismiss()
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
                    .scaledToFit() // 耳/リボンが円で切れないよう fill+overscale から fit へ
                    .frame(width: 160, height: 160)
                    .clipShape(Circle())
                    .catSilhouetteContrast()
            }
            Text(selected.displayName)
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private func cell(_ breed: PetBreed) -> some View {
        let isSelected = selected == breed
        // 初期設定(オンボーディング)では全種類を自由に選べる(ロックしない)。
        // 確定後に種類を変えるにはプレミアムが必要 = 設定からの再選択時のみロック判定する。
        let locked = !isOnboarding &&
            PetBreedAccess.isLocked(breed, current: prefs.myPet, isPremium: storeKit.isPremiumActive, referralUnlocked: referralUnlocked)
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
                        .scaledToFit() // 耳/リボンが円で切れないよう fill+overscale から fit へ
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .catSilhouetteContrast()
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
        .accessibilityIdentifier(accessibilityID(for: breed))
    }

    /// UI テスト用 id。猫は従来どおり "user-cat-<raw>"、犬は "user-dog-<raw>"。
    private func accessibilityID(for breed: PetBreed) -> String {
        switch breed {
        case .cat(let b): return "user-cat-\(b.rawValue)"
        case .dog(let b): return "user-dog-\(b.rawValue)"
        }
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
