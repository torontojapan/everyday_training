# Phase 2 Plan — 習慣化体験 (通知 / Widget / 猫キャラ演出)

## 0. フェーズゴール

要件書 §23 Phase 2 に対応する習慣化体験を実装し、§24.5 (通知) / §24.6 (ウィジェット) を満たす。

スコープ:
1. ローカル通知 (UserNotifications, デフォルト1日2回)
2. ホーム画面ウィジェット (WidgetKit, 小・中サイズ)
3. 猫キャラクター7状態の状態遷移
4. 達成演出 (アニメーション + 状態別メッセージ)
5. アプリグループ経由のホスト⇔Widget データ共有

Phase 1 の評価で出た Low 指摘 (アクセシビリティ・UIアニメ) はうち UI アニメは達成演出と合わせて本フェーズで部分対応する。

---

## 1. 追加ファイル構成

```
app/CerealExercise/
├── project.yml                                        # Widget target & entitlements 追加
├── CerealExercise/                                    # 既存ホストアプリ
│   ├── App/CerealExerciseApp.swift                    # 通知許可リクエスト, ModelContainer に App Group 設定
│   ├── Services/
│   │   ├── (既存)
│   │   ├── NotificationPermissionManager.swift        # 許可状態管理
│   │   ├── NotificationScheduler.swift                # 1日2回ローカル通知のスケジューリング
│   │   ├── NotificationMessageProvider.swift          # 通知本文生成 (§13.4, §21)
│   │   ├── SharedSnapshotStore.swift                  # App Group UserDefaults で Widget 用スナップショット保存
│   │   ├── WidgetSnapshotPublisher.swift              # 記録保存時にスナップショット更新
│   │   └── CatStateResolver.swift                     # DailyStatus + 時間帯 → CatState (7状態)
│   ├── Models/
│   │   └── CatState.swift                             # enum (waiting_morning/worried_noon/begging_night/celebrating/streak_extended/resting/encouraging)
│   ├── Models/
│   │   └── WidgetSnapshot.swift                       # Codable struct (Widget が読む共有データ型)
│   ├── ViewModels/
│   │   └── HomeViewModel.swift                        # CatState 算出 + 演出トリガ追加
│   ├── Views/
│   │   ├── CatStateView.swift                         # 7状態の表示 (画像があれば画像、なければ emoji + アニメ)
│   │   ├── CatMessageView.swift                       # CatStateView を内包するよう更新
│   │   ├── RecordCompletionView.swift                 # 達成演出追加 (紙吹雪 or scale spring)
│   │   └── Components/
│   │       └── ConfettiView.swift                     # SwiftUI ベースの軽量紙吹雪
│   └── Resources/
│       ├── CerealExercise.entitlements                # App Group: group.com.serial.cerealexercise
│       └── Info.plist                                 # NSUserNotificationsUsageDescription (iOSは不要だが UIBackgroundModes 必要に応じて)
├── CerealExerciseWidget/                              # 新規 Widget extension
│   ├── CerealExerciseWidget.swift                     # @main Widget bundle
│   ├── WidgetEntry.swift                              # TimelineEntry
│   ├── WidgetProvider.swift                           # TimelineProvider (SharedSnapshotStore から読む)
│   ├── Views/
│   │   ├── SmallWidgetView.swift                      # systemSmall: 残り時間 + 猫
│   │   ├── MediumWidgetView.swift                     # systemMedium: 達成率 + 猫 + メッセージ
│   │   └── WidgetCatView.swift                        # ホストと共通 emoji ベース
│   ├── Info.plist
│   └── CerealExerciseWidget.entitlements              # App Group 共有
└── CerealExerciseTests/
    ├── NotificationSchedulerTests.swift               # スケジュール計算
    ├── CatStateResolverTests.swift                    # 状態判定
    └── SharedSnapshotStoreTests.swift                 # シリアライズ
```

---

## 2. 通知仕様

### 2.1 NotificationPermissionManager
- 初回起動時 (またはユーザー操作時) に `UNUserNotificationCenter.requestAuthorization([.alert, .badge, .sound])` を呼ぶ
- 状態取得 `authorizationStatus()` を ViewModel から呼べるように

