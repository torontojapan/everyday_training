# 達成の豪華演出リデザイン 設計書 (v1.2+)

**作成**: 2026-06-06 / **改訂**: 2026-06-06(連続ベース＋フリーズ復活を反映)
**状態**: 設計レビュー待ち

## ゴール
「達成の豪華さ」を**猫に乗せる装飾(シェイカー/王冠/頭上バッジ)を全廃**し、
**①背景の進化(A) ②達成の瞬間演出(B) ③メタリックな称号(C)** の3軸で表現する。
**細かいペースで演出が用意される**よう強度を3段に分け、さらに
**④連続が途切れても4日以内はフリーズ(課金)で復活できる導線(D)** と
**⑤運動記録の前後に出る全猫種シェイカー版フレーバー(E)** を足す。

撤廃理由: アイテムアートは猫種ごとに手・頭の形が違い全11猫種で破綻する(共有スプライト不可・
全描き直しは生成コスト/トンマナ統一リスク大)。豪華さを**形非依存**の背景/瞬間/テキストへ移す。

---

## 設計の背骨: 統一ランクラダー `CatRank`(連続ベース)

段階(`CatDecoration` 5段 / `MilestoneBackground` 11段 / `MilestoneItem` 3段)を **1本の11段ランク**に統一。

**基準 = 現在の連続日数(current streak)。連続が途切れたらランクもリセット(降格)する。**
連続は既存 `StreakCalculator` が算出し、**休息日(restLimit:2)とフリーズ(rescuedDates)で橋渡し済み**の値。
→ フリーズで連続が保たれていればランクも保たれる。途切れて再度登り直せば称号は**再獲得＋昇格演出も再発火**(=細かいペースに合致)。

各ランクが **A背景の濃さ・C称号名・Cメタリック色** を同時に駆動する単一ソース。

| rank | 連続閾値 | 称号 | metal |
|---|---|---|---|
| 0 | 0–6 | (なし) | — |
| 1 | 7 | みならいネコ | bronze |
| 2 | 14 | かけだしネコ | bronze+ |
| 3 | 30 | がんばりネコ | silver |
| 4 | 50 | まいにちネコ | silver+ |
| 5 | 75 | きたえネコ | gold- |
| 6 | 100 | つわものネコ | gold |
| 7 | 150 | ベテランネコ | gold |
| 8 | 200 | 達人ネコ | gold+ |
| 9 | 300 | 仙人ネコ | gold+ |
| 10 | 365 | レジェンドネコ | platinum |
| 11 | 500 | ぬしネコ | 虹 (rainbow) |

**メタリック色 `MetalStyle`**: bronze=`(0.80,0.52,0.25)` / silver=`(0.74,0.76,0.80)` /
gold=`(1.00,0.80,0.42)`(既存 backdrop と一致) / platinum=`(0.88,0.90,0.96)`。
`+`/`-` = 同系統 ±8% 明度。虹 = 角度アニメ `AngularGradient`(reduceMotion で静止)。

`CatRank(currentStreak:)` は純ロジック → rank/title/metal/richness(`=rank/11`)。テスト容易。

---

## A. 背景の進化 (`MilestoneBackdrop` 強化・連続駆動)

現状(gold グラデ + RadialGradient グロー + sparkle + 最上位 光帯)を `CatRank` 駆動に。

- **色がランクで変わる**: 下地グラデを `rank.metal` 系統に(bronze帯=琥珀 / silver帯=涼色 / gold→platinum で本命)。`richness` で濃さ。
- **粒子**: `sparkleCount = rank==0 ? 0 : min(3 + rank*2, 24)`。
- **時間帯トーン**: 朝/昼/夜で全体に淡いトーン(暖→昼白→紺)を ~6% かぶせる(`Calendar` hour)。
- **最上位の光**: rank>=10 で光帯、rank==11 でゴッドレイ+虹の微反射。
- **連続リセット時**: 連続が途切れると rank が落ち、背景も淡くなる(=連続を守る動機)。**ただし D の4日グレース内にフリーズ復活すれば即座に戻る。**
- `allowsHitTesting(false)` / `accessibilityHidden`、reduceMotion で粒子/光帯を静止。

`MilestoneBackdropStyle` を `CatRank` ベースに作り替え(`MilestoneBackground.tier` 依存を置換)。

---

## C. メタリックな称号 (`RankBadge`)

「○日連続」チップの**隣**に称号バッジを置く。

