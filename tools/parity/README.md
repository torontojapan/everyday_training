# パリティ差分ハーネス(Android↔iOS 100% 一致の検証基盤)

iOS build 12 と Android を「同一視覚状態」で撮影し、SSIM(知覚類似度)で機械検証する。
合格基準: 各 画面×状態 で **SSIM ≥ 0.97**(SwiftUI↔Compose のレンダラ差で 1px 完全一致は不可能なため知覚基準)。

## 構成
- `diff.py` — 差分エンジン。chrome クロップ→寸法整列→SSIM+差分ヒートマップ→横並び合成+HTML レポート。
- `pairs.json` — 比較ペア [{name, ios, android, top?, bottom?}]。
- `capture_android.py` — emulator(go_test)を adb 駆動して各 画面×状態 を撮影(同一データ)。
- iOS は XCUITest `ScreenshotCaptureUITests`(全状態)で golden を撮る。

## 使い方
```
# 単発
python3 tools/parity/diff.py ios.png android.png --out composite.png
# バッチ(レポート)
python3 tools/parity/diff.py --pairs tools/parity/pairs.json --out-dir parity_report
open parity_report/index.html
```

## 前提(超重要)
SSIM が意味を持つのは **両OSが同一データ・同一ロケール・固定時刻・対応画面サイズ**のとき。
データが違うと(例: 連続 365 vs 18)構造が一致していても SSIM は下がる。撮影スクリプトで状態を厳密に揃える。

詳細計画: `docs/PARITY_100_PLAN.md`
