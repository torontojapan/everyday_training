# Phase 1 Plan — MVPコア機能

## 0. フェーズゴール

要件書 §23 Phase 1 に対応する MVP コアを実装し、§24 受け入れ条件のうち以下を満たす:
- §24.1 ホーム画面 (全6項目)
- §24.2 記録入力 (全8項目)
- §24.3 達成判定 (全5項目)
- §24.4 休養日 (全3項目)

Phase 2 で扱う通知・Widget・キャラクター画像差分は対象外。文言とプレースホルダ猫(SF Symbol `cat.fill` or emoji 🐱)で代替する。

---

## 1. プロジェクト構成 (XcodeGen)

```
app/CerealExercise/
├── project.yml                            # XcodeGen 定義
├── CerealExercise/
│   ├── App/
│   │   └── CerealExerciseApp.swift        # @main, ModelContainer 注入
│   ├── Models/
│   │   ├── WorkoutCategory.swift          # enum
│   │   ├── ExerciseItem.swift             # Codable struct
│   │   ├── WorkoutRecord.swift            # @Model (SwiftData)
│   │   └── DailyStatus.swift              # enum + value
│   ├── Services/
│   │   ├── WorkoutStore.swift             # SwiftData ModelContext ラッパー
│   │   ├── DateProvider.swift             # テスト用に置換可能
│   │   ├── AchievementEvaluator.swift     # 達成判定 §20.1
│   │   ├── RestDayResolver.swift          # 休養日判定 §11
│   │   ├── StreakCalculator.swift         # 連続記録 §10
│   │   ├── WeeklyProgressCalculator.swift # 週間達成率 §12
│   │   └── CatMessageProvider.swift       # 状態別文言 §6.4 §21
│   ├── ViewModels/
│   │   ├── HomeViewModel.swift            # @Observable
│   │   └── RecordEntryViewModel.swift     # @Observable
│   ├── Views/
│   │   ├── HomeView.swift
│   │   ├── RecordEntryView.swift
│   │   ├── ExerciseInputRow.swift
│   │   ├── RecordCompletionView.swift
│   │   ├── WeeklyCalendarView.swift
│   │   ├── StreakBadgeView.swift
│   │   ├── CatMessageView.swift
│   │   └── Components/
│   │       ├── PrimaryButton.swift
│   │       └── CategoryChip.swift
│   ├── Theme/
│   │   ├── Palette.swift                  # ポップ・柔らかい配色
│   │   └── Typography.swift               # 角丸・親しみやすいフォント
│   └── Resources/
│       ├── Assets.xcassets
│       │   ├── AccentColor.colorset       # ピーチ/コーラル系
│       │   └── AppIcon.appiconset (placeholder)
│       └── Info.plist
└── CerealExerciseTests/
    ├── AchievementEvaluatorTests.swift
    ├── RestDayResolverTests.swift
    ├── StreakCalculatorTests.swift
    └── WeeklyProgressCalculatorTests.swift
```

`project.yml` で iOS 17+ / Swift 6 / SwiftUI / SwiftData を指定。テストターゲットを `CerealExerciseTests` として定義する。

---

## 2. データモデル

### 2.1 列挙
```swift
enum WorkoutCategory: String, Codable, CaseIterable, Identifiable {
  case cardio, strength, yoga, stretch, other
  var displayName: String { ... }     // 有酸素/筋トレ/ヨガ/ストレッチ/その他
  var symbolName: String { ... }      // SF Symbol
}
```

### 2.2 ExerciseItem (値型 Codable)
要件 §19.3 通り。SwiftData の relationship を増やさず、`WorkoutRecord.exercises` を `[ExerciseItem]` として Codable で保存 (SwiftData 17 の Attribute(.externalStorage) ではなく Transformable で `Data` にエンコード)。

```swift
struct ExerciseItem: Codable, Identifiable, Hashable {
  let id: UUID
  var name: String
  var durationSeconds: Int?
  var reps: Int?
  var sets: Int?
  var memo: String?
}
```

