# 達成の豪華演出リデザイン 設計書 (v1.2+)

**作成**: 2026-06-06
**状態**: 設計レビュー待ち

## ゴール
「達成の豪華さ」を**猫に乗せる装飾(シェイカー/王冠/頭上バッジ)を全廃**し、
**①背景の進化(A) ②達成の瞬間演出(B) ③メタリックな称号(C)** の3軸で表現する。
さらに**細かいペースで演出が用意される**よう、強度を3段に分けた reward cadence にする。

撤廃の理由: アイテムアートは猫種ごとに手・頭の形が違い、全11猫種で破綻する(共有スプライト不可・
猫種ごと全描き直しは生成コスト/トンマナ統一リスク大)。豪華さを**形非依存**の背景/瞬間/テキストに移す。

---

## 設計の背骨: 統一ランクラダー `CatRank`

バラバラだった段階(`CatDecoration` 5段 / `MilestoneBackground` 11段 / `MilestoneItem` 3段)を
**1本の11段ランク**に統一。基準は **累計達成日数 (lifetime achieved days)** = **単調増加・降格なし**
(休んでも称号は剥奪されない=アプリのやさしいトーンを守る)。

各ランクが **A背景の濃さ・C称号名・Cメタリック色** を同時に駆動する単一ソース。

| rank | 累計閾値 | 称号 | metal |
|---|---|---|---|
| 0 | 0 | (なし) | — |
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

**メタリック色の定義**(`MetalStyle`):
- bronze = `Color(red:0.80, green:0.52, blue:0.25)`
- silver = `Color(red:0.74, green:0.76, blue:0.80)`
- gold = `Color(red:1.00, green:0.80, blue:0.42)`(既存 MilestoneBackdrop の gold と一致)
- platinum = `Color(red:0.88, green:0.90, blue:0.96)`
- `+` / `-` サフィックス = 同系統の明度を ±8% した派生(同じ列挙で `brightnessStep` を持つ)。
- 虹 = 角度アニメする `AngularGradient`(reduceMotion で静止グラデ)。

`CatRank` は純ロジック(`init(totalAchievedDays:)` → rank / title / metal / richness)。テスト容易。
`richness = Double(rank)/11`(A背景用)。

---

## A. 背景の進化 (`MilestoneBackdrop` 強化)

現状(gold グラデ + RadialGradient グロー + sparkle + 最上位 光帯)を `CatRank` 駆動に。

- **色がランクで変わる**: 下地グラデを `rank.metal` 系統に寄せる(bronze帯は琥珀、silver帯は涼色寄り、
  gold/platinum で本命のゴールド→白金)。`richness` で濃さ。
- **粒子増加**: `sparkleCount = rank==0 ? 0 : min(3 + rank*2, 24)`。
- **時間帯トーン**: 朝/昼/夜で全体に淡いトーン(暖→昼白→紺)を 6% 程度かぶせる(`Calendar` の hour)。
- **最上位の光**: rank>=10 で光帯、rank==11(虹)でゴッドレイ + 虹のかすかな反射。
- すべて `allowsHitTesting(false)` / `accessibilityHidden`。reduceMotion で粒子/光帯を静止。

`MilestoneBackdropStyle` を `CatRank` ベースに作り替え(既存 `MilestoneBackground.tier` 依存を置換)。

---

## C. メタリックな称号 (`RankBadge`)

ホームの「○日連続」チップの**隣(または上)**に、称号バッジを置く。

- **見た目**: カプセル/ピル形。背景に `rank.metal` の LinearGradient + 細い金属フチ + 微 shadow。
  内部に称号テキスト(`Typography`)+ 小さなランクアイコン(SF Symbol、装飾なら accessibilityHidden)。
- **昇格アニメ**: ランクが上がった最初の表示で metallic **shimmer**(斜めハイライトが一度流れる)+ スケール pop。
- **連続チップ自体**は streak 数のまま(称号は累計基準で別物)。両者を並べて「連続◯日 / 称号」を併記。
- rank==0(7日未満)は称号バッジ非表示(新規ユーザーに空バッジを出さない)。
- VoiceOver: 「称号 みならいネコ」を読み上げ(装飾フチは hidden)。

`RankBadge(rank:)` を新規 View 化。HomeView の topStatusBar 付近に配置。

---

## B. 達成の瞬間演出 + 細かい cadence

既存の `MilestoneDetector` / `MilestoneCelebrationSheet` / `CelebrationLevel` / `CelebrationOverlay` /
`CelebrationCenter` を**温存し拡張**。演出を**強度3段**に分け、細かいペースで何かしら起きるようにする。

