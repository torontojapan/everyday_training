import Foundation
import Observation
import SwiftData

/// 記録(運動・体重・体調・フリーズ救済日)のクラウドバックアップ/復元コーディネータ。
/// Duolingo 型: 本人アカウント(匿名+Apple/Google連携)に紐付け、OS 跨ぎの機種変更でも復元できる。
///
/// 設計:
/// - **オプトイン(既定 OFF)**。ON の間、起動時とバックグラウンド移行時に同期。
/// - push: `updatedAt > lastSyncAt` のレコード(+ 救済日は全件=少量)を upsert(冪等)。
/// - pull: 本人の全行を取得し、ローカルに無い id を挿入 / tombstone(deleted)はローカル削除 /
///   既存 id は updatedAt の新しい方を採用(LWW)。
/// - 削除伝播: 各 Store の削除時に `RecordSyncTombstones.note` でキューイングし、次回同期で
///   サーバへ論理削除を書く。「すべての記録を削除」は wipe フラグでサーバも物理全削除。
/// - 復元: サインイン復元(friendCode 変化)時に pull。リモートに行があれば自動で ON にして適用。
///
/// ★ payload のクロスOS契約(Android も同形式で読み書きする。変更時は両OS同時に):
///  - workout:   {"date": ISO8601, "category": rawValue, "exercises": [ExerciseItem JSON],
///                "memo": String?, "createdAt": ISO8601, "updatedAt": ISO8601}
///  - weight:    {"date": ISO8601, "kg": Double, "memo": String?, "createdAt": ISO8601, "updatedAt": ISO8601}
///  - menstrual: {"date": ISO8601, "createdAt": ISO8601}
///  - rescued_day: {"day": "yyyy-MM-dd"}   (record_id = "rescued-yyyy-MM-dd")
///  日付は ISO8601(秒精度・UTC)。day はローカル暦日文字列。
@MainActor
@Observable
final class RecordSyncCoordinator {
    nonisolated static let enabledKey = "recordBackup.enabled.v1"
    nonisolated static let lastSyncKey = "recordBackup.lastSyncAt.v1"

    private let service: any FriendsService
    private let defaults: UserDefaults
    private let rescueStore: RescueTicketStore
    private var modelContext: ModelContext?
    private let calendar: Calendar

    private(set) var isSyncing = false
    var lastError: String?
    private(set) var lastSyncAt: Date?

    var isEnabled: Bool {
        get { defaults.bool(forKey: Self.enabledKey) }
        set { defaults.set(newValue, forKey: Self.enabledKey) }
    }

    init(service: any FriendsService,
         defaults: UserDefaults = .standard,
         rescueStore: RescueTicketStore = .shared,
         calendar: Calendar = .mondayFirst) {
        self.service = service
        self.defaults = defaults
        self.rescueStore = rescueStore
        self.calendar = calendar
        if let t = defaults.object(forKey: Self.lastSyncKey) as? Double {
            lastSyncAt = Date(timeIntervalSince1970: t)
        }
    }