### 2.2 NotificationScheduler
- デフォルト: 1日2回 (`08:30` / `20:00`)
- ユーザー設定があれば優先 (Phase 3 で UI 提供、本フェーズはコードでデフォルト値)
- `UNCalendarNotificationTrigger` で `DateComponents(hour:minute:)` の毎日繰り返し
- ID は `notif.morning` / `notif.evening` で固定 → 上書き再スケジュール
- アプリ起動・記録完了時に再評価し、本日既に達成済みなら本日分の通知をキャンセル → 翌日再登録

### 2.3 NotificationMessageProvider
- 入力: 時間帯 (morning/evening), 連続記録, 週間達成率
- 出力: 要件 §13.4 / §21 の候補からランダム選択 (種は日付固定で同日2回繰り返さないように)
- 例: 「🐱 今日の運動、そろそろ一緒にやろ？」

### 2.4 通知設定 (Phase 2 では固定)
- ON/OFF: `UserDefaults` に bool 保存 (キー: `notif.enabled` デフォルト true)
- 時刻: `notif.morning.hour`, `notif.morning.minute`, `notif.evening.hour`, `notif.evening.minute`
- Phase 3 で `NotificationSettingsView` を提供

---

## 3. Widget 仕様

### 3.1 アーキテクチャ
- iOS 17 の StaticConfiguration を採用 (Configuration Intent 不要)
- App Group `group.com.serial.cerealexercise` で UserDefaults (suite) を共有
- ホストアプリは記録保存・起動時に `SharedSnapshotStore.write(WidgetSnapshot)` を実行
- WidgetProvider は `SharedSnapshotStore.read()` でスナップショットを取り、5分間隔の TimelineEntry を生成
- `WidgetCenter.shared.reloadAllTimelines()` を記録保存後に呼ぶ

### 3.2 WidgetSnapshot (Codable)
```swift
struct WidgetSnapshot: Codable, Sendable {
  let generatedAt: Date
  let todayAchieved: Bool
  let isRestDay: Bool
  let currentStreak: Int
  let weeklyAchieved: Int          // 0..7
  let weeklyTotal: Int             // 7
  let catState: String             // CatState.rawValue
  let message: String              // 表示文言
  let nightDeadlineHoursLeft: Int  // 23:59 までの残り時間 (整数)
}
```

### 3.3 SmallWidgetView (systemSmall)
- 上段: 🐱 + 残り時間 (e.g. "あと5時間")
- 下段: 今日の達成 or 未達成バッジ
- タップでアプリ起動 (要件 §14.4)

### 3.4 MediumWidgetView (systemMedium)
- 左: 🐱 大きめ + 状態
- 右上: 今週 4/7 達成
- 右下: メッセージ ("今日の運動、まだ待ってるよ" 等)

### 3.5 タイムライン
- entries: 現在 + 1時間後 + 23:59 直前 (状態変化に追従)
- `.atEnd` policy で 1時間ごとに更新

---

## 4. 猫キャラクター7状態 (§6.4)

### 4.1 CatState enum
```swift
enum CatState: String {
  case waitingMorning   // 朝・未達成: にこにこ待機
  case worriedNoon      // 昼・未達成: 少し心配
  case beggingNight     // 夜・未達成: そわそわ、お願い
  case celebrating      // 達成後: 喜ぶ、褒める
  case streakExtended   // 連続記録更新: 大喜び
  case resting          // 休養日: 回復モード
  case encouraging      // 未達成翌日: 優しく復帰を促す
}
```

### 4.2 CatStateResolver
入力: `DailyStatus`, 現在時刻 (時間帯), 前日達成有無, 連続記録更新フラグ
出力: `CatState`

優先度ルール:
1. 連続記録が今日更新された → `.streakExtended`
2. 今日達成済み → `.celebrating`
3. 休養日 → `.resting`
4. 昨日未達成・今日まだ未達成 → `.encouraging`
5. 未達成 + 時間帯
   - 〜11:59 → `.waitingMorning`
   - 12:00〜17:59 → `.worriedNoon`
   - 18:00〜23:59 → `.beggingNight`

