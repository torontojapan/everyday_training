import Foundation

enum DefaultExerciseSuggestions {
    static func suggestions(for category: WorkoutCategory) -> [String] {
        switch category {
        case .strength:
            return [
                "スクワット",
                "腕立て伏せ",
                "プランク",
                "腹筋",
                "背筋",
                "バーピー",
                "ランジ",
                "ジャンピングジャック",
                "マウンテンクライマー",
                "ヒップリフト",
                "サイドプランク",
                "デッドバグ"
            ]
        case .cardio:
            return [
                "ウォーキング",
                "ジョギング",
                "ランニング",
                "サイクリング",
                "縄跳び",
                "階段昇降",
                "ダンス",
                "エアロビクス"
            ]
        case .yoga:
            return [
                "太陽礼拝",
                "ダウンドッグ",
                "コブラのポーズ",
                "戦士のポーズ",
                "子供のポーズ",
                "橋のポーズ",
                "三日月のポーズ",
                "猫のポーズ"
            ]
        case .stretch:
            return [
                "前屈ストレッチ",
                "開脚ストレッチ",
                "肩回し",
                "首回し",
                "ふくらはぎ伸ばし",
                "太もも前ストレッチ",
                "股関節ストレッチ",
                "背中ストレッチ"
            ]
        case .other:
            return []
        }
    }

    static func merged(history: [String], category: WorkoutCategory, limit: Int = 12) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        for name in history {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !seen.contains(trimmed) else { continue }
            result.append(trimmed)
            seen.insert(trimmed)
            if result.count >= limit { return result }
        }
        for name in suggestions(for: category) {
            guard !seen.contains(name) else { continue }
            result.append(name)
            seen.insert(name)
            if result.count >= limit { return result }
        }
        return result
    }
}
