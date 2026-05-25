import SwiftUI

struct FriendAddView: View {
    @Environment(FriendsStore.self) private var friendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var codeInput = ""
    @State private var searchQuery = ""
    @State private var searchResults: [FriendProfile] = []
    @State private var isSearching = false
    @State private var resultMessage: String?

    var body: some View {
        Form {
            Section("友達コードで追加") {
                TextField("6桁の英数字", text: $codeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("friend-code-field")

                Button {
                    Task { await sendByCode() }
                } label: {
                    Label("申請を送る", systemImage: "paperplane.fill")
                }
                .disabled(codeInput.count < 4)
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
                if searchResults.isEmpty && !isSearching && !searchQuery.isEmpty {
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
        isSearching = true
        searchResults = await friendsStore.search(searchQuery)
        isSearching = false
    }
}