### 2.3 WorkoutRecord (@Model)
```swift
@Model
final class WorkoutRecord {
  @Attribute(.unique) var id: UUID
  var date: Date                  // その日の 00:00 (Calendar.startOfDay)
  var categoryRaw: String         // WorkoutCategory.rawValue
  var exercisesData: Data         // [ExerciseItem] を JSON encode
  var memo: String?
  var createdAt: Date
  var updatedAt: Date
  ...
}
```
- `category` / `exercises` は computed property で型変換
- `date` は Calendar.current.startOfDay(for:) で正規化

### 2.4 DailyStatus (値型)
```swift
enum DailyStatus {
  case achieved
  case rest
  case missed
  case future
  case todayPending
  case todayAchieved
}

struct DailyStatusEntry {
  let date: Date          // startOfDay
  let status: DailyStatus
  let recordIds: [UUID]
}
```
DailyStatus は永続化不要。記録から都度計算する。

### 2.5 StreakState
```swift
struct StreakState {
  let currentStreak: Int
  let longestStreak: Int
  let lastAchievedDate: Date?
}
```
記録から都度計算する。

---

## 3. ロジック仕様

### 3.1 AchievementEvaluator
```swift
static func isAchieved(record: WorkoutRecord) -> Bool
// §20.1: 1種目以上 OR 合計1分以上

static func dailyStatus(for date: Date, records: [WorkoutRecord], weekRecords: [WorkoutRecord], today: Date) -> DailyStatus
// date と today を比較し、achieved/rest/missed/future/todayPending/todayAchieved を返す
```

### 3.2 RestDayResolver (§11)
```swift
// 週(月〜日)内の未記録日数を数え、weeklyRestLimit (=2) 以内なら未記録日を休養日扱い
static func restDays(in week: DateInterval, records: [WorkoutRecord], limit: Int = 2) -> [Date]
```

### 3.3 StreakCalculator (§10)
- 直近の達成日 or 休養日 が連続している日数を返す
- 週またぎに対応 (休養日は同一週で再計算)

### 3.4 WeeklyProgressCalculator (§12)
- 当週(月〜日)の (achieved + rest + todayAchieved) / 7

### 3.5 CatMessageProvider (§6.4, §21)
- 状態 (DailyStatus) + 時間帯 (朝/昼/夜) を入力に、表示文言と簡易絵文字キーを返す
- 文言は要件書 §21 から固定セットで複数候補、ランダムまたは決定論的に1つ選択

---

## 4. 画面構成

### 4.1 HomeView (§7, §18.1)
- 上部: アプリ名 + 連続記録バッジ (🔥 N日連続)
- 中央: 大きな PrimaryButton 「今日の運動を記録する」
- その下: WeeklyCalendarView (月〜日, ○/休/×/-/◎/・)
- その下: 今週 N/7 達成
- 下部: CatMessageView (状態別)
- NavigationStack で RecordEntryView へ遷移

### 4.2 RecordEntryView (§8, §18.2)
- フォーム
  - カテゴリ (CategoryChip 5択, 必須)
  - 種目リスト ([ExerciseItem] を追加可能)
    - 各行: 名前(必須), 時間(分秒), 回数, セット数, メモ
    - 「種目を追加」ボタン
  - メモ (全体)
  - 「保存」ボタン
- 保存後 RecordCompletionView へ

### 4.3 RecordCompletionView (§18.3)
- 達成メッセージ + 猫表示
- 今日の記録サマリ
- 連続記録
- 「ホームへ戻る」

### 4.4 WeeklyCalendarView
- 横並び 7セル (月火水木金土日)
- 各セルに記号 (○/休/×/-/◎/・)
- 今日のセルはハイライト

### 4.5 StreakBadgeView
- `🔥 12日連続` をカード状に表示

### 4.6 CatMessageView
- emoji `🐱` + 吹き出し風カードに文言

---

## 5. 状態管理

