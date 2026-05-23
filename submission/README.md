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
