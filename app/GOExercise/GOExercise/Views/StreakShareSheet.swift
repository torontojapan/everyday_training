import SwiftUI

struct StreakShareSheet: View {
    let streak: Int
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?
    /// 背景グラデの選択(端末ローカルに記憶。カード種別ごとのキー)。
    @AppStorage("shareCard.gradient.streak") private var gradientRaw = ShareCardGradient.ocean.rawValue

    init(streak: Int, isPresented: Binding<Bool> = .constant(true)) {
        self.streak = streak
        self._isPresented = isPresented
    }

    private var level: StreakLevel { StreakLevel(streak: streak) }
    private var appName: String { "GO エクササイズ" }
    private var gradient: ShareCardGradient { ShareCardGradient(rawValue: gradientRaw) ?? .ocean }

    var body: some View {
        ZStack(alignment: .top) {
            // フルスクリーン背景はカードと同じ選択グラデ(既定 = 寒色オーシャン)。
            LinearGradient(
                colors: gradient.colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 56)

                    StreakShareCard(streak: streak, appName: appName, gradientColors: gradient.colors)

                    if let renderedImage {
                        ShareLink(
                            item: renderedImage,
                            preview: SharePreview(
                                "\(streak)日連続運動達成!",
                                image: renderedImage
                            )
                        ) {
                            Label("SNSで共有", systemImage: "square.and.arrow.up")
                                .font(Typography.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                    } else {
                        ProgressView()
                            .tint(.white)
                            .padding(.vertical, 20)
                    }

                    if let uiImage = renderedUIImage {
                        Button {
                            saveToPhotos(uiImage)
                        } label: {
                            Label("写真に保存", systemImage: "photo.badge.plus")
                                .font(Typography.body)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 28)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.2), in: Capsule())
                        }
                    }

                    // 背景グラデの選択(5種)。変更すると共有画像も再レンダリングされる。
                    ShareGradientPicker(selectionRaw: $gradientRaw)

                    if let saveBannerText {
                        Text(saveBannerText)
                            .font(Typography.caption)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.45), in: Capsule())
                    }

                    Spacer().frame(height: 40)
                }
                .padding(20)
            }

            closeButtonOverlay
        }
        .task {
            renderImage()
        }
        .onChange(of: gradientRaw) { _, _ in renderImage() }
    }

    private var closeButtonOverlay: some View {
        HStack {
            Spacer()
            Button {
                // Belt-and-suspenders close. The Binding flips the parent's
                // isPresented so the sheet definitely dismisses, and dismiss()
                // is kept as a fallback for environments where Binding is
                // .constant(true) (e.g. direct launch via --initial-route).
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
            .padding(.top, 12)
            .padding(.trailing, 16)
            .contentShape(Circle())
            .buttonStyle(.plain)
            .zIndex(10)
        }
    }

    @MainActor
    private func renderImage() {
        let card = StreakShareCard(streak: streak, appName: appName, gradientColors: gradient.colors)
            .frame(width: 600, height: 800)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 600, height: 800)
        if let uiImage = renderer.uiImage {
            renderedUIImage = uiImage
            renderedImage = Image(uiImage: uiImage)
        }
    }

    private func saveToPhotos(_ image: UIImage) {
        saveBannerText = "保存中..."
        let saver = ImageSaver()
        saver.save(image) { result in
            switch result {
            case .success:
                saveBannerText = "✓ 写真に保存しました"
            case .failure(let error):
                // Most common case: user denied 写真追加 permission. Surface a
                // friendly hint instead of the raw NSError string.
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

/// ImageRenderer で書き出される静的ブランドカード。
/// `WeeklyHighlightShareCard`(履歴タブのハイライト)とレイアウト言語を統一:
/// バッジ → タイトル → 大きい猫 → 巨大 KPI → アプリ名。🔥/✨ の絵文字装飾は廃止。
/// 背景はハイライト(暖色)と被らない寒色系グラデーション(ユーザー要望)。
struct StreakShareCard: View {
    let streak: Int
    let appName: String
    var gradientColors: [Color] = ShareCardGradient.ocean.colors

    private var level: StreakLevel { StreakLevel(streak: streak) }

    var body: some View {
        VStack(spacing: 18) {
            // バッジ(レベル称号があればそれを、無ければ STREAK)
            Text(level.badgeText ?? "STREAK")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())

            Text(level.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            // 猫キャラ (大きく。ハイライトカードと同じ扱い)
            catImage
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.top, 4)

            // メイン KPI: 連続日数
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(streak)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("日連続")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            Text(appName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }

    @ViewBuilder
    private var catImage: some View {
        // ハイライトカードと同じ scaledToFit(被写体が全面に入っている asset 前提)。
        if UIImage(named: level.catStateAssetName) != nil {
            Image(level.catStateAssetName)
                .resizable()
                .scaledToFit()
        } else {
            Text(level.fallbackEmoji)
                .font(.system(size: 100))
        }
    }
}
