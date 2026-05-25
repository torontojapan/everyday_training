import SwiftUI

struct StreakShareSheet: View {
    let streak: Int
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?

    init(streak: Int, isPresented: Binding<Bool> = .constant(true)) {
        self.streak = streak
        self._isPresented = isPresented
    }

    private var level: StreakLevel { StreakLevel(streak: streak) }
    private var appName: String { "GOエクササイズ" }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: level.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 56)

                    StreakShareCard(streak: streak, appName: appName)

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
        let card = StreakShareCard(streak: streak, appName: appName)
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

struct StreakShareCard: View {
    let streak: Int
    let appName: String

    private var level: StreakLevel { StreakLevel(streak: streak) }

    var body: some View {
        VStack(spacing: 18) {
            if let badge = level.badgeText {
                Text(badge)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.45), in: Capsule())
            }

            Text(level.headline)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 4) {
                Text(String(repeating: "🔥", count: level.fireCount))
                    .font(.system(size: 28))
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(streak)")
                    .font(.system(size: 110, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("日連続")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            ZStack {
                ForEach(0..<level.sparkleCount, id: \.self) { idx in
                    sparkle(at: idx)
                }
                catImage
                    .frame(width: 180, height: 180)
            }
            .frame(height: 220)

            Text(appName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 8)

            Text("GO Exercise")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
                .tracking(1.5)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                LinearGradient(
                    colors: level.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .opacity(0.85)
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 2)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
    }

    @ViewBuilder
    private var catImage: some View {
        if UIImage(named: level.catStateAssetName) != nil {
            Image(level.catStateAssetName)
                .resizable()
                .scaledToFit()
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.45), lineWidth: 3))
        } else {
            Text(level.fallbackEmoji)
                .font(.system(size: 100))
        }
    }

    private func sparkle(at index: Int) -> some View {
        let angle = Double(index) / Double(max(1, level.sparkleCount)) * 360
        let radius: CGFloat = 110 + CGFloat(index % 3) * 12
        let size: CGFloat = 12 + CGFloat(index % 4) * 4
        return Text("✨")
            .font(.system(size: size))
            .offset(
                x: cos(angle * .pi / 180) * radius,
                y: sin(angle * .pi / 180) * radius
            )
    }
}
