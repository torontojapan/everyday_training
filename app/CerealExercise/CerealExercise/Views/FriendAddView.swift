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
    @State private var searchTask: Task<Void, Never>?

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
                        .onChange(of: searchQuery) { _, newValue in
                            // クリアしたら「見つかりません」と古い結果を消し、
                            // 進行中の検索 Task もキャンセルする (Gemini 指摘: race)。
                            if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
                                searchTask?.cancel()
                                searchTask = nil
                                isSearching = false
                                hasSearched = false
                                searchResults = []
                            }
                        }
                    Button("検索") {
                        searchTask?.cancel()
                        searchTask = Task { await runSearch() }
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
            resultMessage = "\(target) に友達申請を送りました 🤝"
            codeInput = ""
        }
    }

    private func runSearch() async {
        let query = searchQuery
        isSearching = true
        let results = await friendsStore.search(query)
        // Task が cancel されている (= テキストがクリアされた) なら結果を反映しない
        if Task.isCancelled { return }
        // search 中にクエリが変わっていたら古い結果は捨てる
        if query != searchQuery { return }
        searchResults = results
        isSearching = false
        hasSearched = true
    }
}
