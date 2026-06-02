#if canImport(AuthenticationServices) && os(iOS)
import AuthenticationServices
import UIKit

/// Google 連携の web/PKCE フローを `ASWebAuthenticationSession` で実行する。
///
/// 設計 (Phase 2 / [[AccountLinking]]):
/// - Apple ([[AppleSignInCoordinator]]) は ASAuthorization のネイティブ id_token だが、
///   Google は **web/PKCE** で経路が違う。本 coordinator は「認可 URL を web で開き、
///   `goexercise://` のコールバック URL を返す」だけを担う ([[WebAuthFlow]])。
/// - 認可 URL の生成と PKCE code 交換 (`session(from:)`) は Supabase SDK 側 = Service が行う
///   (SupabaseFriendsService.linkGoogle / signInWithGoogle)。
/// - `callbackURLScheme` で OS がリダイレクトを ASWebAuthenticationSession に直接戻すため、
///   コールバックはアプリの `.onOpenURL` には流れない (友達コード deep link と衝突しない)。
/// - 再入ガード・`.cancelled` 写像・presentation anchor を Apple と同じ堅牢度で扱う。
@MainActor
final class GoogleSignInCoordinator: NSObject, ASWebAuthenticationPresentationContextProviding {

    /// ASWebAuthenticationSession がコールバックを捕捉するスキーム。
    /// `SupabaseConfig.googleRedirectURL` の scheme と一致させる (Info.plist 登録済)。
    static let callbackScheme = "goexercise"

    /// 実行中の session を強参照で保持 (途中で解放されると認可がキャンセル扱いになる)。
    private var session: ASWebAuthenticationSession?

    /// 認可 URL を web で提示し、コールバック URL を返す。Service が `WebAuthFlow` として渡す。
    /// 再入ガード: 実行中の新規要求は `.cancelled` で弾く (継続の取りこぼし防止, Apple と対称)。
    func presentWebFlow(url: URL) async throws -> URL {
        guard session == nil else { throw AccountLinkError.cancelled }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: Self.callbackScheme
            ) { [weak self] callbackURL, error in
                self?.session = nil
                if let error {
                    // ユーザーが Cancel を押した場合は静かに扱う (エラーバナーを出さない)。
                    let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                    cont.resume(throwing: cancelled ? AccountLinkError.cancelled : AccountLinkError.failed)
                } else if let callbackURL {
                    cont.resume(returning: callbackURL)
                } else {
                    cont.resume(throwing: AccountLinkError.failed)
                }
            }
            session.presentationContextProvider = self
            // 既存の Google ログインセッションを使えるよう ephemeral にはしない (再入力を避ける)。
            session.prefersEphemeralWebBrowserSession = false
            self.session = session
            // start() が false を返すのは提示不能 (anchor 無し等)。完了ハンドラは呼ばれないので
            // ここで continuation を解決する (二重 resume にはならない)。
            if !session.start() {
                self.session = nil
                cont.resume(throwing: AccountLinkError.failed)
            }
        }
    }

    // MARK: ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
        let scene = (scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        return scene?.windows.first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
#endif
