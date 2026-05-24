# 実機 (iPhone) Instruments プロファイリング ガイド

Simulator では `xctrace` の trace 生成が空になるため、実機での計測が必要。
本ガイドは iPhone を Mac に接続して App Launch / Allocations / Time Profiler / Energy を計測する手順をまとめます。

## 前提条件

| 項目 | 必要なもの |
|---|---|
| iPhone 実機 | iOS 17 以降 |
| 接続 | USB-C / Lightning ケーブル または 同一 WiFi (WiFi デバッグ有効) |
| Apple ID | 有効な Apple ID (無料 Personal Team で OK) |
| Xcode | 26.5 (本プロジェクトは Xcode 17 系) |
| 開発者モード | iPhone の「設定 → プライバシーとセキュリティ → デベロッパモード」を ON |

## ステップ 1: iPhone を接続して認識確認

```bash
# USB / WiFi で接続後
xcrun xctrace list devices

# 期待: 接続した iPhone が表示される
# 例:
# == Devices ==
# Jun's iPhone (00008140-001A1B2C3D4E5F6G) iOS 26.5
```

接続が見えない場合:
- iPhone 画面で「このコンピュータを信頼しますか?」→ 信頼する
- Xcode を一度開く → Windows → Devices and Simulators → 該当 iPhone を Pair

## ステップ 2: コード署名設定

Personal Team (Apple ID) で実機ビルドする場合:

```bash
# Apple ID を Xcode で追加
open -a Xcode  # → Settings → Accounts → Apple IDs → +
```

`project.yml` の DEVELOPMENT_TEAM をご自身の Team ID (例: `ABCD123456`) に変更:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "ABCD123456"  # ← Xcode → Settings → Accounts → 該当 Apple ID で確認
    CODE_SIGN_STYLE: Automatic
```

xcodegen generate → ビルド時に Xcode が自動でプロビジョニング profile を生成。

## ステップ 3: 実機ビルド & インストール

```bash
DEVICE_UDID=00008140-001A1B2C3D4E5F6G  # ステップ 1 で取得した実機 UDID

cd app/CerealExercise

xcodebuild \
  -project CerealExercise.xcodeproj \
  -scheme CerealExercise \
  -destination "id=$DEVICE_UDID" \
  -configuration Debug \
  build

# 出力 .app を取得
DEVICE_APP=$(find ~/Library/Developer/Xcode/DerivedData/CerealExercise-* \
  -name "CerealExercise.app" -path "*/Debug-iphoneos/*" -type d | head -1)

# devicectl で実機にインストール
xcrun devicectl device install app --device "$DEVICE_UDID" "$DEVICE_APP"
```

## ステップ 4: xctrace で計測

### App Launch (起動時間 + Hangs)

```bash
mkdir -p artifacts/verification/traces

xcrun xctrace record \
  --template "App Launch" \
  --device "$DEVICE_UDID" \
  --launch -- com.serial.cerealexercise \
  --time-limit 30s \
  --output artifacts/verification/traces/device_app_launch.trace
```

完了後、`.trace` を Xcode の Instruments.app で開く:
```bash
open artifacts/verification/traces/device_app_launch.trace
```

主な観察点:
- `Hang Detection`: 250ms 以上のメインスレッドブロックがあるか
- `Time to Interactive`: タップ可能になるまで
- 起動の3フェーズ (Initialization / Static Runtime / Pre-main)

### Allocations (メモリ)

```bash
xcrun xctrace record \
  --template "Allocations" \
  --device "$DEVICE_UDID" \
  --launch -- com.serial.cerealexercise --seed-demo-data --no-notification-prompt --seed-scenario long-streak \
  --time-limit 60s \
  --output artifacts/verification/traces/device_allocations.trace
```

主な観察点:
- Persistent bytes (生存中のヒープ)
- Allocation count (頻度の多い型)
- WidgetSnapshot, WorkoutRecord, ExerciseItem の累積

### Time Profiler (CPU)

```bash
xcrun xctrace record \
  --template "Time Profiler" \
  --device "$DEVICE_UDID" \
  --launch -- com.serial.cerealexercise --seed-demo-data --no-notification-prompt \
  --time-limit 30s \
  --output artifacts/verification/traces/device_time_profiler.trace
```

主な観察点:
- `WorkoutRecord.exercises` getter (JSON decode が頻発するか)
- `StreakCalculator.streakState` (365日ループ)
- `WeeklyProgressCalculator.statuses`

### Energy (バッテリー消費)

```bash
xcrun xctrace record \
  --template "Energy Log" \
  --device "$DEVICE_UDID" \
  --launch -- com.serial.cerealexercise \
  --time-limit 5m \
  --output artifacts/verification/traces/device_energy.trace
```

5 分間アプリを開きっぱなしで放置し、`Energy Impact` を確認。

## ステップ 5: 結果のサマリ化

各 .trace を Instruments.app で開き、以下を artifacts/verification/performance.md に追記:

| 項目 | 目標値 | 計測値 |
|---|---|---|
| Cold launch (Time to Interactive) | < 1.0 s | (実機計測) |
| Memory peak (foreground) | < 50 MB | (Allocations) |
| Memory growth over 5min | < 5 MB | (Allocations) |
| CPU 平均 (idle) | < 5% | (Time Profiler) |
| Energy Impact (5min idle) | Low | (Energy) |

## 推奨計測シナリオ

1. **Cold launch (basic)** — 普段の起動
2. **Cold launch (long-streak, 30日連続)** — 大きめデータでの起動
3. **記録入力 → 保存 → 完了画面** までの一連 (Time Profiler)
4. **設定 → 通知設定変更** (Allocations で UNCalendarNotificationTrigger の生成)
5. **Widget リフレッシュ** (`WidgetCenter.reloadAllTimelines`)

## トラブルシューティング

| エラー | 対処 |
|---|---|
| `Unable to install app: codesigning failure` | DEVELOPMENT_TEAM 設定確認、Xcode で signin |
| `Device not paired` | Xcode → Devices and Simulators → iPhone → Trust |
| `Application could not be launched` | iPhone 開発者モード ON、Profile 受け入れ (設定 → 一般 → VPN とデバイス管理) |
| `xctrace not found` | `sudo xcode-select -s /Applications/Xcode-26.5.0.app/Contents/Developer` |
