#if canImport(AuthenticationServices) && os(iOS)
import AuthenticationServices
import SwiftUI

/// 公式 Sign in with Apple ボタン (`ASAuthorizationAppleIDButton`) の SwiftUI ラッパー。
///
/// App Store 審査 (HIG) 要件で、Apple ログインのボタンは**独自装飾を付けず**公式の見た目を
/// 使う必要がある (Codex#F)。タップで `action` を呼ぶだけで、実際の認可フローは
/// [[AppleSignInCoordinator]] が担う (nonce/SHA256 を正しく扱うため流用)。
struct AppleIDButton: UIViewRepresentable {
    var type: ASAuthorizationAppleIDButton.ButtonType = .signIn
    var style: ASAuthorizationAppleIDButton.Style = .black
    var cornerRadius: CGFloat = 12
    let action: () -> Void

    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        let button = ASAuthorizationAppleIDButton(authorizationButtonType: type, authorizationButtonStyle: style)
        button.cornerRadius = cornerRadius
        button.addTarget(context.coordinator, action: #selector(Coordinator.didTap), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {
        // クロージャは毎回キャプチャし直す (state 変化に追従)。
        context.coordinator.action = action
        uiView.cornerRadius = cornerRadius
    }

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    final class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func didTap() { action() }
    }
}
#endif
