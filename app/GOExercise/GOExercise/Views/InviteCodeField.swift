import SwiftUI

/// 招待コード入力欄(オンボ・設定で再利用)。入力は自己補正(大文字化・許可文字のみ・6桁)。
/// 送信は親が closure で受ける。成功/失敗の文言は ReferralStore.lastError を親が表示する。
struct InviteCodeField: View {
    @Binding var code: String
    var isSubmitting: Bool
    var onSubmit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("招待コードをお持ちですか?(任意)")
                .font(Typography.headline)
                .foregroundStyle(Palette.textPrimary)
            Text("友達のコードを入れると、お互いにフリーズが増えます。")
                .font(Typography.caption)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 8) {
                TextField("ABC123", text: Binding(
                    get: { code },
                    set: { code = FriendCodeValidator.sanitize($0) }
                ))
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("invite-code-field")

                Button(action: onSubmit) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Text("送信").fontWeight(.semibold)
                    }
                }
                .disabled(!FriendCodeValidator.isValid(code) || isSubmitting)
                .accessibilityIdentifier("invite-code-submit")
            }
        }
    }
}
