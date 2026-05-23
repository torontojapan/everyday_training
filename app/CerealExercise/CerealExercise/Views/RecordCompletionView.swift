import SwiftUI

struct RecordCompletionView: View {
    @Environment(WorkoutStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let record: WorkoutRecord
    let streakExtendedThisRun: Bool

    @State private var contentVisible = false
    @State private var streakPulse = false
    @State private var showsConfetti = true
    @State private var fireBurst = false

    init(record: WorkoutRecord, streakExtendedThisRun: Bool = false) {
        self.record = record
        self.streakExtendedThisRun = streakExtendedThisRun
    }

    private var streak: Int {
        StreakCalculator.currentStreak(records: store.records, today: store.today)
    }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    CatMessageView(
                        message: CatMessageProvider.message(for: streakExtendedThisRun ? .streakExtended : .celebrating),
                        state: streakExtendedThisRun ? .streakExtended : .celebrating
                    )

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

                    StreakBadgeView(streak: streak)
                        .scaleEffect(streakPulse ? 1.18 : 1)

                    PrimaryButton("ホームへ戻る", systemImage: "house.fill") {
                        dismiss()
                    }
                }
                .padding(20)
            }

            if showsConfetti {
                ConfettiView()
                    .transition(.opacity)
            }

            if streakExtendedThisRun {
                fireOverlay
            }
        }
        .navigationTitle("記録完了")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            store.fetchRecords()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                contentVisible = true
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.45).repeatCount(2, autoreverses: true)) {
                streakPulse = true
            }
            withAnimation(Motion.bouncy.repeatCount(3, autoreverses: true)) {
                fireBurst = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.2)) {
                    showsConfetti = false
                }
            }
        }
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
