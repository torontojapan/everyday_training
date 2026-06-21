import SwiftUI

struct StreakShareSheet: View {
    let streak: Int
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?
    @State private var renderedUIImage: UIImage?
    @State private var saveBannerText: String?
    /// 提示ごとに固定のポーズ seed(再レンダリングでブレない / シート開き直しで変わる)。
    @State private var poseSeed = Int.random(in: 0..<10_000)
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

                    StreakShareCard(streak: streak, appName: appName, gradientColors: gradient.colors, poseSeed: poseSeed)

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
        let card = StreakShareCard(streak: streak, appName: appName, gradientColors: gradient.colors, poseSeed: poseSeed, fillFrame: true)
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
    /// 提示ごとに固定のポーズ seed(0 = 既定の celebrating)。
    var poseSeed: Int = 0
    /// ImageRenderer でスマホ全画面比のキャンバス (ShareCardLayout.canvas = 600×1300) に書き出すとき true。フレーム全面をグラデで塗り、
    /// 角丸カードを中央に置くと上下に出る白余白を消す(ユーザー要望)。
    var fillFrame: Bool = false

    private var level: StreakLevel { StreakLevel(streak: streak) }
    /// 連続日数に対応する称号ランク(背景進化・ホームの称号バッジと同一)。
    private var rank: CatRank { CatRank(currentStreak: streak) }
    /// シェアカードの猫はハッピーポーズ3種(celebrating/happy2/happy3)からランダム表示。
    private var poseAsset: String {
        UserCatPreferences.shared.myPet.randomHappyPoseAsset(
            seed: poseSeed, exists: { UIImage(named: $0) != nil })
    }

    var body: some View {
        VStack(spacing: 18) {
            // 見出しは「称号バッジ」。期間表現(旧 "1週間つづいた!" 等)は 7〜13 日を
            // 一律「1週間」と表すなど不正確なため廃止。ホームと同じメタリックな称号バッジ
            // (rank のメタル色カプセル+肉球+称号)を大きく見せる(ユーザー要望 2026-06-13)。
            // ImageRenderer は静止画なので shimmer アニメは off。
            if rank.rank > 0 {
                RankBadge(rank: rank, animateShimmer: false)
                    .scaleEffect(1.2)
                    .frame(height: 36)
                    .padding(.top, 6)
            } else {
                Text("継続中！")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }

            // 猫キャラ (大きく。ハイライトカードと同じ扱い)。
            // 旧「炎を背負う猫」を廃し、celebrating 猫の背面に紙吹雪を散らして祝祭感を出す
            // (ユーザー要望 2026-06-13: 炎はダサい → 紙吹雪)。
            catImage
                .frame(width: 200, height: 200)
                .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
                .padding(.top, 4)
                .background(
                    StaticConfettiView(count: max(level.sparkleCount, 12))
                        .frame(width: 260, height: 230)
                        .allowsHitTesting(false)
                )

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

    @ViewBuilder
    private var catImage: some View {
        // ハイライトカードと同じ scaledToFit(被写体が全面に入っている asset 前提)。
        if UIImage(named: poseAsset) != nil {
            Image(poseAsset)
                .resizable()
                .scaledToFit()
        } else {
            Text(level.fallbackEmoji)
                .font(.system(size: 100))
        }
    }
}

/// 静的な紙吹雪(ImageRenderer で書き出すカード用。アニメ無し)。
/// 決定論的に配置・回転・配色するので、同じ count なら毎回同じ絵になる。
struct StaticConfettiView: View {
    let count: Int
    var colors: [Color] = [
        .white,
        Color(red: 1.00, green: 0.85, blue: 0.30),
        Color(red: 0.99, green: 0.55, blue: 0.45),
        Color(red: 0.55, green: 0.80, blue: 0.95),
        Color(red: 0.70, green: 0.55, blue: 0.95),
    ]

    private func h(_ v: Int) -> Double {
        var x = UInt64(bitPattern: Int64(v)) &* 0x9E37_79B9_7F4A_7C15
        x ^= x >> 33
        x &*= 0xC2B2_AE3D_27D4_EB4F
        x ^= x >> 29
        return Double(x % 100_000) / 100_000.0
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(0..<count, id: \.self) { i in
                let x = h(i * 3 + 1)
                let y = h(i * 3 + 2)
                let isCircle = (i % 4 == 0)
                Group {
                    if isCircle {
                        Circle().frame(width: 9, height: 9)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .frame(width: 9, height: 13)
                    }
                }
                .foregroundStyle(colors[i % colors.count])
                .rotationEffect(.degrees(h(i * 3) * 360))
                .position(x: x * geo.size.width, y: y * geo.size.height)
                .opacity(0.92)
            }
        }
    }
}
