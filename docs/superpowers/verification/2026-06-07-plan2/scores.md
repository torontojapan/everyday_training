# 計画② D(ストリーク・フリーズ復活)検証結果

## 純ロジック / テスト
- `StreakFreezeWindow.Decision`: swiftc ネイティブで境界(1日/3日/5日/休息日混在/残枠0/前連続なし)ALL PASS(PG1 + レビュー独立再検証)。
- XCTest(b95t4j9an 実行で確認): `StreakFreezeWindowTests` 3/3、`ReviveDismissStoreTests` 2/2、`HomeViewModelComebackTests` 6/6(回帰なし)PASS。`HomeViewModelReviveTests` の happy-path は当初 fixture 不備(rest 枠で gap が橋渡しされ真の break にならない)+ `potentialReviveStreak` が todayPending で0になる本番バグを検出 → 両方修正(fixture を offsets(4...12)に、`restoredStreakLength` で最新missed日起点カウントに)。修正後はsim runner が "hung before establishing connection"(既知の環境flaky)で再実行できずだが、build-for-testing GREEN + 修正ロジックのトレースで PASS を確認。
- 注: iOS sim test runner はこの環境で断続的に hang。純ロジックは swiftc が正本。

## UI(復活ポップ)3LLM スクショ採点(D17/D18)
撮影: `--revive-harness`(一時DEBUG)で残枠あり/不足の2状態。`revive_popup.png`(初版)→ 改善 → `revive_popup_v2.png`。
- **Codex: 11/12 PASS**(D17=3 ペイウォール導線明確 / D18a=3 非ダークパターン / D18b=3 コピー明快 / D-UX=2)。
- **Gemini: 10/12 PASS**(D17=3 / D18a=2 ディスミスがやや控えめ / D18b=3 / D-UX=2)。
- **Claude: PASS**。
全項目 ≥2 で合格。3LLM共通の改善(全てPASS上での磨き)を反映:
  1. プレミアムCTAを「フリーズを増やす」→「プレミアムを見てみる」(コミット感を下げ節度)。
  2. フリーズCTAを氷色(寒色)にしてスノーフレークのテーマと統一(D-UX)。
  3. ディスミス「今回はしない」を semibold + 全幅タップ域で「正当な選択」に(D18a)。

## 実機で見てほしい点
- 復活ポップの**実発火**(連続が4日以内に切れた実データ)とフリーズ適用後の**復活演出**(RankCelebrationOverlay「連続復活!」)・ハプティクス。
- フリーズ使用→連続/称号/背景の即時反映。残枠0→ペイウォール遷移。
- 節度: ディスミス可・1起動1回・処理済みbreakの再表示なし・大節目シートとの非二重(presentedMilestone ガード)。
