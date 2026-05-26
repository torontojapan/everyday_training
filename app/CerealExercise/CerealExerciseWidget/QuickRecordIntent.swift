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
        // App Group 共有 SQLite store を直接更新。WidgetKit / メインアプリ
        // どちらからもアクセスできるよう ModelConfiguration の URL を
        // App Group container に置く。
        let container = try ModelContainer(
            for: WorkoutRecord.self,
            configurations: ModelConfiguration(
                url: Self.sharedStoreURL,
                cloudKitDatabase: .none
            )
        )
        let context = ModelContext(container)

        let now = Date()
        let calendar = Calendar.mondayFirst
        let today = calendar.startOfDay(for: now)

        // 同じ日にすでに「クイック記録」がある場合は重複登録しない。
        let descriptor = FetchDescriptor<WorkoutRecord>()
        if let all = try? context.fetch(descriptor),
           all.contains(where: {
               calendar.isDate($0.date, inSameDayAs: today)
               && $0.exercisesData.isEmpty == false
           }) {
            // 既に記録ありの日は何もしない (idempotent)。
            WidgetCenter.shared.reloadAllTimelines()
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

        // Widget timeline を即時更新して「達成済み」表示に切り替える。
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }

    /// メインアプリ / ウィジェットが共有する SwiftData ファイル URL。
    /// App Group `group.com.serial.cerealexercise` 配下に置く必要あり。
    static var sharedStoreURL: URL {
        let fm = FileManager.default
        let groupURL = fm.containerURL(
            forSecurityApplicationGroupIdentifier: "group.com.serial.cerealexercise"
        ) ?? URL.documentsDirectory
        return groupURL.appendingPathComponent("WorkoutStore.sqlite")
    }
}