### 4.3 CatStateView
- 表示: emoji (🐱) を基本に、状態ごとに装飾 (背景色, 揺れアニメ, 吹き出し)
- 画像差分対応 (任意): `assets/cat_character/{state}.png` があれば `Image` を使用、なければ emoji
- Phase 2 では画像は emoji のみ。画像生成 API キーが用意できたら差し替え

### 4.4 メッセージ
- CatMessageProvider (Phase 1) を CatState ベースに拡張
- 状態別文言 (要件 §6.5, §7.4, §11.4, §21.1〜§21.5) を辞書化

---

## 5. 達成演出

### 5.1 RecordCompletionView
- 保存完了時に `withAnimation(.spring())` でカードが pop-in
- 連続記録バッジが scale 1.0 → 1.2 → 1.0 でバウンス
- 紙吹雪 ConfettiView を 2秒間オーバーレイ表示
- 「今日も達成！えらい！」(§7.4)

### 5.2 ConfettiView
- 30個の小さな円形 SwiftUI shape を Random offset で animate
- 軽量 (CADisplayLink 不要、`Timer.publish` ベース)

---

## 6. App Group / Entitlements

- App Group ID: `group.com.serial.cerealexercise`
- ホスト + Widget extension の両方に `.entitlements` を作成
- `project.yml` に `entitlements` セクションを追加
- 注意: 実機 / ストア配信時は Apple Developer Account で App Group 作成が必要 (本実装はコード/設定のみ)

---

## 7. Execute 向け指示

別ファイル `orchestrator/prompts/execute_phase2.md` に詳細プロンプトを配置。要点:

1. `app/CerealExercise/` 配下に Phase 2 追加ファイルを作成
2. 既存ファイル変更は最小限 (HomeViewModel, CatMessageView, RecordCompletionView, project.yml, App.swift, Info.plist)
3. WidgetKit ベスト practice (TimelineProvider, AppIntent 不要)
4. UserNotifications の許可リクエストは初回起動 1回のみ
5. すべて Swift 6, iOS 17+
6. テスト3ファイル新規追加 (各5件以上)
7. Phase 1 のテストは壊さない

---

## 8. Evaluate (Gemini) 観点

`orchestrator/prompts/evaluate_phase2.md` で:
- §24.5 通知 全4項目
- §24.6 ウィジェット 全4項目
- §6.4 猫キャラ7状態の網羅
- §13 通知トーン (かわいくお願い)
- §14 ウィジェット表示要素
- WidgetKit / UserNotifications のベストプラクティス
- App Group + entitlements の整合性
- 既存テスト (Phase 1) を壊していないか

---

## 9. 受け入れ条件マッピング

| 受け入れ条件 (§24) | 実装ファイル |
|---|---|
| §24.5 通知ON/OFFを設定できる | UserDefaults 経由 (Phase 3 で UI 化) |
| §24.5 通知時間を設定できる | UserDefaults 経由 (Phase 3 で UI 化) |
| §24.5 デフォルト1日2回 | NotificationScheduler |
| §24.5 通知文言が猫キャラのかわいいお願いトーン | NotificationMessageProvider |
| §24.6 残り時間表示 | SmallWidgetView / MediumWidgetView (`nightDeadlineHoursLeft`) |
| §24.6 週間達成率表示 | MediumWidgetView |
| §24.6 猫キャラ/メッセージ表示 | WidgetCatView |
| §24.6 タップでアプリ起動 | Widget の `widgetURL`/StaticConfiguration |

---

## 10. リスク

- WidgetKit のプレビューは Xcode が必要なため、コード生成のみ可能
- App Group は実機 / Sandbox 設定が必要 → コード/設定のみで動作確認はビルド検証フェーズに先送り
- 通知許可リクエストは Simulator/実機テストが必要
- アニメーションの再生品質は SwiftUI Preview で確認推奨
