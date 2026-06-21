import SwiftUI
import UIKit

/// 累計記録 (これまでの記録) を SNS シェアできるブランドカードに整形して表示するシート。
/// StreakShareSheet / WeeklyHighlightShareSheet と同じ ImageRenderer ベース。
struct LifetimeStatsShareSheet: View {
    let achievedDays: Int
    let usedDays: Int
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?
    @AppStorage("shareCard.gradient.lifetime") private var gradientRaw = ShareCardGradient.daybreak.rawValue
    @State private var poseSeed = Int.random(in: 0..<10_000)

    init(achievedDays: Int,
         usedDays: Int,
         isPresented: Binding<Bool> = .constant(true)) {
        self.achievedDays = achievedDays
        self.usedDays = usedDays
        self._isPresented = isPresented
    }

    private var appName: String { "GO エクササイズ" }
    private var gradient: ShareCardGradient { ShareCardGradient(rawValue: gradientRaw) ?? .daybreak }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: gradient.colors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 56)

                    LifetimeStatsShareCard(
                        achievedDays: achievedDays,
                        usedDays: usedDays,
                        appName: appName,
                        gradientColors: gradient.colors,
                        poseSeed: poseSeed
                    )

                    if let renderedImage {
                        ShareLink(
                            item: renderedImage,
                            preview: SharePreview("これまでの記録 · \(appName)",
                                                   image: renderedImage)
                        ) {
                            Label("SNSで共有", systemImage: "square.and.arrow.up")
                                .font(Typography.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32).padding(.vertical, 14)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                    } else {
                        ProgressView().tint(.white).padding(.vertical, 20)
                    }

                    if let uiImage = renderedUIImage {
                        Button {
                            saveToPhotos(uiImage)
                        } label: {
                            Label("写真に保存", systemImage: "photo.badge.plus")
                                .font(Typography.body)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28).padding(.vertical, 12)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }

                    ShareGradientPicker(selectionRaw: $gradientRaw)

                    if let saveBannerText {
                        Text(saveBannerText)
                            .font(Typography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(.black.opacity(0.45), in: Capsule())
                    }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }
            closeButtonOverlay
        }
        .task { renderImage() }
        .onChange(of: gradientRaw) { _, _ in renderImage() }
    }

    private var closeButtonOverlay: some View {
        HStack {
            Spacer()
            Button {
                isPresented = false
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.55), in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.6), lineWidth: 1))
            }
            .accessibilityLabel("閉じる")
            .padding(.top, 12).padding(.trailing, 16)
            .buttonStyle(.plain)
            .zIndex(10)
        }
    }

    @MainActor
    private func renderImage() {
        let card = LifetimeStatsShareCard(
            achievedDays: achievedDays, usedDays: usedDays, appName: appName,
            gradientColors: gradient.colors, poseSeed: poseSeed, fillFrame: true
        ).frame(width: ShareCardLayout.canvas.width, height: ShareCardLayout.canvas.height)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(ShareCardLayout.canvas)
        if let uiImage = renderer.uiImage {
            renderedUIImage = uiImage
            renderedImage = Image(uiImage: uiImage)
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        saveBannerText = "保存中..."
        ImageSaver().save(image) { result in
            switch result {
            case .success:
                saveBannerText = "✓ 写真に保存しました"
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == "ALAssetsLibraryErrorDomain" || nsError.code == -3311 {
                    saveBannerText = "写真への保存が許可されていません。設定アプリから許可してください。"
                } else {
                    saveBannerText = "保存に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct LifetimeStatsShareCard: View {
    let achievedDays: Int
    let usedDays: Int
    let appName: String
    var gradientColors: [Color] = ShareCardGradient.daybreak.colors
    var poseSeed: Int = 0
    /// ImageRenderer で書き出すとき true。フレーム全面をグラデで塗り、上下の白余白を消す。
    var fillFrame: Bool = false

    /// 達成率 (使用日 0 のときは 0 で防御)。
    private var rate: Double {
        guard usedDays > 0 else { return 0 }
        return Double(achievedDays) / Double(usedDays)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("LIFETIME RECORD")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())

            Text("これまでの記録")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // 猫キャラ (大きく、誇らしげな celebrating ポーズ)
            catImage
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.top, 4)

            // 中央の大数字 (累計達成日)
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(achievedDays)")
                    .font(.system(size: 100, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("日達成")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            // ratio バー + 使用日数
            VStack(spacing: 6) {
                Text("使用 \(usedDays) 日中")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))

                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(0.22))
                        .frame(height: 12)
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.white)
                            .frame(width: geo.size.width * CGFloat(min(1.0, rate)),
                                   height: 12)
                    }
                    .frame(height: 12)
                }
                .frame(maxWidth: 280)

                Text("達成率 \(Int((rate * 100).rounded()))%")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(appName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: fillFrame ? .infinity : nil)
        .background {
            let g = LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if fillFrame {
                g  // フルブリード: 隅まで塗って白余白を消す
            } else {
                g.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(fillFrame ? 0 : 0.18), radius: fillFrame ? 0 : 24, y: fillFrame ? 0 : 10)
    }

    private var catImage: some View {
        let breed = UserCatPreferences.shared.myPet
        // ハッピーポーズ3種(celebrating/happy2/happy3)から poseSeed で1つ選ぶ。
        let resolved = breed.randomHappyPoseAsset(seed: poseSeed, exists: { UIImage(named: $0) != nil })
        return Group {
            if UIImage(named: resolved) != nil {
                Image(resolved)
                    .resizable()
                    .scaledToFit()
            } else {
                Text("😺").font(.system(size: 120))
            }
        }
    }
}
