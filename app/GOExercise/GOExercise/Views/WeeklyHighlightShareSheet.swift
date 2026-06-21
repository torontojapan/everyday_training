import SwiftUI
import UIKit

/// 今週のハイライトを SNS シェアできるブランドカードに整形して表示するシート。
/// `StreakShareSheet` と同じ ImageRenderer ベースの実装パターン:
/// - `WeeklyHighlightShareCard` を中央に描画
/// - 起動時に ImageRenderer で UIImage 化し、`ShareLink(item: Image, preview:)` で共有
/// - 「写真に保存」ボタンも提供
struct WeeklyHighlightShareSheet: View {
    let summary: ExerciseTrendSummary.WeeklySummary
    let weekLabel: String  // 例: "5/26 - 6/1"
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?
    @AppStorage("shareCard.gradient.weekly") private var gradientRaw = ShareCardGradient.sunset.rawValue
    @State private var poseSeed = Int.random(in: 0..<10_000)

    init(summary: ExerciseTrendSummary.WeeklySummary,
         weekLabel: String,
         isPresented: Binding<Bool> = .constant(true)) {
        self.summary = summary
        self.weekLabel = weekLabel
        self._isPresented = isPresented
    }

    private var appName: String { "GO エクササイズ" }
    private var gradient: ShareCardGradient { ShareCardGradient(rawValue: gradientRaw) ?? .sunset }

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

                    WeeklyHighlightShareCard(
                        summary: summary,
                        weekLabel: weekLabel,
                        appName: appName,
                        gradientColors: gradient.colors,
                        poseSeed: poseSeed
                    )

                    if let renderedImage {
                        ShareLink(
                            item: renderedImage,
                            preview: SharePreview("Weeklyハイライト · \(appName)",
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
        let card = WeeklyHighlightShareCard(summary: summary, weekLabel: weekLabel, appName: appName, gradientColors: gradient.colors, poseSeed: poseSeed, fillFrame: true)
            .frame(width: ShareCardLayout.canvas.width, height: ShareCardLayout.canvas.height)
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

/// ImageRenderer で書き出される静的ブランドカード。
/// ShareCardLayout.canvas (600×1300, スマホ全画面比) で書き出す、SNS プレビューに乗りやすい縦長比率。
struct WeeklyHighlightShareCard: View {
    let summary: ExerciseTrendSummary.WeeklySummary
    let weekLabel: String
    let appName: String
    var gradientColors: [Color] = ShareCardGradient.sunset.colors
    var poseSeed: Int = 0
    /// ImageRenderer でスマホ全画面比のキャンバス (ShareCardLayout.canvas = 600×1300) に書き出すとき true。フレーム全面をグラデで塗り、
    /// 上下の白余白を消す(ユーザー要望)。
    var fillFrame: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            // バッジ
            Text("WEEKLY HIGHLIGHT")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .tracking(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 5)
                .background(.black.opacity(0.45), in: Capsule())

            Text("Weeklyハイライト")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(weekLabel)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            // 猫キャラ (大きく)
            catImage
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.top, 4)

            // メイン KPI: 合計時間
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(summary.totalDurationSeconds / 60)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("分")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            // 使ったカテゴリの chip 群
            if !summary.usedCategories.isEmpty {
                HStack(spacing: 8) {
                    ForEach(summary.usedCategories.prefix(5)) { category in
                        Text(category.displayName)
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(.white.opacity(0.22), in: Capsule())
                    }
                }
            }

            // よく使う種目
            if !summary.topExerciseNames.isEmpty {
                VStack(spacing: 4) {
                    Text("よく使う種目")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                    Text(summary.topExerciseNames.prefix(3).joined(separator: " · "))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 4)
            }

            Text(appName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: fillFrame ? .infinity : nil)
        .background {
            let gradient = LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if fillFrame {
                gradient  // フルブリード: 隅まで塗って白余白を消す
            } else {
                gradient.clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
            }
        }
        .shadow(color: .black.opacity(fillFrame ? 0 : 0.18), radius: fillFrame ? 0 : 24, y: fillFrame ? 0 : 10)
    }

    /// 選択中の猫キャラ (celebrating ポーズ。asset 欠落時は orange fallback、それも
    /// 無ければ emoji)。share card は静的なので毎回新 instance でも問題なし。
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