- **見た目**: カプセル形。`rank.metal` の LinearGradient + 細い金属フチ + 微 shadow。称号テキスト + 小ランクアイコン(SF Symbol、accessibilityHidden)。
- **昇格アニメ**: ランク上昇後の初表示で metallic **shimmer**(斜めハイライトが一度流れる)+ スケール pop。
- 連続チップは streak 数のまま。称号バッジと並べて「連続◯日 / 称号」を併記(同じ連続基準なので一貫)。
- rank==0(連続7日未満)は称号バッジ非表示。
- VoiceOver: 「称号 みならいネコ」を読み上げ。

`RankBadge(rank:)` 新規 View。HomeView topStatusBar 付近に配置。

---

## B. 達成の瞬間演出 + 細かい cadence

既存 `MilestoneDetector` / `MilestoneCelebrationSheet` / `CelebrationLevel` / `CelebrationOverlay` /
`CelebrationCenter` を**温存・拡張**。演出を**強度3段**に。

### 強度ラダー
1. **常時(ambient)** — A背景 + C称号が連続で日々濃くなる。発火不要。
2. **小節目(minor・割り込まない)** — フルシート無しの**軽量オーバーレイ**:
   - **ランク昇格**(連続が `CatRank` 閾値を跨いだ時)
   - **週次**(連続が 7 の倍数 かつ 大節目に未該当)
   → **光のさざ波 + ハプティクス + 称号 shimmer + 称号トースト**(上から短く降りて自動で消える)。
   `CelebrationCenter.fireLight()` を追加(シート無しでオーバーレイ/ハプティクスのみ)。
3. **大節目(major・まれ)** — 既存 `MilestoneCelebrationSheet`。発火点は現状維持(streak 10/30/50/100/200…・累計 100/365/500/1000・周年・減量 3/5/10kg)。
   **coordination**: 同日に大節目シートが出る時は同イベントの小節目オーバーレイを抑止(二重演出防止)。

### 検出
- 大節目: 既存 `MilestoneDetector.nextPending(...)`。
- ランク昇格(minor): 新規 `RankUpDetector`(前回 rank を `UserDefaults` 保持、上昇分を返す。**リセット後の再上昇でも再発火**。週次も同方式)。
- 純ロジック + テスト。HomeViewModel が起動/記録後に評価。

---

## D. ストリーク・フリーズ復活(4日グレース + ポップ導線)【新規・収益化】

**フリーズ自体は既存** (`RescueTicketStore`):月次付与(無料 1/月・プレミアム 4/月・+紹介ボーナス・上限5)、
フリーズした日は `rescuedDates()` として連続を橋渡し。¥1,000 消耗型IAPは廃止済み。
→ **新規実装は「途切れ後4日以内の復活グレース + ポップ導線」のみ。**

### 仕組み
- **検出 `StreakFreezeWindow`(新規・純ロジック)**: records / today / rescuedDates / 連続 から、
  「直近4日以内に**フリーズで橋渡しすれば連続が復活する** missed 日」を特定。
  復活に必要なフリーズ枚数(=連続を切った missed 日数)と、現在の残枠を返す。
  4日を過ぎた missed 日は対象外(復活不可で確定)。
- **ポップ `StreakRevivePopup`**: window が有効かつ未消化の時にホームで提示。
  - コピー: 「連続◯日が途切れそう。フリーズで守れます(残り X)」
  - **残枠 ≥ 必要枚数** → 「フリーズを使う」→ `RescueTicketStore.useTicket` を missed 日に適用 →
    連続・称号・背景が**即復活** + 復活演出(B の軽量オーバーレイを流用)。
  - **残枠 < 必要枚数(無料枠切れ等)** → 「プレミアムで月4回フリーズ」→ 既存 `PremiumPaywallSheet` へ。
- **収益化ゲート**: 無料枠(1/月)で復活可。**枠切れで `PremiumPaywallSheet` へ**(決定済)。
- **節度(ダークパターン回避)**: ポップは**ディスミス可**・**1起動につき最大1回**・4日経過で自動失効・
  復活 or 「今回はしない」で当該 break について再表示しない。連続の損失を煽りすぎない穏やかなコピー。

### 検出の純ロジック方針
`StreakFreezeWindow.evaluate(records:today:rescuedDates:remainingFreezes:lookback:4)` →
`(revivable: Bool, missedDates: [Date], freezesNeeded: Int, hasEnough: Bool)`。テスト必須(境界=4日目/5日目、複数日 missed、休息日混在、残枠0)。

---

## E. シェイカー猫フレーバー(運動記録の前後)【新規アセット・達成段階と無関係】

「ごほうび装飾」ではなく、運動の文脈で出る**フレーバー演出**。達成段階(CatRank)とは無関係に誰でも出る。

