import Foundation

struct Achievement: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let description: String
    let symbol: String           // SF Symbol
    let isUnlocked: Bool
    let progress: Double         // 0...1
    let progressLabel: String?   // e.g. "12/30"
}

@MainActor
enum AchievementCatalog {
    static func evaluate(
        records: [WorkoutRecord],
        streak: StreakState,
        lifetime: LifetimeStatsCalculator.Stats,
        calendar: Calendar = .mondayFirst
    ) -> [Achievement] {
        let totalAchievedDays = lifetime.achievedDays
        let allExercises = records.flatMap(\.exercises)
        let categoryCounts: [WorkoutCategory: Int] = records.reduce(into: [:]) { partial, record in
            partial[record.category, default: 0] += 1
        }
        let exerciseNameCounts: [String: Int] = allExercises.reduce(into: [:]) { partial, item in
            let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return }
            partial[name, default: 0] += 1
        }

        func milestone(id: String, title: String, description: String, symbol: String, value: Int, target: Int) -> Achievement {
            let unlocked = value >= target
            let progress = min(1.0, Double(value) / Double(target))
            return Achievement(
                id: id,
                title: title,
                description: description,
                symbol: symbol,
                isUnlocked: unlocked,
                progress: progress,
                progressLabel: "\(min(value, target))/\(target)"
            )
        }

        var list: [Achievement] = []

        // First record.
        list.append(Achievement(
            id: "first.record",
            title: "はじめての記録",
            description: "1件目の運動を記録した",
            symbol: "sparkles",
            isUnlocked: !records.isEmpty,
            progress: records.isEmpty ? 0 : 1,
            progressLabel: nil
        ))

        // Streak milestones.
        list.append(milestone(id: "streak.3", title: "3日連続", description: "達成日3日連続", symbol: "flame.fill", value: streak.currentStreak, target: 3))
        list.append(milestone(id: "streak.7", title: "1週間連続", description: "達成日7日連続", symbol: "flame.fill", value: streak.currentStreak, target: 7))
        list.append(milestone(id: "streak.30", title: "1ヶ月連続", description: "達成日30日連続", symbol: "flame.fill", value: max(streak.currentStreak, streak.longestStreak), target: 30))
        list.append(milestone(id: "streak.100", title: "100日連続", description: "達成日100日連続", symbol: "flame.fill", value: max(streak.currentStreak, streak.longestStreak), target: 100))

        // Lifetime totals.
        list.append(milestone(id: "lifetime.10", title: "累計10日達成", description: "通算 10 日運動した", symbol: "calendar", value: totalAchievedDays, target: 10))
        list.append(milestone(id: "lifetime.50", title: "累計50日達成", description: "通算 50 日運動した", symbol: "calendar", value: totalAchievedDays, target: 50))
        list.append(milestone(id: "lifetime.100", title: "累計100日達成", description: "通算 100 日運動した", symbol: "calendar.badge.checkmark", value: totalAchievedDays, target: 100))
        list.append(milestone(id: "lifetime.365", title: "累計1年達成", description: "通算 365 日運動した", symbol: "calendar.circle.fill", value: totalAchievedDays, target: 365))

        // Category-specific.
        list.append(milestone(id: "cat.strength.10", title: "筋トレ10回", description: "筋トレを10回記録", symbol: "dumbbell.fill", value: categoryCounts[.strength] ?? 0, target: 10))
        list.append(milestone(id: "cat.yoga.10", title: "ヨガ10回", description: "ヨガを10回記録", symbol: "figure.mind.and.body", value: categoryCounts[.yoga] ?? 0, target: 10))
        list.append(milestone(id: "cat.cardio.10", title: "有酸素10回", description: "有酸素を10回記録", symbol: "figure.run", value: categoryCounts[.cardio] ?? 0, target: 10))
        list.append(milestone(id: "cat.stretch.10", title: "ストレッチ10回", description: "ストレッチを10回記録", symbol: "figure.flexibility", value: categoryCounts[.stretch] ?? 0, target: 10))

        // Variety.
        let categoriesUsed = Set(records.map(\.category)).count
        list.append(milestone(id: "variety.all", title: "全カテゴリ制覇", description: "5カテゴリ全てを記録", symbol: "star.fill", value: categoriesUsed, target: 5))

        // Favorite exercise repetition.
        let topRep = exerciseNameCounts.values.max() ?? 0
        list.append(milestone(id: "favorite.20", title: "推し種目20回", description: "同じ種目を20回記録", symbol: "heart.fill", value: topRep, target: 20))

        return list
    }

    static func newlyUnlocked(previous: [Achievement], current: [Achievement]) -> [Achievement] {
        let prevUnlockedIds = Set(previous.filter(\.isUnlocked).map(\.id))
        return current.filter { $0.isUnlocked && !prevUnlockedIds.contains($0.id) }
    }
}
