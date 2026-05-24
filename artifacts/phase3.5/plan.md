# Phase 3.5 Plan — UI/UX 改善 (中優先項目)

## 0. フェーズゴール

Phase 1-3 で実装した MVP を、Gemini 評価 + Claude の観察から抽出した **中優先 UI/UX 課題** を解消することで、App Store 提出後のユーザー体験を一段上げる。

スコープ:
1. **ホーム画面の余白活用** — リッチデータ時にも下半分が空白問題
2. **iPad NavigationSplitView** — iPhone 拡大ではなく iPad ネイティブ感
3. **記録入力の保存後フロー** — 「次の種目を追加」「保存して終わる」を選べる
4. **DatePicker のアフォーダンス改善** — 通知時間が押せると分かるように
5. **空状態 (Empty State) の網羅** — 設定通知未許可 / サジェストゼロ
6. **ハプティクスフィードバック** — 保存成功 / 達成時

Phase 1-3 評価で Low priority だった項目のうち、UI体験に直接影響するもの。

---

## 1. 追加・変更ファイル構成

```
app/CerealExercise/
├── CerealExercise/
│   ├── Views/
│   │   ├── HomeView.swift                 # 拡張: 達成サマリーカード + 今週ハイライト
│   │   ├── Components/
│   │   │   ├── TodayAchievementSummaryCard.swift  # 新規: 今日の達成内容サマリー
│   │   │   ├── WeeklyHighlightCard.swift          # 新規: 週間ハイライト (連続最長, 種目傾向)
│   │   │   └── HapticFeedback.swift               # 新規: UIImpactFeedbackGenerator wrapper
│   │   ├── RecordEntryView.swift          # 拡張: 保存後アクション ConfirmationDialog
│   │   ├── NotificationSettingsView.swift # 拡張: DatePicker styling + 未許可時 banner
│   │   ├── HistoryView.swift              # 拡張: 種目傾向ヘッダー
│   │   ├── RootSplitView.swift            # 新規: iPad NavigationSplitView (sidebar + detail)
│   │   └── PrimaryButton.swift            # 拡張: tap時 haptic + scale
│   ├── App/
│   │   └── CerealExerciseApp.swift        # 拡張: UIUserInterfaceIdiom で View 切替
│   └── Services/
│       └── ExerciseTrendSummary.swift     # 新規: 今週・今日の傾向集計
└── CerealExerciseTests/
    ├── ExerciseTrendSummaryTests.swift    # 新規 (5件以上)
    └── HapticFeedbackTests.swift          # 新規 (3件以上、protocol 経由で呼び出し検証)
```

---

## 2. 機能仕様

### 2.1 TodayAchievementSummaryCard
- 今日達成済みのとき表示 (todayAchieved=true)
- 表示要素: カテゴリアイコン + 種目数 + 合計時間
- 例: `🏋️ 筋トレ ・ 2種目 ・ 8分`
- 未達成日 / 休養日では非表示

### 2.2 WeeklyHighlightCard
- 表示要素:
  - 今週使用したカテゴリ (chip 並び)
  - 今週の合計運動時間
  - 最も多い種目 Top 3
- 全週分のレコードから集計
- データなしの週は表示しない (空白防止)

### 2.3 ExerciseTrendSummary (Service)
```swift
@MainActor
enum ExerciseTrendSummary {
    struct DailySummary {
        let categoryCounts: [WorkoutCategory: Int]
        let exerciseCount: Int
        let totalDurationSeconds: Int
    }

    struct WeeklySummary {
        let usedCategories: [WorkoutCategory]
        let totalDurationSeconds: Int
        let topExerciseNames: [String]
    }

    static func today(records: [WorkoutRecord], today: Date, calendar: Calendar) -> DailySummary
    static func week(records: [WorkoutRecord], week: DateInterval, calendar: Calendar) -> WeeklySummary
}
```

### 2.4 iPad NavigationSplitView (RootSplitView)
- Sidebar: ホーム / 履歴 / 設定 のセクション
- Detail: 選択されたセクションのコンテンツ
- iPhone では HomeView を継続使用
- 切替条件: `UIDevice.current.userInterfaceIdiom == .pad`
- iPadOS 17+ の `NavigationSplitView` 標準 API

