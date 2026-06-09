import Foundation
import Observation

/// 友達に共有する「今日の活動」と「月次集計」を記録から組み立てる純粋関数。
/// プライバシー: 種目ごとの詳細 (回数/セット/分) は `includeDetail == true` の時だけ含める。
/// カテゴリ名・種目名は常に共有 (プロフィール表示・友達カード用)。体重・体調は対象外。
enum FriendSharedActivity {
    struct Snapshot: Equatable {
        var todayCategoryName: String?
        var todayExerciseNames: [String]
        var todayExerciseDetails: [SharedExerciseDetail]?
        var monthlyTotalMinutes: Int
        var monthlyAchievedDays: Int
    }

    static func build(records: [WorkoutRecord], today: Date, calendar: Calendar,
                      includeDetail: Bool) -> Snapshot {
        let todays = records.filter { calendar.isDate($0.date, inSameDayAs: today) }

        // 今日使ったカテゴリ名 (重複なく「・」連結)。
        let uniqueCategories = todays.map { $0.category.displayName }
            .reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let categoryName = uniqueCategories.isEmpty ? nil : uniqueCategories.joined(separator: "・")

        // 今日の種目名 (空白除去・重複なく)。
        let items = todays.flatMap { $0.exercises }
        let names = items.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .reduce(into: [String]()) { if !$1.isEmpty, !$0.contains($1) { $0.append($1) } }

        // 種目詳細 (回数/セット/分) は opt-in のときだけ。
        let details: [SharedExerciseDetail]? = includeDetail
            ? items.compactMap { item in
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }
                let minutes = (item.durationSeconds ?? 0) / 60
                return SharedExerciseDetail(name: name,
                                            durationMinutes: minutes > 0 ? minutes : nil,
                                            reps: item.reps, sets: item.sets)
              }
            : nil

        // 今月の集計 (ランキング今月タブ用)。ネスト reduce は型推論が重いので明示ループ。
        let monthRecords = records.filter { calendar.isDate($0.date, equalTo: today, toGranularity: .month) }
        var monthlySeconds = 0
        for rec in monthRecords {
            for ex in rec.exercises { monthlySeconds += ex.durationSeconds ?? 0 }
        }
        let monthlyMinutes = monthlySeconds / 60
        let monthlyDays = Set(monthRecords.map { calendar.startOfDay(for: $0.date) }).count

        return Snapshot(todayCategoryName: categoryName,
                        todayExerciseNames: names,
                        todayExerciseDetails: details,
                        monthlyTotalMinutes: monthlyMinutes,
                        monthlyAchievedDays: monthlyDays)
    }
}

/// User-controlled privacy slider for what their own profile broadcasts to
/// friends. Default: minimal (category + names only).
@MainActor
@Observable
final class FriendSharingPreferences {
    static let detailKey = "friend.sharing.includeDetail"
    static let shared = FriendSharingPreferences()

    private let defaults: UserDefaults

    /// When true, the profile published to friends includes per-exercise
    /// duration / reps / sets in addition to category + name.
    var includeExerciseDetail: Bool {
        didSet { defaults.set(includeExerciseDetail, forKey: Self.detailKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default OFF — opt-in for the more revealing share.
        self.includeExerciseDetail = defaults.bool(forKey: Self.detailKey)
    }
}
