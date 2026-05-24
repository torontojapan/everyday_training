# App Store 提出パッケージ

このディレクトリは App Store Connect 提出に必要な資料をまとめています。

## ファイル

- [`app_store_metadata.md`](app_store_metadata.md) — App Store Connect の各フィールド (アプリ名・説明文・キーワード・カテゴリ・サポート/プライバシー URL 等)
- [`PrivacyPolicy.md`](PrivacyPolicy.md) — プライバシーポリシー (URL ホスト用)
- [`TermsOfService.md`](TermsOfService.md) — 利用規約 (URL ホスト用)
- `screenshots/iphone-6.7/` — iPhone 15 Pro Max スクリーンショット (1290 × 2796)
- `screenshots/iphone-6.5/` — iPhone 11 Pro Max スクリーンショット (1242 × 2688, optional)
- `screenshots/ipad-13/` — iPad Pro 13" スクリーンショット (2064 × 2752, iPad 配信時)

## スクリーンショット撮影手順

1. デモモードでアプリを起動 (12日連続 + サンプル種目が seed される)

   ```bash
   DEVICE_UDID=$(xcrun simctl list devices available | grep "iPhone 15 Pro Max" | grep -oE "[A-F0-9-]{36}" | head -1)
   xcrun simctl boot "$DEVICE_UDID"
   open -a Simulator
   xcrun simctl install "$DEVICE_UDID" path/to/CerealExercise.app
   xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise --seed-demo-data --no-notification-prompt
   ```

2. 各画面で `xcrun simctl io <UDID> screenshot submission/screenshots/iphone-6.7/<N>_<画面名>.png`

3. iPad / 6.5" の場合は新規 Simulator を作成して同手順

### 個別画面の direct launch (launch arg `--initial-route`)

Phase 3.5 で initial-route 対応済み。直接特定画面で起動可能:

```bash
# 記録入力画面
xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise \
  --seed-demo-data --no-notification-prompt --initial-route record

# 履歴画面
xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise \
  --seed-demo-data --no-notification-prompt --initial-route history

# 設定画面
xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise \
  --seed-demo-data --no-notification-prompt --initial-route settings

# 通知設定画面
xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise \
  --seed-demo-data --no-notification-prompt --initial-route notification-settings
```

### Widget スクショ撮影手順 (手動操作必須)

`xcrun simctl` には UI tap 自動化が含まれないため、ホーム画面ウィジェットの追加は **Simulator 上で手動操作** が必要です。

1. **デモモード起動 + Home Screen に戻る**
   ```bash
   xcrun simctl launch "$DEVICE_UDID" com.serial.cerealexercise --seed-demo-data --no-notification-prompt
   sleep 2
   # アプリを kill して Home Screen を露出
   xcrun simctl terminate "$DEVICE_UDID" com.serial.cerealexercise
   ```
   または Simulator のメニューバーで `Device > Home` (Cmd+Shift+H)

2. **Widget Gallery を開く**
   - ホーム画面の空白部分を **長押し** (option キー + ホールドで Long press シミュレート、または Simulator メニューの `Device > Touch > Long Press`)
   - 左上の **「+」** ボタンをタップ

3. **GOエクササイズを検索**
   - 検索欄に `シリアル` または `Cereal` と入力
   - Small / Medium / どちらかをタップ

4. **「ウィジェットを追加」** をタップ

5. **スクショ撮影**
   ```bash
   xcrun simctl io "$DEVICE_UDID" screenshot \
     submission/screenshots/widgets/small_home.png
   ```

> Small Widget は今日の残り時間 + 円形プログレス (達成率) + 猫キャラ。Medium Widget は達成率の数字 + メッセージ + 猫。両方タップでアプリ起動 (要件 §24.6)。

## プライバシーポリシー URL のホスト

GitHub Pages を使う場合 (リポジトリ Settings → Pages):

1. Source: `Deploy from a branch`
2. Branch: `main` / `docs` folder (もしくは `gh-pages` ブランチ)
3. `submission/PrivacyPolicy.md` を `docs/privacy.md` にコピーまたは Symlink

公開 URL の例:
- `https://torontojapan.github.io/everyday_training/privacy`
- `https://torontojapan.github.io/everyday_training/terms`
- `https://torontojapan.github.io/everyday_training/support`

これらの URL を `app_store_metadata.md` のサポート/プライバシー欄に記入します。
