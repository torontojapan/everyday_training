import SwiftUI
import UIKit

/// 今月のハイライトを SNS シェアできるブランドカードに整形して表示するシート。
/// `WeeklyHighlightShareSheet` / `LifetimeStatsShareSheet` と同じ ImageRenderer
/// ベースのパターン (3 色グラデ背景 + 大きな猫キャラ + 写真に保存)。
struct MonthlyReviewSheet: View {
    let review: MonthlyReviewBuilder.Review
    /// 期間に応じた表示。デフォルトは月次 (既存呼び出しはそのまま動く)。
    /// 英字バッジは廃止し、タイトルに付ける SF Symbol アイコンに置き換え。
    var icon: String = "doc.text.image"
    var title: String = "Monthlyハイライト"
    var streakLabel: String = "今月の最長連続"
    var gradient: [Color] = MonthlyReviewSheet.monthlyGradient
    @Environment(\.dismiss) private var dismiss

    /// 期間ごとの背景グラデーション (先月=紫 / 今週=青緑 / 累計=金)。
    static let monthlyGradient: [Color] = [
        Color(red: 0.50, green: 0.48, blue: 0.92),
        Color(red: 0.62, green: 0.42, blue: 0.88),
        Color(red: 0.85, green: 0.48, blue: 0.80)
    ]
    static let weeklyGradient: [Color] = [
        Color(red: 0.16, green: 0.62, blue: 0.74),
        Color(red: 0.22, green: 0.70, blue: 0.66),
        Color(red: 0.42, green: 0.80, blue: 0.60)
    ]
    static let lifetimeGradient: [Color] = [
        Color(red: 0.96, green: 0.64, blue: 0.22),
        Color(red: 0.94, green: 0.52, blue: 0.28),
        Color(red: 0.90, green: 0.40, blue: 0.42)
    ]
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?
    /// 背景グラデの上書き選択。空 = 呼び出し元の既定 `gradient` を使う(先月=紫 等)。
    @AppStorage("shareCard.gradient.review") private var gradientRaw = ""
    @State private var poseSeed = Int.random(in: 0..<10_000)

    private var appName: String { "GO エクササイズ" }
    /// ピッカーで選んでいればそれを、未選択なら呼び出し元の既定を使う。
    private var activeGradient: [Color] {
        ShareCardGradient(rawValue: gradientRaw)?.colors ?? gradient
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: activeGradient,
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 56)

                    MonthlyReviewCard(review: review, appName: appName, icon: icon, title: title, streakLabel: streakLabel, gradient: activeGradient, poseSeed: poseSeed)

                    if let renderedImage {
                        ShareLink(
                            item: renderedImage,
                            preview: SharePreview("\(title) · \(appName)", image: renderedImage)
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
        let card = MonthlyReviewCard(review: review, appName: appName, icon: icon, title: title, streakLabel: streakLabel, gradient: activeGradient, poseSeed: poseSeed, fillFrame: true)
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
/// `WeeklyHighlightShareCard` / `LifetimeStatsShareCard` と同じ構成:
/// tracked バッジ + タイトル + 大きな猫キャラ (scaledToFit) + KPI + グラデ背景。
struct MonthlyReviewCard: View {
    let review: MonthlyReviewBuilder.Review
    var appName: String = "GO エクササイズ"
    /// 期間に応じて差し替える表示。デフォルトは月次。
    /// バッジは英字テキストを廃止し、タイトル(日本語)にこの SF Symbol アイコンを付けた
    /// ピルに統合する(英字「MONTHLY HIGHLIGHT」とタイトル「Monthlyハイライト」の重複解消)。
    /// アイコンは履歴エントリ行と同一対応 (Weekly=sparkles / Monthly=doc.text.image / All-time=trophy.fill)。
    var icon: String = "doc.text.image"
    var title: String = "Monthlyハイライト"
    var streakLabel: String = "今月の最長連続"
    var gradient: [Color] = MonthlyReviewSheet.monthlyGradient
    var poseSeed: Int = 0
    /// ImageRenderer でスマホ全画面比のキャンバス (ShareCardLayout.canvas = 600×1300) に書き出すとき true。フレーム全面をグラデで塗り、
    /// 上下の白余白を消す(ユーザー要望)。
    var fillFrame: Bool = false

    var body: some View {
        VStack(spacing: 18) {
            // 英字バッジ + 日本語タイトルの重複を解消: アイコン付きの日本語バッジ 1 つに統合。
            Label(title, systemImage: icon)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(.black.opacity(0.45), in: Capsule())

            Text(review.monthLabel)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))

            // 猫キャラ (今週/これまでと同じく circle clip なしの scaledToFit 大判)
            catImage
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.top, 4)

            // メイン KPI: 達成日数
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(review.achievedDays)")
                    .font(.system(size: 88, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                Text("/ \(review.totalDays) 日達成")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(spacing: 10) {
                statRow(icon: "pawprint.fill", label: streakLabel, value: "\(review.longestStreakInMonth) 日")
                statRow(icon: "clock.fill", label: "合計時間", value: "\(review.totalDurationMinutes) 分")
                statRow(icon: "list.bullet.rectangle", label: "種目数", value: "\(review.totalExerciseCount) 件")
                if let cat = review.topCategory {
                    statRow(icon: "star.fill", label: "イチオシのカテゴリ", value: cat.displayName)
                }
                if let ex = review.topExerciseName {
                    statRow(icon: "heart.fill", label: "推し種目", value: ex)
                }
            }
            .padding(16)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(appName)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .padding(.top, 10)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: fillFrame ? .infinity : nil)
        .background {
            let g = LinearGradient(
                colors: gradient,
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

    /// 選択中の猫キャラ (celebrating ポーズ。asset 欠落時は orange fallback、それも
    /// 無ければ emoji)。今週/これまでカードと同じ解決ロジック。
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

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 22)
            Text(label)
                .font(Typography.body)
                .foregroundStyle(.white.opacity(0.85))
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded, weight: .heavy))
                .foregroundStyle(.white)
        }
    }
}