### 強度ラダー
1. **常時(ambient)** — A背景 + C称号バッジが累計で毎日少しずつ濃くなる。発火イベント不要。
2. **小節目(minor・割り込まない)** — フルシートを出さない**軽量オーバーレイ**:
   - **ランク昇格**(累計が `CatRank` の閾値を跨いだ時)
   - **週次**(連続が 7 の倍数、かつ大節目に未該当の時)
   → 画面上に **光のさざ波 + ハプティクス + 称号バッジの shimmer + 称号トースト**(上から短く降りて自動で消える)。
   `CelebrationCenter` に `fireLight()` を追加し、シート無しでオーバーレイ/ハプティクスだけ鳴らせるように。
3. **大節目(major・まれ)** — 既存 `MilestoneCelebrationSheet`(フルスクリーン)。発火点は現状維持
   (streak 10/30/50/100/200…・累計 100/365/500/1000・周年・減量 3/5/10kg)。文言/演出を微強化。

### 検出
- 大節目: 既存 `MilestoneDetector.nextPending(...)` をそのまま使用。
- ランク昇格(minor): 新規 `RankUpDetector`(累計達成日数の前回値を `UserDefaults` に保持し、
  跨いだランクを返す。大節目と同様 acknowledged 管理で二重発火を防ぐ)。週次も同方式。
- いずれも純ロジック + テスト。HomeViewModel が起動/記録後に評価して `home` に渡す。

### cadence の体感(例: 新規ユーザーの最初の100日)
7日でランク昇格演出+称号獲得 → 10日で大節目シート → 14日で昇格 → 21日で週次 →
30日で昇格+大節目 → 50/75 で昇格 → … と**1〜2週おきに必ず何か**が起きる。

---

## 撤去対象(掃除)

| 対象 | 種別 | 備考 |
|---|---|---|
| `MilestoneItem`(MilestoneStyle.swift) | dead code | shaker/crown 接尾辞ロジック |
| `cat_orange_waitingMorning_shaker/_crown` | asset×2 | 既に未使用 |
| `CatBreed.avatarAssetName(totalAchievedDays:)` | dead code | 唯一の MilestoneItem 消費元 |
| `MilestoneBackgroundView` + `bg_milestone_01〜11` | view + asset×11 | 例の「カード感チープ」画像背景。コード背景に置換済 |
| `MilestoneBackground.assetName` | dead code | bg_milestone 名生成。tier ロジックは CatRank へ移植後に enum 廃止 |
| `CatDecorationEmblem` + BigCatView の overlay/decoration | view + 配線 | 頭上バッジ撤廃 |
| `CatDecoration`(enum) | model | → `CatRank` に統合。FriendProfile.decoration / 関連テストを CatRank へ移行 |
| `MilestoneStyleTests` | test | MilestoneItem 部分を削除、CatRank テストへ |

`FriendProfile` は friend の称号表示に `CatRank` を使う(将来、友達一覧に称号を出せる土台)。

---

## データフロー
- 累計達成日数 = `HomeViewModel.lifetimeStats.achievedDays`(既存)。これが `CatRank` / A / C / RankUp の唯一の入力。
- 連続日数 = 既存 streak(B の大節目・週次にのみ使用)。

## テスト方針 (TDD)
- `CatRankTests`: 閾値境界(6/7/13/14/…/499/500)で rank/title/metal が正しいか。単調性。
- `RankUpDetectorTests`: 前回値→今回値で跨いだランクのみ返す。二重発火しない。週次。
- `MilestoneBackdropStyleTests`: CatRank 駆動後の richness/sparkle/animated を更新。
- 既存 `MilestoneDetectorTests` は不変(大節目ロジックは温存)。
- UI: swiftc 純ロジック検証 + simctl スクショで A/C/小節目演出を**検証チェックリスト**(別ファイル)に沿って3LLM採点。

## スコープ外 (YAGNI)
- D 殿堂(実績コレクション画面)— 今回見送り。
- weightLoss 節目の改変 — 既存のまま。
- 称号の友達一覧表示 — 土台のみ用意、画面追加は別途。
- 称号名の最終確定 — 案B採用済。微調整は実装中に可。

## 検証
別ファイル `2026-06-06-decoration-verification-checklist.md` をこの設計に合わせて更新し、
A(背景)/C(称号バッジ)/B(小節目演出)を 3LLM スクショ検証する。