- `WorkoutStore` (@MainActor, @Observable) を環境に注入
- `HomeViewModel` は `WorkoutStore` から records をクエリ → DailyStatus / Streak / WeeklyProgress を算出
- 記録保存後は `WorkoutStore.add(...)` 経由で SwiftData 永続化、ホームに自動反映
- 日付の境界判定は `DateProvider.current()` でテスト可能にする

---

## 6. デザイン方針 (§5)

- カラー: ピーチ/コーラルアクセント + クリーム背景 + 柔らかい影
- 角丸: 大きめ (16-24pt)
- フォント: SF Rounded
- 黒基調・ジムアプリ風は禁止
- 1画面の情報密度は低く、空白を活かす

### Palette (例)
```swift
enum Palette {
  static let bg = Color(red: 1.00, green: 0.97, blue: 0.93)   // クリーム
  static let primary = Color(red: 1.00, green: 0.62, blue: 0.55) // コーラル
  static let secondary = Color(red: 0.96, green: 0.85, blue: 0.74) // ピーチ
  static let textPrimary = Color(red: 0.30, green: 0.25, blue: 0.20)
  static let success = Color(red: 0.55, green: 0.78, blue: 0.55)
  static let restDay = Color(red: 0.70, green: 0.80, blue: 0.95)
}
```

---

## 7. 非機能 (§22)

- ホームから2タップ以内で記録: 「記録する」→ フォーム → 保存 で達成
- 起動時は ModelContainer 初期化のみ、ホーム表示は SwiftData query で1フレーム以内
- 保存は SwiftData の `context.insert` + `try? context.save()` で即時反映

---

## 8. Execute 向け指示 (Codex CLI に渡す)

別ファイル `orchestrator/prompts/execute_phase1.md` に詳細プロンプトを配置する。要点:

1. `app/CerealExercise/` 配下に上記ディレクトリ構造でファイルを新規作成
2. `project.yml` を作り、`xcodegen generate` で `CerealExercise.xcodeproj` が生成できる状態にする
3. iOS 17+, Swift 6, SwiftUI, SwiftData
4. すべてのファイルがビルド可能 (構文・型)
5. テスト4ファイルに各5件以上の XCTest を実装
6. ファイル冒頭にコメントは書かない
7. 言語は日本語 (日本語UI文字列)
8. **Antigravity や他CLI は使わない**

---

## 9. Evaluate (Gemini) 観点

`orchestrator/prompts/evaluate_phase1.md` に詳細を書く。要点:

- §24.1〜§24.4 の受け入れ条件を1項目ずつチェック
- ロジック実装 (達成判定 §20, 連続記録 §10, 休養日 §11) が要件通りか
- SwiftUI/SwiftData ベストプラクティス
- UI/デザイン方針 (§5: ポップ・柔らかい・女性向け)
- コード品質 (Force unwrap, 命名, 重複)

判定: PASS / CONDITIONAL_PASS / FAIL を必ず付与。

---

## 10. 受け入れ条件マッピング

| 受け入れ条件 (§24) | 実装ファイル |
|---|---|
| §24.1 ホーム画面6項目 | HomeView, StreakBadgeView, WeeklyCalendarView, CatMessageView |
| §24.2 記録入力8項目 | RecordEntryView, ExerciseInputRow, CategoryChip |
| §24.3 達成判定5項目 | AchievementEvaluator, StreakCalculator, WeeklyProgressCalculator, WorkoutStore |
| §24.4 休養日3項目 | RestDayResolver, WeeklyProgressCalculator |
| §24.5/24.6 通知・Widget | Phase 2 で実装 (本Phaseは対象外) |

---

## 11. 想定リスク

- SwiftData の `Transformable` で `[ExerciseItem]` を保存する際の型情報問題 → JSON Data として保存することで回避
- Xcode 未インストール環境ではビルド検証ができない → ユーザーのXcodeインストール完了を待つ
- 日付ロジックの境界バグ → DateProvider 注入 + XCTest で網羅
