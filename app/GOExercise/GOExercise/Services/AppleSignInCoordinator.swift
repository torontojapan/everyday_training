#if canImport(AuthenticationServices) && os(iOS)
import AuthenticationServices
import CryptoKit
import UIKit

/// Sign in with Apple のネイティブフローを実行し、Supabase 連携用の (idToken, rawNonce) を返す。
///
/// 設計 (Phase 2 / [[AccountLinking]]):
/// - `rawNonce` を生成し、リクエストには **SHA256 ハッシュ**を、Supabase には **rawNonce** を渡す
///   (リプレイ防止。取り違えると検証失敗)。
/// - email は要求しない (匿名志向)。`fullName` は初回認可時のみ得られるため表示名候補として扱う。
/// - Swift 6 strict concurrency: デリゲートは nonisolated で受け、Sendable 値のみ MainActor へ渡す。
@MainActor
final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    struct Result: Sendable {
        let idToken: String
        let nonce: String
        let fullName: String?
    }

    private var continuation: CheckedContinuation<Result, Error>?
    private var rawNonce = ""

    /// Apple 認可を実行して id_token と rawNonce を取得する。
    func requestIdToken() async throws -> Result {
        // 再入ガード: 既に実行中なら新規要求は無視 (継続の取りこぼし防止)。
        guard continuation == nil else { throw AccountLinkError.cancelled }
        let raw = try Self.randomNonce()
        rawNonce = raw
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(raw)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Result, Error>) in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private func finish(_ result: Swift.Result<Result, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        switch result {
        case .success(let r): cont.resume(returning: r)
        case .failure(let e): cont.resume(throwing: e)
        }
    }

    // MARK: ASAuthorizationControllerDelegate
    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithAuthorization authorization: ASAuthorization) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        let token = credential?.identityToken.flatMap { String(data: $0, encoding: .utf8) }
        let name = credential?.fullName.flatMap {
            PersonNameComponentsFormatter().string(from: $0).trimmingCharacters(in: .whitespaces)
        }
        let fullName = (name?.isEmpty == false) ? name : nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let token, !token.isEmpty {
                self.finish(.success(Result(idToken: token, nonce: self.rawNonce, fullName: fullName)))
            } else {
                self.finish(.failure(AccountLinkError.failed))
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController,
                                             didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        Task { @MainActor [weak self] in
            self?.finish(.failure(cancelled ? AccountLinkError.cancelled : AccountLinkError.failed))
        }
    }

    // MARK: ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let scene = (scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return scene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    // MARK: - nonce
    /// 安全な乱数 nonce。RNG 失敗時は**決定的フォールバックせず throw**する (予測可能な
    /// nonce はリプレイ耐性を損なうため)。charset は 64 文字なので 256 を割り切り、mod バイアスなし。
    private static func randomNonce(length: Int = 32) throws -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        guard SecRandomCopyBytes(kSecRandomDefault, length, &bytes) == errSecSuccess else {
            throw AccountLinkError.failed
        }
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
#endif
