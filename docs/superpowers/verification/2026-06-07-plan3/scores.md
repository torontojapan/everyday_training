# 計画③ E(シェイカー猫)検証結果

## コード(Phase 0)
- `CatBreed.shakerAssetName` + `resolvedShakerAssetName(exists:)`(3段フォールバック: breed shaker→breed waiting→orange shaker)。`CatBreedShakerTests` 4本(全11種規約 + フォールバック3段)。build-for-testing GREEN。
- `BigCatView.useShaker`: RecordCompletion=常時 / Home catTheater=今日未記録時(`!todayStatus.countsAsAchieved`)。達成段階(CatRank)非依存。
- **画像欠落でも破綻しない**(フォールバック)設計。

## アセット(Phase 1)— 全10猫種生成
- Codex CLI 画像生成(各 breed の waitingMorning + orange shaker を参照画像に -i 渡し、**逐次**)→ `sips` 1024² → PIL flood-fill 透過(外側白のみ・内部の白=シェイカー/ヘッドバンド/靴下は保持)。
- **3LLM トンマナ検証**(contact sheet・`shaker_contact.png`): Codex 8/12・Gemini 8/12 で **gray のみ除外指摘**(初回生成が「立ちポーズ+シェイカー無し」)→ gray を pose 制約強化で再生成、座り+シェイカー保持を確認。両LLMとも breed coloring 3/3・scottish の折れ耳等は正確、青滲み無しを確認。残り9種は full-res で個別確認済(白/クリーム猫=白ボディがlineartで保護され透過穴なし)。
- 結果: **全11猫種(orange既存 + 10生成)トンマナ統一でマージ**。

## 実機(simctl)
- `home_shaker_black.png`: 猫種=black + 今日未記録 → ホーム catTheater に**黒猫シェイカー版**が表示。透過クリーン・halo自然。表示タイミング(E22)/トンマナ(E20)確認。
- RecordCompletion(記録直後ヒーロー)は同じ `BigCatView(useShaker:true)` 経路のため同様に動作(対話操作要のため未撮影だが配線・アセットは home と共通)。

## 実機で見てほしい点
- 各猫種で記録直後ヒーロー + ホーム未記録の**シェイカー版**表示。記録後は通常の達成猫に戻ること。
