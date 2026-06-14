# 猫キャラ画像 ビジュアル監査 (2026-06-14)

iOS `app/GOExercise/.../Assets.xcassets/CatCharacter/` の全110画像(11猫種 × ~10ポーズ)を
神経質に目視監査した結果。**見た目の正しさ**のみが対象(透過/コントラストは別項)。
方法: 各画像を中性グレー/マゼンタ/各テーマ背景に合成 → 11猫種を並列サブエージェントで精査 →
本体で再確認。Android(`app-android` の webp 110枚)は iOS と同一画なので**修正は両OSに反映必須**。

## A. 要再生成(Codex 画像生成)= 確定不具合 → **✅ 全6件 是正済(2026-06-14)**

| asset | 不具合 | 優先 | 是正方法 |
|---|---|---|---|
| `cat_silvertabby_encouraging` | **画風が別物**(他はチビ系ベクター調、これだけ厚塗り写実調)+ ヘッドバンドの肉球プリントが崩れ+縞が薄い | **高** | ✅ Codex 再生成(silver tabby チビ調・縞くっきり・cheering ポーズ) |
| `cat_persian_waitingMorning` | 目が**青**(他ポーズは銅/琥珀)+ 顔が尖りペルシャらしくない。**=アバター/ピッカー表示の正本ポーズ**ゆえ最も目立つ | **高** | ✅ **目のみ PIL recolor**(青アイリス→琥珀、輝度/彩度グラデ・キャッチライト温存)。顔は良好と判断し温存=キャラ完全保持。`/tmp/recolor_eyes.py` |
| `cat_persian_encouraging` | 目が青(銅/琥珀のはず)= 同一キャラが別猫に見える | 中 | ✅ 目のみ recolor(全画面走査・persian は目以外に青無し) |
| `cat_persian_streakExtended` | 目が青(同上) | 中 | ✅ 目のみ recolor(**目バンド領域限定**=紙吹雪の青を温存) |
| `cat_persian_happy3` | ピース手が崩れ(指が破綻) | 中 | ✅ Codex 再生成(ピース2指くっきり・黒衣装/銅目維持・1024 化) |
| `cat_orange_beggingNight` | 祈り手が融合してブロブ化(指の分離なし) | 中 | ✅ Codex 再生成 v2(祈り手の肉球分離・**黒衣装の橙アクセント**を再指定で v1 の橙過多を是正) |

**所見**: 青目3件は全身再生成より **PIL の局所 recolor が安全**(良好なキャラ/衣装/毛並みを完全保持し目だけ修正)。構造破綻3件(画風/指/融合手)は Codex 再生成。全件 iOS png(1024 or 1254)+ Android webp(lossy q80)へ反映。各テーマ背景に合成して透過/コントラスト/画風を拡大目視確認済([[feedback-visual-selfcheck]])。Codex 再生成は衣装ドリフト(橙過多)が出るため参照画像 + 明示制約 + 1発再試行で収束。

**再生成手順** = memory [[codex-image-generation]]:
1. Codex CLI で参照画像(同猫種の正常ポーズ)を `-i` 指定し、同画風・同ポーズで再生成。
2. `/tmp/transparentize.py` 型で外周白を透過(PIL flood-fill)。
3. iOS: `*.imageset/*.png` を差し替え。Android: PIL `Image.save(p,'WEBP')` で webp 化し `app-android/.../res` or assets の対応 `cat_<breed>_<pose>.webp` を差し替え(sips は webp 非対応)。
4. 差し替え後、本セッションの監査スクリプト(下記)で再確認。
⚠️ Codex usage limit に注意(本日 15:43 リセット済)。背景 watchdog で回す。

## B. 要ユーザー判断

