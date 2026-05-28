import StoreKit
import SwiftUI

struct RecordCompletionView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    private let reviewController = ReviewRequestController()
    let record: WorkoutRecord
    let streakExtendedThisRun: Bool
    let onRecordAnother: (() -> Void)?

    @State private var contentVisible = false
    @State private var streakPulse = false
    @State private var showsConfetti = true
    @State private var fireBurst = false
    @State private var ribbonText = ""
    @State private var ribbonAppear = false
    @State private var catHaloScale: CGFloat = 0.4
    @State private var catHaloOpacity: Double = 0
    private let hapticFeedback = HapticFeedbackController()

    private static let praiseRibbons = [
        "お見事！", "ナイス継続！", "今日もえらい！", "素晴らしい！", "やったね！", "完璧！", "天才！", "コツコツ最強！"
    ]

    private var celebrationLevel: CelebrationLevel {
        let level = StreakLevel(streak: streak)
        switch level {
        case .zero, .sprout: return .subtle
        case .week, .twoWeeks: return .standard
        case .month, .century: return .heroic
        case .legend: return .legendary
        }
    }

    init(
        record: WorkoutRecord,
        streakExtendedThisRun: Bool = false,
        onRecordAnother: (() -> Void)? = nil
    ) {
        self.record = record
        self.streakExtendedThisRun = streakExtendedThisRun
        self.onRecordAnother = onRecordAnother
    }

    private var streak: Int {
        // 保険チケット救済日も連続に含める。これが無いと記録完了直後の
        // 連続バッジが履歴/ホームと食い違う (3 LLM 監査 A-Major)。
        StreakCalculator.currentStreak(
            records: store.records,
            today: store.today,
            rescuedDates: RescueTicketStore.shared.rescuedDates()
        )
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Palette.primary.opacity(0.55), Palette.primary.opacity(0.0)],
                                    center: .center, startRadius: 0, endRadius: 180
                                )
                            )
                            .frame(width: 320, height: 320)
                            .scaleEffect(catHaloScale)
                            .opacity(catHaloOpacity)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)

                        CatMessageView(
                            message: CatMessageProvider.message(for: streakExtendedThisRun ? .streakExtended : .celebrating),
                            state: streakExtendedThisRun ? .streakExtended : .celebrating
                        )
                    }

                    if ribbonAppear && !ribbonText.isEmpty {
                        Text(ribbonText)
                            .font(.system(.title2, design: .rounded, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.00, green: 0.55, blue: 0.35),
                                                 Color(red: 0.95, green: 0.32, blue: 0.60)],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                            )
                            .shadow(color: Color(red: 0.95, green: 0.32, blue: 0.60).opacity(0.4), radius: 16, x: 0, y: 6)
                            .transition(.scale(scale: 0.4).combined(with: .opacity))
                            .accessibilityIdentifier("praise-ribbon")
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日の記録")
                            .font(Typography.headline)
                            .foregroundStyle(Palette.textPrimary)

                        Label(record.category.displayName, systemImage: record.category.symbolName)
                            .font(Typography.body)
                            .foregroundStyle(Palette.textSecondary)

                        ForEach(record.exercises) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(Typography.headline)
                                Text(summary(for: item))
                                    .font(Typography.caption)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .scaleEffect(contentVisible ? 1 : 0.92)
                    .opacity(contentVisible ? 1 : 0)

                    ZStack {
                        // Backdrop glow
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(red: 1.00, green: 0.55, blue: 0.30).opacity(streakPulse ? 0.45 : 0.18), .clear],
                                    center: .center, startRadius: 0, endRadius: 200
                                )
                            )
                            .frame(width: 360, height: 220)
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)

                        StreakBadgeView(streak: streak)
                            .scaleEffect(streakPulse ? 1.20 : 1)
                            .shadow(color: Palette.primary.opacity(streakPulse ? 0.55 : 0.20), radius: streakPulse ? 22 : 8, x: 0, y: 4)
                    }

                    if let onRecordAnother {
                        Button {
                            onRecordAnother()
                        } label: {
                            Label("もう一種目を記録する", systemImage: "plus.circle")
                                .font(Typography.headline)
                                .foregroundStyle(Palette.primaryDeep)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .strokeBorder(Palette.primary.opacity(0.5), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("record-another-button")
                    }

                    PrimaryButton("ホームへ戻る", systemImage: "house.fill") {
                        dismiss()
                    }
                }
                .padding(20)
            }

            if showsConfetti && !reduceMotion {
                CelebrationOverlay(level: celebrationLevel)
                    .transition(.opacity)
            }

            if streakExtendedThisRun && !reduceMotion {
                fireOverlay
            }
        }
        .navigationTitle("記録完了")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.fetchRecords()
            triggerHaptic()
            ribbonText = Self.praiseRibbons.randomElement() ?? "お見事！"
            withAnimation(Motion.animation(.spring(response: 0.45, dampingFraction: 0.72), reduceMotion: reduceMotion)) {
                contentVisible = true
            }
            withAnimation(.easeOut(duration: 0.5)) {
                catHaloScale = 1.0
                catHaloOpacity = 1.0
            }
            withAnimation(Motion.animation(.spring(response: 0.55, dampingFraction: 0.5).delay(0.18), reduceMotion: reduceMotion)) {
                ribbonAppear = true
            }
            withAnimation(Motion.animation(.spring(response: 0.35, dampingFraction: 0.45).repeatCount(2, autoreverses: true), reduceMotion: reduceMotion)) {
                streakPulse = true
            }
            withAnimation(Motion.animation(Motion.bouncy.repeatCount(3, autoreverses: true), reduceMotion: reduceMotion)) {
                fireBurst = true
            }
        }
        // 遅延処理は `.task` に置き、画面離脱で自動キャンセルする。これにより
        // 「もう一種目」やホーム遷移で素早く離脱したとき、別画面で confetti 消去や
        // requestReview が発火するのを防ぐ (Codex 指摘: unstructured Task の取り残し)。
        .task {
            do {
                try await Task.sleep(for: .seconds(2.6))
            } catch {
                return  // 離脱でキャンセル → 演出もレビュー依頼も出さない
            }
            withAnimation(.easeOut(duration: 0.3)) {
                showsConfetti = false
                catHaloOpacity = 0.0
            }
            requestReviewIfMilestoneReached()
        }
    }

    /// 連続記録が節目に達した「成功体験の直後」にだけレビュー依頼を出す。
    /// 祝祭演出が一段落してから出すため、confetti のフェード後に呼ぶ。
    private func requestReviewIfMilestoneReached() {
        guard !ProcessInfo.processInfo.arguments.contains("--no-review-prompt") else { return }
        let streakToday = streak
        guard reviewController.shouldRequestReview(streak: streakToday) else { return }
        reviewController.markRequested(streak: streakToday)
        requestReview()
    }

    private func triggerHaptic() {
        CelebrationCenter.shared.fire(celebrationLevel)
    }

    private var fireOverlay: some View {
        ZStack {
            ForEach(0..<10, id: \.self) { index in
                Text("🔥")
                    .font(.system(size: index.isMultiple(of: 2) ? 28 : 22))
                    .offset(
                        x: fireBurst ? CGFloat((index % 5) - 2) * 42 : 0,
                        y: fireBurst ? CGFloat(index / 5 == 0 ? -1 : 1) * 120 : 20
                    )
                    .opacity(fireBurst ? 0.1 : 0.9)
                    .scaleEffect(fireBurst ? 1.25 : 0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func summary(for item: ExerciseItem) -> String {
        var parts: [String] = []
        if let duration = item.durationSeconds {
            let minutes = duration / 60
            let seconds = duration % 60
            parts.append(minutes > 0 ? "\(minutes)分\(seconds)秒" : "\(seconds)秒")
        }
        if let reps = item.reps {
            parts.append("\(reps)回")
        }
        if let sets = item.sets {
            parts.append("\(sets)セット")
        }
        if let memo = item.memo {
            parts.append(memo)
        }
        return parts.isEmpty ? "詳細なし" : parts.joined(separator: " / ")
    }
}
