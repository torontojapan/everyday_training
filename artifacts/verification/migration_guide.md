# SwiftData Schema Migration ガイド

将来 `WorkoutRecord` などのモデルに新フィールドを追加するとき、ユーザーの端末内データを失わずに移行するためのガイド。

## 現状

- 本体プロダクションコードは **V1 (Schema.Version(1, 0, 0))** 相当
- `WorkoutRecord` を直接定義 (VersionedSchema 化はしていない)
- migration plan は使っていない (初期スキーマのみ)

## なぜ Migration が必要か

SwiftData は同じ ModelContainer の **store URL** に過去のスキーマで書かれた `.store` ファイルが存在するとき、新スキーマでの読み出しに失敗してアプリ起動がクラッシュします。リリース後に `WorkoutRecord` の構造を変えるときは MigrationPlan が必須です。

## 推奨対応のタイミング

| 変更内容 | 対応 |
|---|---|
| 新フィールド追加 (Optional 型) | **Lightweight migration** で OK |
| 新フィールド追加 (Non-Optional 型) | Lightweight + デフォルト値、または Custom migration |
| フィールド削除 | Lightweight (削除される) |
| フィールド名変更 | Custom migration (旧 → 新へ値コピー) |
| 型変更 (Int → String 等) | Custom migration 必須 |
| Entity 名変更 | Custom migration 必須 |

## 実装テンプレート

### 1. 既存 WorkoutRecord を V1 として VersionedSchema 化

```swift
// app/CerealExercise/CerealExercise/Models/WorkoutRecordSchemaV1.swift
import SwiftData

enum WorkoutSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [WorkoutRecord.self] }
}
```

### 2. 新フィールドを持つ V2 を定義

```swift
// app/CerealExercise/CerealExercise/Models/WorkoutRecordSchemaV2.swift
import SwiftData

enum WorkoutSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [WorkoutRecord.self] }
}

extension WorkoutRecord {
    // 例: 強度 (1-10) の Optional 追加
    var intensity: Int? {
        get { _intensity ?? nil }
        set { _intensity = newValue }
    }
}

// 新フィールドは @Model クラスに直接追加 (Optional)
// @Model
// final class WorkoutRecord {
//   ... (既存)
//   var intensity: Int?   // ← NEW
// }
```

### 3. MigrationPlan

```swift
// app/CerealExercise/CerealExercise/Services/WorkoutMigrationPlan.swift
import SwiftData

enum WorkoutMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WorkoutSchemaV1.self, WorkoutSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: WorkoutSchemaV1.self, toVersion: WorkoutSchemaV2.self)]
    }
}
```

### 4. ModelContainer 構築時に Plan を渡す

```swift
// app/CerealExercise/CerealExercise/App/CerealExerciseApp.swift
.modelContainer(
    for: WorkoutRecord.self,
    migrationPlan: WorkoutMigrationPlan.self
)
```

### 5. テスト追加 (テンプレート)

`CerealExerciseTests/SwiftDataMigrationTests.swift` を参考に:

```swift
func testV1ToV2PreservesWorkoutRecords() throws {
    let storeURL = uniqueStoreURL()
    do {
        let v1 = try ModelContainer(for: WorkoutRecord.self, ...) // V1 schema
        let ctx = ModelContext(v1)
        ctx.insert(WorkoutRecord(date: Date(), category: .strength, exercises: [...]))
        try ctx.save()
    }
    let v2 = try ModelContainer(
        for: WorkoutRecord.self,
        migrationPlan: WorkoutMigrationPlan.self,
        configurations: ModelConfiguration(url: storeURL)
    )
    let records = try ModelContext(v2).fetch(FetchDescriptor<WorkoutRecord>())
    XCTAssertEqual(records.count, 1)
    XCTAssertNil(records[0].intensity)   // 新フィールドはデフォルト nil
}
```

## Custom Migration (フィールド名変更等)

Lightweight では足りない場合、`MigrationStage.custom` を使う:

```swift
static var stages: [MigrationStage] {
    [
        .custom(
            fromVersion: WorkoutSchemaV1.self,
            toVersion: WorkoutSchemaV2.self,
            willMigrate: { context in
                // 旧形式から新形式へデータコピー
                let v1Records = try context.fetch(FetchDescriptor<V1Record>())
                for old in v1Records {
                    let new = V2Record(...)
                    context.insert(new)
                    context.delete(old)
                }
                try context.save()
            },
            didMigrate: nil
        )
    ]
}
```

## チェックリスト (新フィールド追加時)

- [ ] 既存 V (V1, V2, ...) を VersionedSchema として保存
- [ ] 新フィールドを追加した V(N+1) を定義
- [ ] WorkoutMigrationPlan に新 stage を追加
- [ ] modelContainer 呼び出しに migrationPlan を渡す
- [ ] Migration テストを追加 (V(N) → V(N+1) で既存データが残ること)
- [ ] 既存ユニットテスト全件 PASS を確認
- [ ] ベータ配信で実機の前バージョンからアップデートして確認
- [ ] App Store Connect のリリースノートで「データは保持されます」を明記

## 既知のリスク

| リスク | 対策 |
|---|---|
| SwiftData の Custom Migration は API が限定的 | Core Data へのフォールバックを検討 (`@Model` → NSManagedObject 経由) |
| 古い iOS バージョンへの downgrade | 不可。リリース後はバージョンを上げ続ける |
| 大量データでの migration 時間 | Background `Task` で処理、splash 表示 |
| 失敗時の復旧 | バックアップ機能 (将来) で .store を別 URL に複製してから migration |

## 参考

- Apple Docs: [Schema Migration](https://developer.apple.com/documentation/swiftdata/schema)
- WWDC 23 Session 10195: Model your schema with SwiftData
- 本プロジェクトのテンプレートテスト: `CerealExerciseTests/SwiftDataMigrationTests.swift` (V1 → V2 + lightweight migration を実装、PASS 済み)