- **アセット**: 全11猫種に `cat_<breed>_waitingMorning_shaker` を1枚ずつ(プロテインシェイカーを持つ待機ポーズ)。
  既存 `cat_orange_waitingMorning_shaker` を**流用**し、他10猫種を **Codex 生成**。
- **品質ガード(過去の失敗を繰り返さない)**: 各 state 単一画像の画風・線・塗りに合わせ、確立済みの
  **flood-fill 透過パイプライン**で背景透過。**青色滲み・他猫種とのスタイル不一致**(以前 variant を一掃した原因)を
  **3LLM トンマナ検証**で排除してからマージ。
- **表示タイミング = 運動記録の前後**:
  - **記録直後**: `RecordCompletionView` のヒーロー猫をシェイカー版に(「お疲れさま・補給!」)。
  - **これから運動(前)**: ホームの**今日まだ未記録**の待機文脈でシェイカー版を出す(「補給して頑張ろう」)。
  - フォールバック: 当該猫種のシェイカー画像が無ければ通常 `waitingMorning`(または orange shaker)。**画像欠落で破綻しない。**
- **解決ロジック**: `CatBreed.shakerAssetName`(新規・純プロパティ)+ `UIImage(named:)` 存在チェック→フォールバック。
- **テスト**: 全11猫種で asset 名が規約通り / 欠落時フォールバックが効く。

---

## 撤去対象(掃除)

| 対象 | 種別 | 備考 |
|---|---|---|
| `MilestoneItem`(MilestoneStyle.swift) | dead code | shaker/crown 接尾辞 |
| `cat_orange_waitingMorning_crown` | asset×1 | 王冠マイルストーンアイテム廃止で削除 |
| `cat_orange_waitingMorning_shaker` | **保持** | 削除せず E のシェイカーセットの種として流用 |
| `CatBreed.avatarAssetName(totalAchievedDays:)` | dead code | 唯一の MilestoneItem 消費元(E は別解決パス `shakerAssetName`) |
| `MilestoneBackgroundView` + `bg_milestone_01〜11` | view + asset×11 | チープな画像背景。コード背景に置換済 |
| `MilestoneBackground`(assetName/tier) | model | tier ロジックは `CatRank` へ移植後に enum 廃止 |
| `CatDecorationEmblem` + BigCatView overlay/decoration | view + 配線 | 頭上バッジ撤廃 |
| `CatDecoration`(enum) | model | → `CatRank` に統合。`FriendProfile.decoration` / 関連テストを `CatRank` へ移行 |
| `MilestoneStyleTests` | test | MilestoneItem 部分を削除、`CatRank` テストへ |

`FriendProfile` は friend の称号表示に `CatRank` を使う(将来 友達一覧に称号を出す土台)。

---

## データフロー
- **入力 = 現在の連続日数**(`StreakCalculator.currentStreak`、rescuedDates/休息日で橋渡し済)。
  これが `CatRank` / A / C / RankUp の唯一の入力。
- フリーズ残枠 = `RescueTicketStore.remainingTickets(today:allowance:)`(D で使用)。
- 大節目(B major)・週次は従来通り連続/累計/周年/体重。

## テスト方針 (TDD)
- `CatRankTests`: 連続の閾値境界(6/7/13/14/…/499/500)で rank/title/metal、リセット(連続0→rank0)。
- `RankUpDetectorTests`: 上昇分のみ返す。リセット後の再上昇で再発火。週次。
- `StreakFreezeWindowTests`: 4日境界・複数日 missed・休息日混在・残枠0・復活後。
- `MilestoneBackdropStyleTests`: `CatRank` 駆動後の richness/sparkle/animated を更新。
- 既存 `MilestoneDetectorTests` は不変(大節目ロジック温存)。
- UI: swiftc 純ロジック + simctl スクショで A/C/小節目/ポップを**検証チェックリスト**に沿い 3LLM 採点。

## スコープ外 (YAGNI)
- D 殿堂(実績コレクション画面)— 見送り。
- weightLoss 節目の改変 — 既存のまま。
- フリーズ消耗型IAPの復活 — しない(月次枠＋プレミアム導線のみ)。
- 称号名の最終確定 — 案B(ねこ仕立て)採用済。微調整は実装中に可。

## 検証
別ファイル `2026-06-06-decoration-verification-checklist.md` をこの設計に更新し、
A(背景)/C(称号バッジ)/B(小節目)/D(復活ポップ)/E(シェイカー版・全猫種トンマナ) を 3LLM スクショ検証する。
