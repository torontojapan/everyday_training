import AVFoundation
import SwiftUI
import UIKit

/// 友達の QR を**アプリ内**で読み取るスキャナ。OS 標準カメラはカスタムスキームの QR を
/// 開けないため、アプリ同士の友達追加はこの自前スキャナで行う(LINE/Instagram と同方式)。
/// 読み取った文字列(`goexercise://friends?code=XXX` または 6 文字コード)から友達コードを
/// 抽出して `onCode` で返す。カメラ権限拒否/未対応端末はメッセージを表示する。
struct QRScannerView: View {
    /// 読み取り成功時に正規化済みの友達コードを返す。
    let onCode: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var permission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var didHandle = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                switch permission {
                case .authorized:
                    QRCameraRepresentable { raw in handle(raw) }
                        .ignoresSafeArea()
                    scanGuide
                case .notDetermined:
                    ProgressView()
                        .tint(.white)
                        .task {
                            _ = await AVCaptureDevice.requestAccess(for: .video)
                            permission = AVCaptureDevice.authorizationStatus(for: .video)
                        }
                default:
                    deniedMessage
                }
            }
            .navigationTitle("友達のQRを読み取る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private var scanGuide: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                .frame(width: 220, height: 220)
            Text("友達の招待QRを枠内に収めてください")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.top, 16)
            Spacer()
        }
    }

    private var deniedMessage: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white.opacity(0.85))
            Text("カメラへのアクセスが必要です")
                .font(.headline)
                .foregroundStyle(.white)
            Text("設定 > GO エクササイズ > カメラ をオンにすると読み取れます。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("設定を開く") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(.black)
        }
        .padding(32)
    }

    private func handle(_ raw: String) {
        guard !didHandle else { return }
        guard let code = Self.friendCode(from: raw) else { return }
        didHandle = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        onCode(code)
        dismiss()
    }

    /// 読み取り文字列から友達コードを取り出す。`goexercise://friends?code=XXX` でも、
    /// 生の 6 文字コードでも受ける。検証は `FriendCodeValidator` に委譲。
    static func friendCode(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // スキーム付きは URL として解釈する。ただし**本アプリのカスタムスキーム
        // (goexercise://friends?code=…)に限定**する。任意スキームの ?code= を拾うと、
        // 無関係な https://example.com/?code=XXX 等で誤った友達追加が起きる(Codex P1/P2)。
        if let url = URL(string: trimmed), url.scheme != nil {
            guard url.scheme?.lowercased() == "goexercise" else { return nil }
            return DeepLinkRouter.friendCode(from: url)
        }
        // それ以外は「生の 6 文字コード」とみなす。切り詰めで誤検出しないよう、
        // 元の文字数が変わらない(=最初から正規の6文字)ときだけ受理する。
        let sanitized = FriendCodeValidator.sanitize(trimmed)
        return (sanitized.count == trimmed.count && FriendCodeValidator.isValid(sanitized)) ? sanitized : nil
    }
}

/// AVFoundation のメタデータ出力で QR を読む UIViewController を SwiftUI に橋渡しする。
private struct QRCameraRepresentable: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    func makeUIViewController(context: Context) -> QRCameraController {
        let controller = QRCameraController()
        controller.onFound = onFound
        return controller
    }

    func updateUIViewController(_ controller: QRCameraController, context: Context) {}
}

final class QRCameraController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?
    private let session = AVCaptureSession()
    private var preview: AVCaptureVideoPreviewLayer?
    /// セッション操作(start/stop)を直列化する専用キュー。グローバル並行キューだと
    /// 開始途中に dismiss されたとき isRunning 判定がすれ違い、画面が消えた後に
    /// セッションが走り続ける可能性がある(Codex P2)。
    private let sessionQueue = DispatchQueue(label: "com.goexercise.qrscanner.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    private func configureSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        preview = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 直列キューで開始(メインを塞がない)。isRunning 判定もキュー上で行い順序を保つ。
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 開始 enqueue の後に必ず停止が走る(直列)。画面が消えたら無条件で停止予約。
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                    didOutput metadataObjects: [AVMetadataObject],
                                    from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        // delegate は nonisolated。onFound は MainActor 隔離なので main へホップして呼ぶ。
        Task { @MainActor in self.onFound?(value) }
    }
}
