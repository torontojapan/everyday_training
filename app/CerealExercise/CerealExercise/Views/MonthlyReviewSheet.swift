import SwiftUI

struct MonthlyReviewSheet: View {
    let review: MonthlyReviewBuilder.Review
    @Environment(\.dismiss) private var dismiss
    @State private var renderedImage: Image?

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Palette.primary.opacity(0.8), Palette.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 56)
                    reviewCard
                    if let renderedImage {
                        ShareLink(item: renderedImage,
                                  preview: SharePreview("\(review.monthLabel) の運動レビュー", image: renderedImage)) {
                            Label("SNSで共有", systemImage: "square.and.arrow.up")
                                .font(Typography.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 14)
                                .background(.black.opacity(0.45), in: Capsule())
                        }
                    } else {
                        ProgressView().tint(.white).padding(.vertical, 16)
                    }
                    Spacer().frame(height: 40)
                }
                .padding(20)
            }

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
                }
                .accessibilityLabel("閉じる")
                .padding(.top, 12)
                .padding(.trailing, 16)
            }
        }
        .task { renderImage() }
    }

    private var reviewCard: some View {
        MonthlyReviewCard(review: review)
    }

    @MainActor
    private func renderImage() {
        let renderer = ImageRenderer(content: MonthlyReviewCard(review: review).frame(width: 600, height: 800))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
    }
}

struct MonthlyReviewCard: View {
    let review: MonthlyReviewBuilder.Review

    var body: some View {
        VStack(spacing: 18) {
            Text("今月のあなた")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(review.monthLabel)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(review.achievedDays)")
                    .font(.system(size: 80, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("/ \(review.totalDays) 日達成")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
            }

            VStack(spacing: 10) {
                statRow(icon: "flame.fill", label: "今月の最長連続", value: "\(review.longestStreakInMonth) 日")
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

            Text("GOエクササイズ")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Palette.primary, Palette.primaryDeep],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
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
