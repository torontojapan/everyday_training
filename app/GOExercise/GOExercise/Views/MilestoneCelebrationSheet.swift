import SwiftUI
import UIKit

struct MilestoneCelebrationSheet: View {
    let milestone: Milestone
    @Binding var isPresented: Bool
    var onAcknowledge: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var emojiScale: CGFloat = 0.2
    @State private var emojiRotation: Double = -25
    @State private var headlineAppear = false
    @State private var detailAppear = false
    @State private var ctaAppear = false
    private let hapticFeedback = HapticFeedbackController()

    private var celebrationLevel: CelebrationLevel {
        switch milestone {
        case .anniversary(let years):
            return years >= 2 ? .legendary : .heroic
        case .lifetimeDays(let d):
            if d >= 365 { return .legendary }
            if d >= 100 { return .heroic }
            return .standard
        case .currentStreak(let d):
            if d >= 365 { return .legendary }
            if d >= 30 { return .heroic }
            return .standard
        case .weightLoss(let kg):
            if kg >= 10 { return .legendary }
            if kg >= 5  { return .heroic }
            return .standard
        }
    }

    /// ミルストーンに合うキャラ表情。全節目で喜び満開の `celebrating` を使う。
    /// (連続記録は以前 炎入りの `streakExtended` だったが「火はださい」とユーザー指摘で廃止。2026-06-19)
    private var characterState: CatState {
        switch milestone {
        case .currentStreak, .anniversary, .lifetimeDays, .weightLoss: return .celebrating
        }
    }

    /// 表示する画像 asset 名 (選択中 breed × state)。
    /// 該当 asset が無ければ orange の同 state に fallback。
    /// 両方失敗した場合は nil → emoji にフォールバック表示する。
    private var characterAssetName: String? {
        let breed = UserCatPreferences.shared.myCat
        let primary = breed.assetName(for: characterState)
        if UIImage(named: primary) != nil { return primary }
        let fallback = CatBreed.fallbackAssetName(for: characterState)
        if UIImage(named: fallback) != nil { return fallback }
        return nil
    }

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.85, blue: 0.40),
                         Color(red: 1.00, green: 0.55, blue: 0.55),
                         Color(red: 0.85, green: 0.45, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            CelebrationOverlay(level: celebrationLevel)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 28) {
                    Spacer().frame(height: 80)
                    // ユーザーが選んだ猫キャラを大きく主役にする。
                    // emoji フォールバックは asset 欠落時のみ (PNG が見つからない)。
                    // 小さな milestone 種別 emoji は右上にバッジ的に重ねて装飾。
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let asset = characterAssetName {
                                Image(asset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 220, height: 220)
                            } else {
                                Text(milestone.fallbackEmoji)
                                    .font(.system(size: 112))
                            }
                        }
                        .shadow(color: .black.opacity(0.25), radius: 18, x: 0, y: 8)
                        // milestone 種別を金グラデの SF Symbol バッジで右上に重ねる
                        // (絵文字 🎉✨🔥 は廃止。メダル/トロフィー/王冠で上質に)。
                        Image(systemName: milestone.badgeSymbol)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.92, blue: 0.55),
                                             Color(red: 1.0, green: 0.74, blue: 0.24)],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                            .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)
                            .overlay(
                                Image(systemName: milestone.badgeSymbol)
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.25))
                                    .mask(LinearGradient(colors: [.white, .clear],
                                                         startPoint: .top, endPoint: .center))
                            )
                            .offset(x: 14, y: -10)
                            .accessibilityHidden(true)
                    }
                    .scaleEffect(emojiScale)
                    .rotationEffect(.degrees(emojiRotation))
                    ShimmerText(
                        text: milestone.headline,
                        font: .system(size: 34, weight: .heavy, design: .rounded)
                    )
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .opacity(headlineAppear ? 1 : 0)
                    .offset(y: headlineAppear ? 0 : 20)
                    Text(milestone.detail)
                        .font(Typography.body)
                        .foregroundStyle(.white.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .opacity(detailAppear ? 1 : 0)
                        .offset(y: detailAppear ? 0 : 12)

                    // CTA は SNS シェアを主役に。「受け取る」では「何が貰えるの?」
                    // が解消されないので、共有 → 仲間とつながる招待トーンに変更。
                    // 「自慢」は negative に取られるので採用せず、「運動仲間と
                    // つながろう」系で community-building 動線を強調。
                    VStack(spacing: 12) {
                        ShareLink(
                            item: AppSharingConfig.shareURL,
                            subject: Text(milestone.shareSubject),
                            message: Text(milestone.shareMessage)
                        ) {
                            Label("シェアして運動仲間とつながる", systemImage: "square.and.arrow.up.fill")
                                .font(Typography.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24).padding(.vertical, 14)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                        // シェアをタップした段階で「確認済」扱いにする (シート
                        // 自体はシステム share sheet が前面に出るため自然に閉じる
                        // 動線にならない → ユーザーは share 後に閉じるを押す)。
                        // 二重 acknowledge は idempotent (Set への insert) なので
                        // 後で「閉じる」を押しても問題ない。
                        .simultaneousGesture(TapGesture().onEnded {
                            onAcknowledge()
                        })
                        .accessibilityIdentifier("milestone-share-button")

                        Button {
                            onAcknowledge()
                            isPresented = false
                            dismiss()
                        } label: {
                            Text("閉じる")
                                .font(Typography.body)
                                .foregroundStyle(.white.opacity(0.9))
                                .padding(.horizontal, 16).padding(.vertical, 8)
                        }
                        .accessibilityIdentifier("milestone-close-button")
                    }
                    .padding(.top, 12)
                    .scaleEffect(ctaAppear ? 1 : 0.7)
                    .opacity(ctaAppear ? 1 : 0)
                    Spacer().frame(height: 60)
                }
                .padding(24)
            }

            HStack {
                Spacer()
                Button {
                    onAcknowledge()
                    isPresented = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.black.opacity(0.4), in: Circle())
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
                .accessibilityLabel("閉じる")
            }
        }
        .onAppear {
            CelebrationCenter.shared.fire(celebrationLevel)
            withAnimation(Motion.animation(.spring(response: 0.6, dampingFraction: 0.55), reduceMotion: reduceMotion)) {
                emojiScale = 1.0
                emojiRotation = 0
            }
            withAnimation(Motion.animation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.35), reduceMotion: reduceMotion)) {
                headlineAppear = true
            }
            withAnimation(Motion.animation(.easeOut(duration: 0.5).delay(0.7), reduceMotion: reduceMotion)) {
                detailAppear = true
            }
            withAnimation(Motion.animation(.spring(response: 0.4, dampingFraction: 0.5).delay(1.05), reduceMotion: reduceMotion)) {
                ctaAppear = true
            }
        }
    }
}