### 2.5 RecordEntryView: 保存後 ConfirmationDialog
- 「保存」タップ後、`.confirmationDialog` で 3 択:
  - **続けて記録** (記録入力を残してフィールドリセット)
  - **完了画面を開く** (現状のフロー)
  - **キャンセル**
- 「続けて記録」を選んだ場合は ViewModel をクリアして同じ画面に留まる

### 2.6 DatePicker アフォーダンス改善
- NotificationSettingsView の DatePicker を `.datePickerStyle(.compact)` 明示
- ラベル余白を再調整、`Image(systemName: "chevron.right")` を時刻横に配置 (HIG ガイドライン準拠)

### 2.7 空状態の追加
- **NotificationSettingsView**: 通知許可が未取得時、上部に warning banner と「設定アプリを開く」リンク (`UIApplication.openSettingsURLString`)
- **RecordEntryView**: 選択カテゴリでサジェストゼロ件のとき、控えめなプレースホルダ (例: 「履歴がたまると、ここによく使う種目が出ます」)

### 2.8 HapticFeedback
- protocol 経由でテスト可能に
```swift
protocol HapticFeedbackProviding {
    func success()
    func warning()
    func tap()
}

@MainActor
final class HapticFeedback: HapticFeedbackProviding {
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}
```
- PrimaryButton, RecordEntryView 保存時、RecordCompletionView 表示時に呼ぶ

---

## 3. アクセシビリティ強化 (繰越分)

- Reduce Motion 対応: `@Environment(\.accessibilityReduceMotion)` を CatStateView, ConfettiView, Motion プリセットで参照
- VoiceOver: TodayAchievementSummaryCard / WeeklyHighlightCard に accessibilityLabel + value

---

## 4. Execute 向け指示

`orchestrator/prompts/execute_phase3.5.md` に詳細を書く。要点:

1. 新規 service `ExerciseTrendSummary.swift` 実装 + テスト 5 件以上
2. 新規 component `TodayAchievementSummaryCard`, `WeeklyHighlightCard`, `HapticFeedback`
3. `HomeView` 拡張: viewModel.summary を取得して 2 カード表示
4. `RecordEntryView` 拡張: 保存後 ConfirmationDialog
5. `NotificationSettingsView` 拡張: warning banner + DatePicker styling
6. `RootSplitView` 新規 (iPad 専用) + `CerealExerciseApp` 振り分け
7. `PrimaryButton` 拡張: scale + haptic
8. Reduce Motion 対応
9. 既存テスト (57件) を壊さない
10. テスト最低 8 件追加 (ExerciseTrendSummary 5件 + HapticFeedback 3件)

---

## 5. Evaluate (Gemini) 観点

`orchestrator/prompts/evaluate_phase3.5.md` で:
- Phase 3 で繰越となった項目すべて解消されているか
- iPad レイアウトが iPhone 拡大に見えないか
- 空状態が破綻なく表示されるか
- ハプティクスフィードバックが過剰でないか
- Reduce Motion が機能するか (Code review レベル)
- 既存 §24 受け入れ条件にリグレッションなし
- 57 ユニットテストが破壊されていない

---

## 6. リスク

- iPad NavigationSplitView は iOS 17/18 で挙動差がある可能性 → SimulatorとプレビューでXcode 26.5確認
- HapticFeedback は Simulator では発火しない (ログのみで確認)
- Reduce Motion はSimulator で `Settings > Accessibility > Motion` で切替可能
- ConfirmationDialog の保存後アクションは UX 検討が必要 (既存フローのリグレッションリスク)

---

## 7. 受け入れ基準 (本 Phase 独自)

- [ ] ホーム画面に達成サマリーと週間ハイライトが表示される (デモモード)
- [ ] iPad で NavigationSplitView が機能する
- [ ] 記録入力で「続けて記録」を選ぶと同画面に留まる
- [ ] 通知設定の DatePicker に chevron が表示される
- [ ] 通知未許可時に warning banner が表示される
- [ ] 保存成功時にハプティクスフィードバック (コード上で呼ばれることを確認)
- [ ] 既存 57 ユニットテスト + 新規 8件 = 65件以上 が PASS
