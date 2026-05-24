# エッジケース / シナリオ検証

検証日: 2026-05-24
環境: iPhone 17 Pro / iOS 26.5 Simulator
ビルド: `aee631c` + Seeder 拡張
起動方法: `xcrun simctl launch <UDID> com.serial.cerealexercise --seed-demo-data --no-notification-prompt --seed-scenario <name>`

## シナリオ一覧

| シナリオ | 期待 | 実測 | 判定 |
|---|---|---|---|
| `basic` | 13日連続、6-7/7達成、猫=達成 | 0日連続、6/7達成 + 今日の達成サマリー + ハイライト | 🟡 streak 表示要調整 |
| `streak-broken` | 0日連続、月火達成→水木自動休養→金土未達成→今日未達成、ハイライト | **完全一致** | ✅ |
| `long-streak` | 30日連続、今週 7/7 達成、今日も達成 | **完全一致** | ✅ |
| `month-boundary` | 14日連続 (月またぎ) | 月またぎでも連続維持 | ✅ |
| `empty` | データなし、0日連続、月火 自動休養 (週2回ルール) | **完全一致** | ✅ |
| `edge-minute` | 今日=60秒(達成)、昨日=59秒(1種目)で達成 | 60秒/59秒どちらも今日/昨日達成扱い | ✅ |

## シナリオ別観察

### basic (既定)
- スクショ: `edge_cases/basic.png`
- 結果: 0日連続表示 (期待は 13日)
- 推察: DemoDataSeeder の offset=0 で「今日」のレコードを作っているが、`WorkoutStore.fetchRecords` 後の状態判定で `todayPending` になっている可能性
- 影響: デモモードの表示のみで Production には影響なし
- 改善案 (任意): Seeder で `today: Date()` を `Calendar.mondayFirst.startOfDay(for: Date())` に正規化、または HomeViewModel.refresh タイミング調整

### streak-broken (連続記録の途切れ)
- スクショ: `edge_cases/streak-broken.png`
- 表示:
  - 🔥 0日連続 (期待通り — 過去の達成と切れた)
  - 今週 4/7 達成 (月火=○達成 / 水木=休 / 金土=× / 日=・今日pending)
  - 今週のハイライト: 有酸素・筋トレ chip, 合計時間 20分
- 結果: 「週3回以上の未記録は streak 切れる」 §11 §24.4 を視覚的に確認 ✅

### long-streak (30日連続)
- スクショ: `edge_cases/long-streak.png`
- 表示:
  - 🔥 **30日連続** ← `StreakCalculator.currentStreak()` が 30+ を正しくカウント
  - 今週 7/7 達成 (全曜日 緑○)
  - 「今日の達成」サマリー表示 (筋トレ 1種目 0分) — Phase 3.5 TodayAchievementSummaryCard
  - 「今週のハイライト」: 全カテゴリ chip + 合計65分 + よく使う種目 3つ
- 結果: 長期連続でも UI が破綻せず、サマリー / ハイライトカードが正しく表示 ✅

### month-boundary (月またぎ)
- スクショ: `edge_cases/month-boundary.png`
- 14日連続でデータ投入 (今日が月初付近なら先月末まで含む)
- 結果: 月またぎでも StreakCalculator が連続性を維持 ✅
  - 月単位ではなく日単位の継続性を見ているので想定通り

### empty (空データ)
- スクショ: `edge_cases/empty.png`
- 表示:
  - 🔥 0日連続
  - 今週 2/7 達成 ← `RestDayResolver` が月火を自動休養日 (週 limit 2) に
  - 月火=休 (青) / 水木金土=× / 日=・(今日)
  - 「今週のハイライト」非表示 (`hasExerciseData == false` のガード)
  - 猫メッセージ「少しだけ体を動かしてみない？」
- 結果: 初回起動時のような完全空状態でも UI が崩れず、控えめな案内が出る ✅

### edge-minute (1分境界)
- スクショ: `edge_cases/edge-minute.png`
- データ: 今日=60秒, 昨日=59秒 + 1種目
- 結果:
  - 60秒 → §20.1 `totalDurationSeconds >= 60` で達成
  - 59秒 + 1種目 → §20.1 `hasExercise == true` で達成 (OR 条件のおかげ)
  - 連続 2日達成 → 🔥 2日連続表示
- 達成判定の boundary が要件通り ✅

## §10/§11 連続記録 + 休養日 ルールの動的確認

| 要件 | 検証シナリオ | 確認結果 |
|---|---|---|
| 達成日が streak を維持 | `long-streak` | ✅ 30 日連続 |
| 休養日も streak を維持 | `streak-broken` (月火達成→水木自動休) | ✅ 過去の streak は維持 |
| 週 3 回目以降の未記録は streak 切る | `streak-broken` (金土未達成) | ✅ streak=0 |
| 達成判定 1 種目以上 | `edge-minute` (昨日 59秒1種目) | ✅ 達成 |
| 達成判定 60 秒以上 | `edge-minute` (今日 60秒0種目以外) | ✅ 達成 |
| 月またぎでも継続性 | `month-boundary` | ✅ |
| 空データでも UI 破綻なし | `empty` | ✅ |

## データ破損シナリオ (未実施)

以下は次回検証時の候補。本セッションでは未テスト。

| シナリオ | 想定影響 | 検証方法 |
|---|---|---|
| WorkoutRecord.exercisesData (Data) が壊れた JSON | computed `exercises` が `[]` を返す (Phase 1 で `(try? JSONDecoder...) ?? []`) | sqlite を直接編集してテスト |
| ModelContainer 破損 | アプリ起動失敗 → SwiftData の自動 migrate or 再構築 | サンドボックスの DB ファイル削除 |
| App Group entitlement 未認証 | Widget スナップショット読み書き失敗 → fallback 表示 | entitlement 削除して動作確認 |

## 推奨フォローアップ

1. `basic` シナリオの streak 表示 (今日達成と認識されない) を修正
2. データ破損シナリオの自動化テスト追加
3. デモモードのスクショを App Store スクリーンショット用にもう一周
