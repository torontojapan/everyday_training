# 紹介リワード(ホームスター + 猫解放)& 設定リデザイン 設計

- 作成日: 2026-06-06
- 対象: GOエクササイズ(iOS 先行 / Android 後追い)
- 前提: 友達紹介(リファラル)実装済([[friend-referral-design]]、`referralStore.summary.starBadges` = サーバの confirmed 紹介数)。達成装飾①・猫種課金②も実装済。
- バージョン: v1.2(v1.1 = 装飾/猫種/紹介 の次)
- 関連ブランチ: `feature/referral-rewards-v12`(iOS v1.1 = feature/achievement-decorations の上)

## 0. ゴールと非ゴール
- **ゴール**: 紹介の成果(星)をホームで可視化して「集めたくなる」体験にし、10個で猫種を無料解放する報酬を足す。あわせて散らかった設定画面を整理し、無料特典をまとめて説明する。
- **非ゴール**: Supabase スキーマ変更(星は既存 confirmed 件数から算出)。Android 実装(本書は設計のみ・実装は iOS 先行、Android は後追いフェーズ)。新しい課金商品の追加。

---

# Part 1: ホームの紹介スター + 10個で猫解放

## 1.1 ホームのスター行
**配置(2026-06-07 改訂)**: `HomeView` 上部を 3 行構成にする。
- 1〜2 行目 = `topStatusBar`: **左 = 連続記録バッジ(縦に伸ばして 2 行ぶんの高さ)** / **右上 = 称号バッジ・右下 = 今日は達成済み(右詰め 2 段)**。
- 3 行目 = **紹介スター行(全幅)**。称号と分離したので最大 10 星が折り返さず一直線に並ぶ。
- スターは**友達を紹介して⭐が 1 個以上付いて初めて表示**する。0 個のときは行ごと非表示(ゴースト星は出さない)。

**表示ロジック(純関数・テスト可能)**: `ReferralStarsDisplay.style(count: Int) -> Style`
```
enum Style {
    case ghost                 // 0個: ホームでは非表示(enum は境界網羅のため残す)
    case progress(filled: Int, total: 10)  // 1〜9個: 金星 filled + 枠星 (10-filled)
    case complete              // 10個: 金星 ×10(解放達成)
    case collapsed(Int)        // 11個以上: 「⭐ N」
}
```
- **0個**: **ホームには何も出さない**(`referralStarsFullRow` を描画しない)。星は友達を紹介して初めて付く仕組みなので、0 個でのゴースト星や勧誘はホームに置かない。仕組みの説明は設定画面の「無料特典・達成ガイド」に記載(§2.3)。
- **1〜9個**: 金の星 ⭐ を count 個 + 残りを薄い枠星で**10個まで**一直線に並べる(進捗が一目で分かる=10を目指したくなる)。
- **10個**: ⭐×10 全点灯(解放状態)。
- **11個以上**: 「**⭐ N**」に省略(個別の星は出さない)。
- 補助テキスト(小さく): `1 ≤ count < 10` のとき**星の下段**に `あと{10-count}人で猫が解放`(横に置くと星が折り返すため下に配置)。10以上では出さない。

**スタイル**: 金星 = `Palette` のアクセント(例 amber/gold 系)、枠星 = `Palette.textSecondary.opacity(~0.3)`。サイズは `topStatusBar` の chip と調和する小ぶり(~16-18pt)。

**タップ**: 行(星)全体をタップ → **招待の共有シート**(`friend_code` を含む招待文を `ShareLink`/`UIActivityViewController` 経由で共有)。設定の招待文と同一文面を再利用。

**0個時の扱い(2026-06-07 改訂)**: **行ごと非表示**。`referralStarsFullRow` は `AppFeatureFlags.isReferralActive` かつサインイン済みかつ `starBadges > 0` のときだけ描画する。友達を紹介して⭐が付いて初めてホームに現れる(0 個での勧誘表示はしない)。未サインイン/紹介無効時も当然非表示。

## 1.2 10個の報酬: 好きな猫種を無料解放
**閾値**: `ReferralReward.breedUnlockThreshold = 10`。`referralBreedUnlocked = (starBadges >= 10)`(累計なので一度10で恒久解放)。

**ロック判定の拡張(純関数)**: `CatBreedAccess.isLocked` に引数追加
```
static func isLocked(_ breed: CatBreed, current: CatBreed, isPremium: Bool, referralUnlocked: Bool) -> Bool {
    !isPremium && !referralUnlocked && breed != current
}
```
- 既存呼び出し互換のため `referralUnlocked: Bool = false` のデフォルトを付ける。
- `UserCatPickerView` は `referralUnlocked: referralStore.summary.starBadges >= ReferralReward.breedUnlockThreshold` を渡す。これで星10以上なら全猫種のロックが外れる(プレミアム相当の猫選びが無料)。

**到達演出**: 星が初めて10に達した瞬間に**お祝いポップ**(「⭐10達成!好きな猫が無料で選べるようになったよ」)。実装はポップ表示の重複を避けるため、**未表示フラグをローカル(UserDefaults)に持つ**(`referral.breedUnlockCelebrated.v1`)。サーバ確定→星更新時、未祝いかつ閾値到達なら1回だけ表示。

