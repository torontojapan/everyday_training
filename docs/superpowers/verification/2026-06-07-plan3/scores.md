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

## 最終再検証(コミット済みアセットに対して・gray修正後)
3LLM を**コミット済みの最終セット**(gray=v2)で再採点:
- **Codex: PASS(ship set)** — gray 3/3/3/3 に改善、exclude なし、全 breed ≥11/12。
- **Gemini: 9/12** — white と persian の除外を主張。だが具体指摘を直接検証した結果:
  - white「ヘッドバンドに青い肉球」= 実際は**オレンジの肉球**で、青はこの白猫の**青い目**の誤読(コンタクトシート縮小由来)。
  - white「左足に透過欠け」= グレー背景で確認したが**透過穴なし・靴は中実**。
  - persian「style drift」= ペルシャ本来の**もふもふ・平face**で breed 的に正しい(両LLMとも coloring 3/3)。
- Claude(自分)が**全11種を full-res で個別確認**(silvertabby/browntabby を含む)→ 柄正確・透過クリーン・青滲み無し・座り+シェイカー保持。
- 唯一の実欠陥(gray v1=立ちポーズ+シェイカー無し)は検出して再生成済み。
→ 結論: **全11種で出荷可**(Codex PASS + 直接検証で Gemini の white 指摘は事実誤認、persian は breed 正常)。
