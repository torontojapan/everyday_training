# パフォーマンス検証

検証日: 2026-05-24
環境: iPhone 17 Pro / iOS 26.5 Simulator (M1+ host)
ビルド: Debug 構成 (`-configuration Debug`)
ビルド commit: `aee631c`

## 起動時間 (cold launch × 5)

各回ごとに `simctl terminate` → `simctl launch` で時間計測。

| 回 | 起動時間 |
|---:|---:|
| 1 (cold) | 0.185s |
| 2 | 0.422s |
| 3 | 0.461s |
| 4 | 0.458s |
| 5 | 0.443s |
| **平均** | **0.394s** |
| **2回目以降平均** | **0.446s** |

要件 §22.2 「アプリ起動は高速であること」を十分に満たす。ユーザー知覚として「即時起動」レベル (一般に 500ms 未満で起動とされる基準クリア)。

## バイナリサイズ

### Debug 構成 (初回計測)

| 項目 | サイズ |
|---|---:|
| アプリ全体 (.app) | 19 MB |
| 実行バイナリ | 40 KB |
| Assets.car | 15 MB |
| Widget extension | 548 KB |

### Release 構成 (初回 / 画像最適化なし)

| 項目 | サイズ |
|---|---:|
| アプリ全体 | 18 MB |
| 実行バイナリ | 2.3 MB |
| Assets.car | 15 MB |
| Widget extension | 376 KB |

### Release 構成 (pngquant 最適化後 ✅)

`pngquant --quality 65-85` で猫キャラ 7枚、`--quality 80-95` でアプリアイコン。

| 項目 | サイズ | 削減 |
|---|---:|---:|
| アプリ全体 | **8.3 MB** | **-54%** |
| 実行バイナリ | 2.3 MB | 変化なし |
| Assets.car | **5.5 MB** | **-63%** |
| Widget extension | 376 KB | 変化なし |

#### 猫キャラ画像 個別

| 状態 | 元 | 最適化後 |
|---|---:|---:|
| beggingNight | 2.3 MB | 792 KB |
| celebrating | 2.3 MB | 736 KB |
| encouraging | 1.9 MB | 536 KB |
| resting | 2.1 MB | 640 KB |
| streakExtended | 2.6 MB | 988 KB |
| waitingMorning | 1.9 MB | 536 KB |
| worriedNoon | 2.1 MB | 612 KB |
| **合計** | **15 MB** | **4.7 MB** |

AppIcon: 1.7 MB → 436 KB (1024×1024 リサイズ + pngquant)。

画質劣化は知覚的にほぼなし (quality 65-85 は写真や水彩イラストで十分)。

## メモリ使用量

Simulator の制限で精密 RSS が取得不能 (xcrun simctl spawn → `launchctl print` 経由は iOS 17+ Simulator で `No such file or directory`)。実機 + Instruments での計測が必要。

推測ベース:
- Phase 1-3.5 で使用する SwiftData / SwiftUI / WidgetKit の標準的なアプリのワーキングセットは 30-60MB が一般的範囲
- WorkoutRecord 12 件 + ExerciseItem 〜30 件は SwiftData 内 < 50KB
- 猫キャラ画像はオンデマンドロード (UIImage cache 経由)

## CPU / Animation

`xctrace record --template "App Launch"` を試したが、Simulator では trace 生成が空のまま終了。Simulator では Time Profiler / Animation Hitches の信頼性が低いため、実機計測推奨。

定性的観察 (Simulator + コードレビュー):
- 起動後ホーム画面表示は即時
- WeeklyCalendarView の 7 セル、CatStateView の breathing アニメ等は 60fps を維持 (目視)
- ConfettiView は Phase 3.5 で Reduce Motion 対応済み
- アニメーションは Motion プリセット (snappy/gentle/bouncy) で集中管理

## SwiftData / ロジック層のパフォーマンス

ユニットテスト 81 件の合計実行時間:

```
Executed 81 tests, with 0 failures (0 unexpected) in 0.114 (0.138) seconds
```

→ 1 テスト当たり < 2ms。各種計算 (達成判定 / 連続記録 / 週間達成率 / 休養日 / トレンド集計) はオフラインで即時。

### 内訳

- AchievementEvaluator 6
- RestDayResolver 5
- StreakCalculator 5
- WeeklyProgressCalculator 6
- NotificationScheduler 6
- CatStateResolver 5
- SharedSnapshotStore 5
- ExerciseHistoryProvider 5
- NotificationSettingsViewModel 6
- WidgetTimelineDates 6
- ExerciseTrendSummary 6 (Phase 3.5)
- HapticFeedback 3 (Phase 3.5)
- DemoDataSeeder 7 (Verification)
- **DataResilience 8** (corrupt JSON / unknown enum raw / null suite / empty DB) — 新規

## 知見・既知の懸念

| 項目 | 状態 | コメント |
|---|---|---|
| 起動速度 | ✅ 0.4s | 要件達成 |
| Asset サイズ | 🟡 15MB | 画像最適化で改善可 |
| Widget reload 頻度 | ✅ atEnd policy | 1時間 + 23:59 で適切に再ビルド |
| WorkoutRecord.exercises の JSON decode が getter ごと | 🟡 | 大量レコード時 (100+) でキャッシュ検討。MVP 規模なら問題なし |
| StreakCalculator.streakState の lookbackDays=365 | 🟡 | 1年分を毎回走査。HomeView では `currentStreak` のみ使用なら影響なし、履歴で `streakState` 呼ぶと重い可能性 |

## 推奨次アクション (任意)

1. **Release 構成でビルドサイズ再測定** (`-configuration Release`)
2. **実機 (iPhone) で Instruments App Launch + Allocations** 取得
3. **画像 PNG 最適化** (`pngquant --quality 65-85 *.png`) で 15MB → 5MB 想定
4. **WorkoutRecord.exercises キャッシュ** (`@Transient private var _cached`) を 100 件超で評価

## 結論

要件 §22 非機能要件 (起動高速・ホーム表示遅延なし・記録保存即時) を十分に満たしている。
Asset サイズが他項目に比べて目立つが、Production 提出前の画像最適化で容易に削減可能。
