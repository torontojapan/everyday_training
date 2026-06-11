import Foundation
import SwiftData

extension Notification.Name {
    /// 全記録を削除した直後に投げる。保持され続けるストア (WorkoutStore /
    /// WeightStore / MenstrualStore) が削除済みオブジェクトを掴んだままにならない
    /// よう、各ストアがこれを購読して再フェッチする。
    static let goDataDidReset = Notification.Name("com.goexercise.app.dataDidReset")
}

/// ユーザーが自分で記録したデータを「書き出す」「全削除する」ための導線。
///
/// 対象は **ユーザーが記録した内容** (運動記録 / 体重 / 体調) のみ。
/// 購入・サブスクリプション状態 (Apple ID 紐付きで復元可能) や、無料体験の
/// 開始日などの課金関連状態は **意図的に対象外**。これらを削除でリセットすると
/// 無料体験の再取得などの不正経路になりうるため (信頼性向上が目的であって
/// アカウント破棄ではない)。
@MainActor
struct DataManagementService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Export

    /// 全記録を Codable スナップショットにまとめる。
    func makeExport(now: Date = Date()) throws -> DataExport {
        let workouts = try context.fetch(
            FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.date)])
        )
        let weights = try context.fetch(
            FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)])
        )
        let menstrual = try context.fetch(
            FetchDescriptor<MenstrualEntry>(sortBy: [SortDescriptor(\.date)])
        )
        return DataExport(
            exportedAt: now,
            workouts: workouts.map(DataExport.Workout.init),
            weights: weights.map(DataExport.Weight.init),
            menstrualDays: menstrual.map(DataExport.MenstrualDay.init)
        )
    }

    /// 書き出し用の整形済み JSON データ。
    func exportJSONData(now: Date = Date()) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(makeExport(now: now))
    }

    /// 一時ディレクトリに JSON を書き出し、共有シート用の file URL を返す。
    /// ファイル名は秒精度 + 短い乱数で一意化し、短時間の連続書き出しでも
    /// 既存ファイルを上書きしない (Codex 指摘)。
    func writeExportFile(now: Date = Date()) throws -> URL {
        let data = try exportJSONData(now: now)
        let stamp = Self.fileStampFormatter.string(from: now)
        let suffix = UUID().uuidString.prefix(8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("GO エクササイズ-データ-\(stamp)-\(suffix).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Delete

    /// 運動 / 体重 / 体調の全記録を削除し、削除件数を返す。
    @discardableResult
    func deleteAllRecords() throws -> Int {
        let workouts = try context.fetch(FetchDescriptor<WorkoutRecord>())
        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        let menstrual = try context.fetch(FetchDescriptor<MenstrualEntry>())
        let total = workouts.count + weights.count + menstrual.count
        workouts.forEach(context.delete)
        weights.forEach(context.delete)
        menstrual.forEach(context.delete)
        try context.save()
        // クラウドバックアップ有効時はサーバ側も全削除(次回同期で物理 delete)。
        RecordSyncTombstones.noteWipe()
        return total
    }

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

/// 書き出し JSON のスキーマ。`schemaVersion` で将来のフォーマット変更に追従できる。
struct DataExport: Codable, Equatable {
    var schemaVersion: Int
    var appVersion: String
    var exportedAt: Date
    var workouts: [Workout]
    var weights: [Weight]
    var menstrualDays: [MenstrualDay]

    init(
        schemaVersion: Int = 1,
        appVersion: String = DataExport.currentAppVersion,
        exportedAt: Date,
        workouts: [Workout],
        weights: [Weight],
        menstrualDays: [MenstrualDay]
    ) {
        self.schemaVersion = schemaVersion
        self.appVersion = appVersion
        self.exportedAt = exportedAt
        self.workouts = workouts
        self.weights = weights
        self.menstrualDays = menstrualDays
    }

    static var currentAppVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    struct Workout: Codable, Equatable {
        var id: UUID
        var date: Date
        var category: String
        var exercises: [ExerciseItem]
        var memo: String?
        var createdAt: Date
        var updatedAt: Date

        init(_ record: WorkoutRecord) {
            id = record.id
            date = record.date
            category = record.categoryRaw
            exercises = record.exercises
            memo = record.memo
            createdAt = record.createdAt
            updatedAt = record.updatedAt
        }
    }

    struct Weight: Codable, Equatable {
        var id: UUID
        var date: Date
        var weightKilograms: Double
        var memo: String?
        var createdAt: Date
        var updatedAt: Date

        init(_ entry: WeightEntry) {
            id = entry.id
            date = entry.date
            weightKilograms = entry.weightKilograms
            memo = entry.memo
            createdAt = entry.createdAt
            updatedAt = entry.updatedAt
        }
    }

    struct MenstrualDay: Codable, Equatable {
        var id: UUID
        var date: Date
        var createdAt: Date

        init(_ entry: MenstrualEntry) {
            id = entry.id
            date = entry.date
            createdAt = entry.createdAt
        }
    }
}
