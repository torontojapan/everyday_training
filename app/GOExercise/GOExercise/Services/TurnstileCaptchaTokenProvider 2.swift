#if canImport(WebKit) && os(iOS)
import UIKit
import WebKit

/// Cloudflare Turnstile を WKWebView で実行し、検証トークンを取得する [[CaptchaTokenProviding]]。
///
/// site key 設定時のみ `SupabaseFriendsService` から使用される (未設定時は [[NoCaptchaTokenProvider]])。
/// 最小の HTML をインメモリで読み込み、JS コールバックで得たトークンを
/// `WKScriptMessageHandler` 経由で受け取る。タイムアウト / 閉じる操作 / エラーにも対応。
///
/// ⚠️ **要設定 (キー所有者の作業)**:
/// - Cloudflare Turnstile で site key を発行し、`Secrets.xcconfig` の `TURNSTILE_SITE_KEY` →
///   Info.plist `TurnstileSiteKey` に注入する。
/// - Turnstile の許可ドメインに `baseURL` のホスト (既定 `https://goexercise.app`) を登録する
///   (WKWebView の origin がこの baseURL になり、未登録だとウィジェットが拒否される)。
/// - この経路は実機 + 実キーでの手動確認が必要 (CI/シミュレータでは未到達)。
@MainActor
final class TurnstileCaptchaTokenProvider: NSObject, CaptchaTokenProviding {
    private let siteKey: String
    private let baseURL: URL
    private let timeout: Duration

    init(siteKey: String,
         baseURL: URL = URL(string: "https://goexercise.app")!,
         timeout: Duration = .seconds(60)) {
        self.siteKey = siteKey
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func obtainTokenIfNeeded() async throws -> String? {
        let key = siteKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }   // config-gated: 未設定なら従来挙動
        let session = TurnstileChallengeSession(siteKey: key, baseURL: baseURL, timeout: timeout)
        return try await session.run()
    }
}

/// 1 回のチャレンジ表示〜トークン受領を司る。WKWebView をホスト VC に載せて modal 表示する。
@MainActor
private final class TurnstileChallengeSession: NSObject, WKScriptMessageHandler, UIAdaptivePresentationControllerDelegate {
    private let siteKey: String
    private let baseURL: URL
    private let timeout: Duration
    private var continuation: CheckedContinuation<String, Error>?
    private var timeoutTask: Task<Void, Never>?
    private weak var hostController: UIViewController?
    private var webView: WKWebView?

    init(siteKey: String, baseURL: URL, timeout: Duration) {
        self.siteKey = siteKey
        self.baseURL = baseURL
        self.timeout = timeout
    }

    func run() async throws -> String {
        // 呼び出し元 Task のキャンセルを即座に伝播する (timeout 待ちにしない)。finish は冪等。
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
                self.start(cont)
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
        }
    }

    private func start(_ cont: CheckedContinuation<String, Error>) {
        self.continuation = cont
        // continuation 登録前に既にキャンセル済みだと onCancel が空振りするため、ここで捕捉。
        if Task.isCancelled {
            finish(.failure(CancellationError()))
            return
        }
        guard let presenter = Self.topViewController() else {
            finish(.failure(CaptchaError.presentationUnavailable))
            return
        }
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "turnstile")
        let web = WKWebView(frame: .zero, configuration: config)
        web.loadHTMLString(Self.html(siteKey: siteKey), baseURL: baseURL)
        self.webView = web

        let content = UIViewController()
        content.view.backgroundColor = .systemBackground
        content.title = "確認"
        web.translatesAutoresizingMaskIntoConstraints = false
        content.view.addSubview(web)
        NSLayoutConstraint.activate([
            web.topAnchor.constraint(equalTo: content.view.safeAreaLayoutGuide.topAnchor),
            web.bottomAnchor.constraint(equalTo: content.view.bottomAnchor),
            web.leadingAnchor.constraint(equalTo: content.view.leadingAnchor),
            web.trailingAnchor.constraint(equalTo: content.view.trailingAnchor),
        ])
        // 明示キャンセル + スワイプで閉じた時も即 .cancelled で解決する (timeout 待ちにしない)。
        content.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.finish(.failure(CaptchaError.cancelled)) }
        )
        let nav = UINavigationController(rootViewController: content)
        nav.presentationController?.delegate = self
        self.hostController = nav
        presenter.present(nav, animated: true)

        // タイムアウト監視 (MainActor を継承)。finish は冪等。
        let limit = timeout
        self.timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: limit)
            guard !Task.isCancelled else { return }
            self?.finish(.failure(CaptchaError.timedOut))
        }
    }

    // MARK: WKScriptMessageHandler
    nonisolated func userContentController(_ controller: WKUserContentController,
                                           didReceive message: WKScriptMessage) {
        guard message.name == "turnstile" else { return }
        // Sendable な String? に取り出してから MainActor へ渡す (非Sendable辞書を跨がない)。
        let dict = message.body as? [String: Any]
        let token = dict?["token"] as? String
        let errorReason = dict?["error"] as? String
        Task { @MainActor [weak self] in
            if let token, !token.isEmpty {
                self?.finish(.success(token))
            } else {
                self?.finish(.failure(CaptchaError.challengeFailed(errorReason ?? "unknown")))
            }
        }
    }

    // MARK: UIAdaptivePresentationControllerDelegate
    /// ユーザーがシートをスワイプで閉じた場合。`finish` でこちらが dismiss した時は呼ばれない。
    nonisolated func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        Task { @MainActor [weak self] in self?.finish(.failure(CaptchaError.cancelled)) }
    }

    /// continuation を一度だけ解決し、webview とホスト VC を後片付けする。
    private func finish(_ result: Result<String, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "turnstile")
        webView = nil
        hostController?.dismiss(animated: true)
        hostController = nil
        switch result {
        case .success(let token): cont.resume(returning: token)
        case .failure(let error): cont.resume(throwing: error)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let scene = (scenes.first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? (scenes.first as? UIWindowScene)
        var top = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    private static func html(siteKey: String) -> String {
        """
        <!DOCTYPE html><html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <script src="https://challenges.cloudflare.com/turnstile/v0/api.js" async defer></script>
        <style>
          body { margin:0; display:flex; align-items:center; justify-content:center;
                 height:100vh; font-family:-apple-system,sans-serif; background:#fff; }
        </style></head><body>
        <div class="cf-turnstile" data-sitekey="\(siteKey)" data-callback="onToken" data-error-callback="onError"></div>
        <script>
          function onToken(t){ window.webkit.messageHandlers.turnstile.postMessage({ token: t }); }
          function onError(e){ window.webkit.messageHandlers.turnstile.postMessage({ error: String(e || 'error') }); }
        </script></body></html>
        """
    }
}
#endif