**収益への影響(明示の意思決定)**: 猫選びはプレミアム価値の一部。10紹介での無料解放は十分ハードルが高く、口コミ拡散の対価として健全。意図的な成長施策として採用する(ユーザー承認済 2026-06-06)。

## 1.3 データ
- 元データ = 既存 `referralStore.summary.starBadges`(StateFlow/Observable)。スキーマ変更ゼロ。
- 起動時・確定時に `referralStore.refresh()` で更新済み(既存の仕組みを流用)。

---

# Part 2: 設定リデザイン + 無料特典ガイド

## 2.1 現状の課題
セクションが約13個に断片化(単独項目セクション多数)、並びに脈絡がなく、デフォルトのスクロールが長い。

## 2.2 新しい情報設計(13 → 6グループ)
上から:

**① プレミアム & 特典**
- GOプレミアム カード(加入中 / アップグレード)
- 🎁 **無料特典・達成ガイド**(折りたたみ・既定は閉)← 新規(§2.3)
- 友達を招待(共有 + ⭐紹介数 + 後から入力。既存の Part 1 と動線統一)

**② カスタマイズ**
- テーマカラー / 自分のキャラを変更 / 達成時の振動

**③ 記録 & 共有**
- 体調・周期を記録する / 自動休養日 / 友達と共有する情報(詳細共有トグル)

**④ 通知 & ウィジェット**
- 通知設定 / ホーム画面ウィジェットの追加方法

**⑤ データ & プライバシー**
- データを書き出す / すべての記録を削除 / 利用状況の分析を共有

**⑥ 情報・サポート**(末尾・折りたたみ既定閉)
- フィードバック(ご意見/不具合)/ サブスクリプション管理 / プライバシーポリシー / 利用規約 / サポート

> 既存の各設定項目の**機能・遷移先・トグルのバインディングは一切変えない**。グルーピングと並び順、見出し、折りたたみだけを再構成する(リスク最小)。

## 2.3 無料特典・達成ガイド(折りたたみ)
`DisclosureGroup`(既定は閉=スクロールを増やさない)。見出し「🎁 無料でもらえる特典・達成」。開くと箇条書き:
- **連続記録フリーズ**: 無料=月1 / プレミアム=月4 / 友達紹介で +1(上限5)/ 招待された人はウェルカム +1
- **友達紹介**: 1人紹介ごとに ⭐ + フリーズ。**⭐10個で好きな猫が無料解放**。⭐は**友達を紹介して初めて付く**(0人のうちはホームに星行は出ない=この設定ガイドが仕組みの説明場所)。
- **達成装飾**: 累計日数で背景が進化(30日 シェイカー・100日 王冠)
- **猫種**: 無料=オレンジ / プレミアム or ⭐10 で全11種
- **連続記録マイルストーン**: 節目で演出

文言は将来の特典追加で増やせるよう、**1つの配列データ**(`PerkGuideItem` のリスト)から描画する。

## 2.4 スクロール削減の手段
- セクション 13→6(単独項目を統合)。
- 「特典ガイド」「情報・サポート」を `DisclosureGroup` 既定閉に。
- 見出し・余白・カード(Surface)スタイルを統一しシンプルに。

---

## 3. コンポーネント分割(isolation)
- `ReferralStarsDisplay`(純ロジック・enum 返し): count → 表示モード。単体テスト対象。
- `ReferralStarsRow`(SwiftUI View): `ReferralStarsDisplay` を描画 + タップで共有。HomeView から使用。
- `ReferralReward`(定数 + `breedUnlockThreshold` + `isBreedUnlocked(starBadges:)`): 純ロジック。
- `CatBreedAccess.isLocked(...referralUnlocked:)`: 既存純関数の引数拡張。
- 設定: `PerkGuideItem`(データ)+ `PerkGuideSection`(折りたたみ View)。`SettingsView` の body をグループ単位の小さな private View(`SettingsSectionXxx`)に再構成。

## 4. テスト
- 純ロジックはネイティブ `swiftc` 実行 + XCTest コンパイルゲート(iOSはシミュレータのテストランナーがハングするため)。
  - `ReferralStarsDisplay.style(count:)`: 0/1/5/9/10/11/25 の各境界。
  - `ReferralReward.isBreedUnlocked`: 9=false / 10=true / 11=true。
  - `CatBreedAccess.isLocked(...referralUnlocked:)`: premium / referralUnlocked / current の組合せ。
- UI/設定再編は `xcodebuild build` で検証。

## 5. 実装順(iOS)
1. 純ロジック(ReferralStarsDisplay / ReferralReward / CatBreedAccess 拡張)+ テスト。
2. ホームのスター行 + タップ共有。
3. 猫解放(UserCatPickerView 配線)+ 10到達お祝いポップ。
4. 設定リデザイン(6グループ再構成)。
5. 無料特典ガイド(折りたたみ)。
6. 統合ビルド + 検証。

## 6. オープン事項
- 金星の正確な色トークン(`Palette` の既存アクセント色を流用。無ければ amber を追加)。
- お祝いポップは既存 `ReferralCelebrationSheet` を拡張(role に `.breedUnlock` 追加)か新規かは実装計画で決定。
- Android パリティは別フェーズ(本書スコープ外)。
