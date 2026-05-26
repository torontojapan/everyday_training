import SwiftUI

struct FriendAddView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var codeInput = ""
    @State private var searchQuery = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    @State private var hasSearched = false   // 検索ボタンを押すまで「結果なし」を出さない
    @State private var resultMessage: String?
    /// 申請を送る前に「この相手にどの猫アバターを当てるか」を選んでおける。
    /// 申請成功時に FriendAvatarStore に保存される。
    @State private var preselectedCat: BuddyCat = .black

    var body: some View {
        Form {
            Section("友達コードで追加") {
                TextField("6桁の英数字", text: $codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("friend-code-field")
                    .onChange(of: codeInput) { _, newValue in
                        codeInput = FriendCodeValidator.sanitize(newValue)
                    }

                Button {
                    Task { await sendByCode() }
                } label: {
                    Label("申請を送る", systemImage: "paperplane.fill")
                }
                .disabled(!FriendCodeValidator.isValid(codeInput))

                if !codeInput.isEmpty && !FriendCodeValidator.isValid(codeInput) {
                    Text("友達コードは 6 桁の英数字です (O / 0 / I / 1 は使われません)")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }

            Section("ユーザー名で検索") {
                HStack {
                    TextField("ユーザー名 (一部でも可)", text: $searchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("検索") {
                        Task { await runSearch() }
                    }
                    .disabled(searchQuery.trimmingCharacters(in: .whitespaces).count < 2)
                }
                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
                // hasSearched ガード: 入力した瞬間に「見つかりません」が
                // 出るバグを防ぐ。検索ボタンを押した後のみ空結果を表示。
                if hasSearched && searchResults.isEmpty && !isSearching {
                    Text("該当するユーザーは見つかりませんでした")
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
                ForEach(searchResults) { result in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.displayName)
                                .font(Typography.body)
                            Text("@\(result.username) · 🔥 \(result.currentStreak)")
                                .font(Typography.caption)
                                .foregroundStyle(Palette.textSecondary)
                        }
                        Spacer()
                        Button("申請") {
                            Task { await sendByCode(code: result.friendCode) }
                        }
                        .font(Typography.caption)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Palette.primary, in: Capsule())
                        .foregroundStyle(.white)
                    }
                }
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(BuddyCat.allCases) { cat in
                            Button {
                                preselectedCat = cat
                            } label: {
                                VStack(spacing: 4) {
                                    ZStack {
                                        Circle()
                                            .fill(cat.tintColor.opacity(0.30))
                                            .frame(width: 52, height: 52)
                                        Image(cat.assetName)
                                            .resizable()
                                            .scaledToFill()
                                            .scaleEffect(1.10)
                                            .frame(width: 52, height: 52)
                                            .clipShape(Circle())
                                    }
                                    .overlay(
                                        Circle().strokeBorder(
                                            preselectedCat == cat ? Palette.primaryDeep : .clear,
                                            lineWidth: 3
                                        )
                                    )
                                    Text(cat.displayName)
                                        .font(.system(size: 10, weight: .medium, design: .rounded))
                                        .foregroundStyle(preselectedCat == cat ? Palette.primaryDeep : Palette.textSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("add-buddy-cat-\(cat.rawValue)")
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("相手のアバター (任意)")
            } footer: {
                Text("申請が承認されたら、選んだ猫が一覧 / 詳細に表示されます。後から詳細画面で変更できます。")
            }

            if let resultMessage {
                Section {
                    Text(resultMessage)
                        .font(Typography.caption)
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .navigationTitle("友達を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("閉じる") { dismiss() }
            }
        }
    }

    private func sendByCode(code: String? = nil) async {
        let target = code ?? codeInput
        await friendsStore.sendRequest(to: target)
        if let err = friendsStore.lastError {
            resultMessage = err
        } else {
            // 申請成功 → ユーザーが事前に選んだアバターを保存
            FriendAvatarStore.shared.set(preselectedCat, for: target.uppercased())
            resultMessage = "\(target) に友達申請を送りました 🤝 (\(preselectedCat.displayName))"
            codeInput = ""
        }
    }

    private func runSearch() async {
        isSearching = true
        searchResults = await friendsStore.search(searchQuery)
        isSearching = false
        hasSearched = true
    }
}
