import ActivityKit
import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Phase 7.0 Step 3: アプリを開かずに「今日の運動を 1 タップで記録」する
/// AppIntent。ウィジェットボタンや Siri ショートカットから呼ばれる。
///
/// 記録される内容はミニマム: 種目名「クイック記録」、カテゴリは「その他」、
/// 時間/回数なし。ユーザーは「やった」事実だけを残す目的。詳細を追加した
/// ければアプリを開いて記録すれば良い。
struct QuickRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "今日の運動を記録"
    static let description = IntentDescription("アプリを開かずに、今日の運動を 1 タップで記録します。")

    /// このフラグがあるとウィジェットがアクションを実行している間、
    /// ウィジェット側で processing を表示する。
    static let openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        // メインアプリと同じ App Group 共有ストアを開く (監査 B-Critical-1)。
        // これでクイック記録がメインアプリの連続記録 / 履歴に反映される。
        let container = AppModelContainer.make()
        let context = ModelContext(container)

        let now = Date()
        let calendar = Calendar.mondayFirst
        let today = calendar.startOfDay(for: now)

        // 同じ日にすでに記録がある場合は重複登録しない。
        // Widget 拡張はメモリ上限が厳しいため、全件フェッチ(O(n))を避け **当日範囲**に限定する
        // (GPT-5.5/Claude 監査: 長期ユーザーで全 WorkoutRecord を読むと jetsam リスク)。
        // exercisesData(Data)の空判定は SQL 述語に載せず、当日の少数行を取得後にメモリで判定。
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let todayDescriptor = FetchDescriptor<WorkoutRecord>(
            predicate: #Predicate { $0.date >= today && $0.date < dayEnd }
        )
        if let todays = try? context.fetch(todayDescriptor),
           todays.contains(where: { $0.exercisesData.isEmpty == false }) {
            // 既に記録ありの日。store は触らないが、snapshot が古い (前日のまま等) と
            // ウィジェットが「未達成」表示のままになり得るので達成表示に揃える。
            Self.markSnapshotAchieved(now: now, calendar: calendar)
            WidgetCenter.shared.reloadAllTimelines()
            await Self.markLiveActivityAchieved()
            return .result()
        }

        let item = ExerciseItem(
            id: UUID(),
            name: "クイック記録",
            durationSeconds: 60,
            reps: nil, sets: nil, memo: nil
        )
        let record = WorkoutRecord(
            date: today,
            category: .other,
            exercises: [item],
            memo: nil,
            calendar: calendar
        )
        context.insert(record)
        try context.save()

        // ウィジェット表示は SharedSnapshotStore (App Group UserDefaults) を読むため、
        // 記録直後に snapshot の「今日達成」フラグも更新しないと見た目が変わらない
        // (監査 B-Critical-1)。正確な再計算は次回 app 起動時に行われるので、ここでは
        // 達成フラグ + 連続/週次の +1 を反映する近似更新に留める。
        Self.markSnapshotAchieved(now: now, calendar: calendar)
        WidgetCenter.shared.reloadAllTimelines()
        await Self.markLiveActivityAchieved()
        return .result()
    }

    /// SharedSnapshotStore の今日分を「達成済み」に近似更新する。
    /// service 群 (StreakCalculator 等) は widget target に無いため厳密再計算は
    /// せず、既存 snapshot を読んで達成フラグ + カウント +1 + celebrating 表情に差し替える。
    private static func markSnapshotAchieved(now: Date, calendar: Calendar) {
        let store = SharedSnapshotStore()
        let current = store.read()
        // snapshot が「今日」生成で既に達成済みのときだけ skip (二重カウント防止)。
        // 前日以前の古い snapshot の todayAchieved=true は信用しない (Codex 指摘の
        // date-blind 回避)。古い場合は streak/週次を据え置きで達成フラグだけ立てる。
        let snapshotIsToday = calendar.isDate(current.generatedAt, inSameDayAs: now)
        if snapshotIsToday && current.todayAchieved { return }
        // 今日の snapshot からの遷移なら +1、古い snapshot なら据え置き (厳密値は
        // 次回 app 起動時に WidgetSnapshotPublisher が再計算する近似更新)。
        let streak = snapshotIsToday ? current.currentStreak + 1 : current.currentStreak
        let weekly = snapshotIsToday ? min(current.weeklyAchieved + 1, current.weeklyTotal) : current.weeklyAchieved
        let updated = WidgetSnapshot.make(
            generatedAt: now,
            todayAchieved: true,
            isRestDay: false,
            currentStreak: streak,
            weeklyAchieved: weekly,
            weeklyTotal: current.weeklyTotal,
            catState: .celebrating,
            message: "今日もえらい！記録できたね",
            calendar: calendar
        )
        _ = store.write(updated)
    }

    /// Live Activity 上のボタンから記録した直後に「達成済」の見た目に切り替える。
    /// streak / hoursLeft は次回 app open 時に正しく recompute されるので、
    /// ここではフラグだけ立てる軽量更新。
    private static func markLiveActivityAchieved() async {
        for activity in Activity<CatActivityAttributes>.activities {
            var next = activity.content.state
            next.todayAchieved = true
            await activity.update(.init(state: next, staleDate: activity.content.staleDate))
        }
    }
}