    /// App 起動後に共有 ModelContainer の context を渡す(@State 初期化時には参照できないため)。
    func attach(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// バックアップを ON にする。未サインインなら匿名アカウントを発行してから全量同期。
    func enableBackup() async {
        lastError = nil
        do {
            if service.myProfile == nil {
                try await service.signIn(displayName: "ねこの友", username: Self.generatedUsername())
            }
            isEnabled = true
            await syncNow()
        } catch {
            lastError = "バックアップを開始できませんでした: \(error.localizedDescription)"
        }
    }

    /// OFF: 同期を止めるだけ(クラウド上の既存バックアップは残す。全消去は「すべての記録を削除」)。
    func disableBackup() { isEnabled = false }

    /// サインイン復元(アカウント切替)直後に呼ぶ。リモートにバックアップがあれば
    /// 取り込み、自動で ON にする(機種変更フローを1タップ少なく)。
    func restoreAfterSignIn() async {
        guard service.myProfile != nil else { return }
        do {
            let rows = try await service.backupFetchAll()
            guard !rows.isEmpty else { return }
            try apply(remote: rows)
            isEnabled = true
            stampSynced()
        } catch {
            lastError = "バックアップの復元に失敗しました: \(error.localizedDescription)"
        }
    }

    /// 通常同期(起動時/バックグラウンド移行時/手動)。
    func syncNow() async {
        guard isEnabled, !isSyncing, service.myProfile != nil, modelContext != nil else { return }
        isSyncing = true
        defer { isSyncing = false }
        lastError = nil
        do {
            // 1) 削除キューを先に伝播(wipe は物理全削除)
            let pending = RecordSyncTombstones.drain(defaults: defaults)
            if pending.wipe {
                try await service.backupWipeAll()
            } else if !pending.ids.isEmpty {
                try await service.backupMarkDeleted(pending.ids)
            }
            // 2) push(lastSync 以降の変更 + 救済日全件)
            try await service.backupUpsert(changedRecords(since: lastSyncAt))
            // 3) pull → マージ適用
            try apply(remote: try await service.backupFetchAll())
            stampSynced()
        } catch {
            // 失敗した削除キューは再投入(次回再試行)
            lastError = "同期に失敗しました: \(error.localizedDescription)"
        }
    }

    // MARK: - push(エンコード)

    private func changedRecords(since: Date?) throws -> [BackupRecord] {
        guard let context = modelContext else { return [] }
        var out: [BackupRecord] = []
        let iso = Self.iso

        let workouts = try context.fetch(FetchDescriptor<WorkoutRecord>())
        for r in workouts where since == nil || r.updatedAt > since! {
            let exercisesJSON = (try? JSONSerialization.jsonObject(with: r.exercisesData)) ?? []
            var p: [String: Any] = [
                "date": iso.string(from: r.date), "category": r.categoryRaw,
                "exercises": exercisesJSON,
                "createdAt": iso.string(from: r.createdAt), "updatedAt": iso.string(from: r.updatedAt),
            ]
            if let m = r.memo { p["memo"] = m }
            out.append(BackupRecord(id: r.id.uuidString.lowercased(), kind: "workout",
                                    payloadJSON: try JSONSerialization.data(withJSONObject: p),
                                    updatedAt: r.updatedAt, deleted: false))
        }
        let weights = try context.fetch(FetchDescriptor<WeightEntry>())
        for w in weights where since == nil || w.updatedAt > since! {
            var p: [String: Any] = [
                "date": iso.string(from: w.date), "kg": w.weightKilograms,
                "createdAt": iso.string(from: w.createdAt), "updatedAt": iso.string(from: w.updatedAt),
            ]
            if let m = w.memo { p["memo"] = m }
            out.append(BackupRecord(id: w.id.uuidString.lowercased(), kind: "weight",
                                    payloadJSON: try JSONSerialization.data(withJSONObject: p),
                                    updatedAt: w.updatedAt, deleted: false))
        }
        let menstruals = try context.fetch(FetchDescriptor<MenstrualEntry>())
        for m in menstruals where since == nil || m.createdAt > since! {
            let p: [String: Any] = ["date": iso.string(from: m.date), "createdAt": iso.string(from: m.createdAt)]
            out.append(BackupRecord(id: m.id.uuidString.lowercased(), kind: "menstrual",
                                    payloadJSON: try JSONSerialization.data(withJSONObject: p),
                                    updatedAt: m.createdAt, deleted: false))
        }
        // 救済日は少量(月≤5)なので毎回全件 upsert(冪等・削除は wipe 以外で起きない)
        for day in rescueStore.rescuedDates() {
            let key = Self.dayKey(day, calendar: calendar)
            let p: [String: Any] = ["day": key]
            out.append(BackupRecord(id: "rescued-\(key)", kind: "rescued_day",
                                    payloadJSON: try JSONSerialization.data(withJSONObject: p),
                                    updatedAt: day, deleted: false))
        }
        return out
    }

    // MARK: - pull(デコード/マージ)

    private func apply(remote rows: [BackupRecord]) throws {
        guard let context = modelContext else { return }
        let iso = Self.iso

        let localWorkouts = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<WorkoutRecord>()).map { ($0.id.uuidString.lowercased(), $0) })
        let localWeights = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<WeightEntry>()).map { ($0.id.uuidString.lowercased(), $0) })
        let localMenstruals = Dictionary(uniqueKeysWithValues:
            try context.fetch(FetchDescriptor<MenstrualEntry>()).map { ($0.id.uuidString.lowercased(), $0) })

        var importedRescued: Set<Date> = []
        var changed = false

        for row in rows {
            switch row.kind {
            case "workout":
                if row.deleted {
                    if let local = localWorkouts[row.id] { context.delete(local); changed = true }
                    continue
                }
                guard let p = (try? JSONSerialization.jsonObject(with: row.payloadJSON)) as? [String: Any],
                      let dateS = p["date"] as? String, let date = iso.date(from: dateS),
                      let category = p["category"] as? String else { continue }
                let exercisesData = (p["exercises"]).flatMap { try? JSONSerialization.data(withJSONObject: $0) } ?? Data("[]".utf8)
                let createdAt = (p["createdAt"] as? String).flatMap(iso.date(from:)) ?? date
                let updatedAt = (p["updatedAt"] as? String).flatMap(iso.date(from:)) ?? date
                if let local = localWorkouts[row.id] {
                    // LWW: リモートの方が新しければ取り込む(別端末での編集を反映)
                    if updatedAt > local.updatedAt.addingTimeInterval(1) {
                        local.date = calendar.startOfDay(for: date)
                        local.categoryRaw = category
                        local.exercisesData = exercisesData
                        local.memo = p["memo"] as? String
                        local.updatedAt = updatedAt
                        changed = true
                    }
                } else if let uuid = UUID(uuidString: row.id) {
                    let record = WorkoutRecord(id: uuid, date: date,
                                               category: WorkoutCategory(rawValue: category) ?? .other,
                                               exercises: [], memo: p["memo"] as? String,
                                               calendar: calendar, createdAt: createdAt, updatedAt: updatedAt)
                    record.exercisesData = exercisesData
                    record.updatedAt = updatedAt   // exercisesData setter が now に上書きするため戻す
                    context.insert(record)
                    changed = true
                }
            case "weight":
                if row.deleted {
                    if let local = localWeights[row.id] { context.delete(local); changed = true }
                    continue
                }
                guard let p = (try? JSONSerialization.jsonObject(with: row.payloadJSON)) as? [String: Any],
                      let dateS = p["date"] as? String, let date = iso.date(from: dateS),
                      let kg = p["kg"] as? Double else { continue }
                let createdAt = (p["createdAt"] as? String).flatMap(iso.date(from:)) ?? date
                let updatedAt = (p["updatedAt"] as? String).flatMap(iso.date(from:)) ?? date
                if let local = localWeights[row.id] {
                    if updatedAt > local.updatedAt.addingTimeInterval(1) {
                        local.date = date
                        local.weightKilograms = kg
                        local.memo = p["memo"] as? String
                        local.updatedAt = updatedAt
                        changed = true
                    }
                } else if let uuid = UUID(uuidString: row.id) {
                    context.insert(WeightEntry(id: uuid, date: date, weightKilograms: kg,
                                               memo: p["memo"] as? String,
                                               createdAt: createdAt, updatedAt: updatedAt))
                    changed = true
                }
            case "menstrual":
                if row.deleted {
                    if let local = localMenstruals[row.id] { context.delete(local); changed = true }
                    continue
                }
                guard localMenstruals[row.id] == nil,
                      let p = (try? JSONSerialization.jsonObject(with: row.payloadJSON)) as? [String: Any],
                      let dateS = p["date"] as? String, let date = iso.date(from: dateS),
                      let uuid = UUID(uuidString: row.id) else { continue }
                let createdAt = (p["createdAt"] as? String).flatMap(iso.date(from:)) ?? date
                context.insert(MenstrualEntry(id: uuid, date: date, calendar: calendar, createdAt: createdAt))
                changed = true
            case "rescued_day":
                guard !row.deleted,
                      let p = (try? JSONSerialization.jsonObject(with: row.payloadJSON)) as? [String: Any],
                      let dayS = p["day"] as? String, let day = Self.date(fromDayKey: dayS, calendar: calendar)
                else { continue }
                importedRescued.insert(day)
            default:
                continue
            }
        }
        if changed { try context.save() }
        if !importedRescued.isEmpty { rescueStore.importRescuedDays(importedRescued) }
    }

    // MARK: - Helpers

    private func stampSynced() {
        let now = Date()
        lastSyncAt = now
        defaults.set(now.timeIntervalSince1970, forKey: Self.lastSyncKey)
    }

    private static let iso = ISO8601DateFormatter()

    private static func generatedUsername() -> String {
        "neko" + UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(6).lowercased()
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromDayKey key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var c = DateComponents(); c.year = parts[0]; c.month = parts[1]; c.day = parts[2]
        return calendar.date(from: c).map { calendar.startOfDay(for: $0) }
    }
}

/// 削除をサーバへ伝播するための軽量キュー(UserDefaults)。各 Store は依存を持たず
/// `note` するだけでよく、次回同期時に Coordinator が drain して論理削除を書く。
enum RecordSyncTombstones {
    static let idsKey = "recordBackup.pendingDeletions.v1"
    static let wipeKey = "recordBackup.pendingWipe.v1"

    static func note(_ recordID: String, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: RecordSyncCoordinator.enabledKey) else { return }
        var ids = (defaults.array(forKey: idsKey) as? [String]) ?? []
        guard !ids.contains(recordID) else { return }
        ids.append(recordID)
        defaults.set(ids, forKey: idsKey)
    }

    static func noteWipe(defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: RecordSyncCoordinator.enabledKey) else { return }
        defaults.set(true, forKey: wipeKey)
        defaults.removeObject(forKey: idsKey)
    }

    static func drain(defaults: UserDefaults = .standard) -> (ids: [String], wipe: Bool) {
        let ids = (defaults.array(forKey: idsKey) as? [String]) ?? []
        let wipe = defaults.bool(forKey: wipeKey)
        defaults.removeObject(forKey: idsKey)
        defaults.removeObject(forKey: wipeKey)
        return (ids, wipe)
    }
}