1. **内耳の色**: orange/black/gray 猫種は内耳が**オレンジ/濃グレー**で**ピンクでない**が、各猫種内で**一貫**=ブランド配色の意図的選択の可能性大(white/calico/siamese/browntabby/silvertabby はピンク)。「全猫種ピンク内耳」に統一したいなら orange/black/gray の該当ポーズを再生成/recolor。**現状は不具合と断定しない**。
2. **「白猫の耳が黒い」報告 → ✅ 実在不具合だった(2026-06-14 ユーザー指摘で再監査・当初の「黒耳無し」判定は誤り)**: `cat_white_happy3`(共有カードのハッピーポーズの1つ)が**左耳に黒い内耳パッチ+黒い房**を持っていた(他ポーズはピンク内耳)。Codex 再生成でピンク内耳・黒なしに是正済。
   - **付随で判明した白猫の系統的不具合 = 頭上の灰色 wisp**: 白猫の高エネルギーポーズ(celebrating/happy2/streakExtended/waitingMorning/worriedNoon/beggingNight/encouraging/shaker)は、頭の上〜耳の間に**不透明の薄い灰色のフワフワした筆ストローク(ラフ線の残り)**があり、有色背景(共有カードの青グラデ等)で**「透過ミス」のような灰色ヘイズ**に見える(透過自体は健全=不透明な明色画素なので alpha 閾値では消せない・耳と空間的に絡むので領域クリップも危険)。orange/persian は ~300px と少なく白猫特有(明色毛+ラフ線が目立つ)。**是正=Codex 再生成時に「頭上は完全に空・loose fur strand / sketch stroke を描くな」と明示**で wisp が 2500→300 に激減。
   - **共有カード3ポーズ(celebrating/happy2/happy3)は是正済**。残り6ポーズ(beggingNight/encouraging/streakExtended/waitingMorning/_shaker/worriedNoon)はホーム等で表示=同手法で要再生成(scope 判断)。
3. **背景コントラスト**(別不具合): **白猫が明るいテーマ(peach/sky/sunshine/forest)で背景に溶ける**(頭の輪郭が消える=「透過ミス」に見える)/ **黒猫・ハチワレが midnight(暗)テーマで消える**。原因=猫と同トーン背景の分離不足。
   - 提案修正: 猫キャラに**背景適応の細い縁取り/ソフトシャドウ**を付け、どの背景でも輪郭が立つようにする(共有 modifier 化)。対象 = `BigCatView`(HomeView)/`CatStateView`/`UserCatPickerView`(241/270行 scaledToFill+clipShape(Circle))/`FriendAvatarView`/`FriendsParkView`。
   - 付随: `UserCatPickerView`/`CatStateView` は `scaledToFill + scaleEffect + clipShape(Circle)` で**耳/ヘッドバンドのリボンが円で切れる**。`BigCatView` 同様 `scaledToFit` 寄りにすると頭切れ解消。

## C. 軽微(様子見)

- `cat_orange_celebrating` 前腕に他ポーズに無いリストバンド+袖に余分な肉球(低)
- `cat_white_happy2`/`happy3` ヘッドバンドの肉球プリントが薄い/白い(低)
- `cat_black_waitingMorning(_shaker)` 目が他ポーズより大きく明るい(画風ゆれ・低)
- `cat_persian` は青目3ポーズ以外は銅目で良好

## D. 問題なしと確認した猫種(ship可)

calico / siamese / browntabby / tuxedo / scottish(全ポーズ良好)。black/gray/white/orange は上記の個別/内耳項目を除き良好。

## 監査スクリプトの要点(次回再現用)
- 全PNG列挙: `find app/GOExercise/GOExercise/Resources/Assets.xcassets/CatCharacter -name "*.png"`
- 猫種別コンタクトシート: 各 `cat_<breed>_*` を中性グレー背景に並べる(PIL)。
- 背景組合せ matrix: 11猫種 × 5テーマ背景(peach 255,247,237 / sky 240,247,255 / midnight 26,28,36 / sunshine 255,250,230 / forest 242,247,237)。
- 透過ホール検出: 境界からの BFS で「外周到達不能な alpha<16」=内部ホール / 「外周接触の opaque near-white」=背景残り。
- **結論: アセットの透過自体は健全**(マゼンタ1:1頭部ズームでホール/ハロー無し)。問題は B の画風/目色/コントラストと A の個別崩れ。
