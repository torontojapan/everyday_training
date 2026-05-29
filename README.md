# GO エクササイズ (GO Exercise)

猫キャラクターと一緒に毎日1分から運動を習慣化する iOS アプリ。

App: SwiftUI / SwiftData / WidgetKit / Swift Charts (iOS 17+)
Pages: [https://torontojapan.github.io/everyday_training/](https://torontojapan.github.io/everyday_training/)
要件: [`specs/requirements_v1.md`](specs/requirements_v1.md)

## 主要機能

- 運動記録 (6 カテゴリ: 有酸素 / 筋トレ / ヨガ / ストレッチ / 筋膜リリース / その他)
- 連続記録 (休養日スキップ、達成日のみカウント) + 週間 / 月間カレンダー
- 累計運動日数 / 利用日数
- 通知 (1日2回ローカル通知) + ホーム画面ウィジェット (Small / Medium)
- 12 ポーズの猫キャラ (オレンジトラ猫のスポーティーキャラ、状態×日付で daily rotation) + 累計達成日数に応じた装飾 (バンダナ→王冠)
- 連続記録シェア画面 (SNS / 写真保存)
- 月次レビュー (前月サマリーカード + シェア)
- 記念日演出 (1周年 / 100日連続等) + 4 段階祝祭 (subtle / standard / heroic / legendary)
- CoreHaptics 多層パターン (設定で ON/OFF)
- 保険チケット (月 1 枚、体調・周期 ON で 2 枚) + カレンダー UI から日付選択
- 体重管理 (記録 + 推移グラフ)
- 体調・周期記録 (オプトイン、生理日に履歴カレンダーで ★)
- 5 テーマカラー (peach / sky / midnight / sunshine / forest)
- **友達と共有** (友達コード / QR / ユーザー名検索、連続記録 + 今日のメニュー共有、4 種スタンプ応援、友達詳細シートで週カレンダー / 装飾ランク / 最終更新時刻も確認)
- **詳細共有 opt-in** (回数・時間・セット数も友達と共有可能、デフォルトは種目名のみ)
- **週間ランキング** (友達 + 自分を連続日数 → 運動時間で順位表示、金銀銅メダル + 自分の順位サマリー)

## ディレクトリ構成

```
serial_training/
├── README.md                  ← このファイル (リポジトリの地図)
├── NEXT_STEPS.md              ← 残タスク・優先順位
├── MEMORY.md                  ← プロジェクトメモ (担当 Claude 用)
│
├── app/GOExercise/        ← iOS アプリ本体 (SwiftUI / iOS 17+)
│   ├── project.yml              xcodegen 設定 (.xcodeproj はここから生成)
│   ├── GOExercise/          アプリ本体
│   │   ├── App/                   エントリポイント
│   │   ├── Models/                SwiftData モデル + 構造体
│   │   ├── Views/                 SwiftUI 画面
│   │   ├── ViewModels/            画面ロジック
│   │   ├── Services/              永続化・通知・友達などのサービス層
│   │   ├── Theme/                 5 テーマカラー定義
│   │   └── Resources/
│   │       ├── Assets.xcassets/
│   │       │   ├── CatCharacter/  ★ 猫キャラ素材 (77 imageset、柄 × ムード)
│   │       │   ├── AppIcon.appiconset/
│   │       │   └── AccentColor.colorset/
│   │       ├── Info.plist
│   │       └── *.strings          ローカライズ
│   ├── GOExerciseTests/     ユニットテスト (186 件)
│   ├── GOExerciseUITests/   UI テスト (14 件)
│   └── GOExerciseWidget/    ホーム画面ウィジェット
│
├── specs/
│   └── requirements_v1.md     ← 要件定義書
│
├── docs/                      ← GitHub Pages (https://torontojapan.github.io/everyday_training/)
│   ├── index.md                 ランディング
│   ├── privacy.md / terms.md / support.md
│   ├── _config.yml              Jekyll 設定
│   └── ux_review/               UX レビュー (Claude / Codex / Gemini 横断比較)
│
├── submission/                ← App Store 提出パッケージ
│   ├── README.md                提出フロー手順
│   ├── app_store_metadata.md    申請メタデータ (説明文・キーワード等)
│   ├── PrivacyPolicy.md / TermsOfService.md
│   └── screenshots/
│       ├── iphone-6.9/          ★ 6.9" 提出スクショ (iPhone 17 Pro Max)
│       ├── iphone-6.7/          ★ 6.7" 提出スクショ
│       ├── ipad-13/             ★ iPad 13" 提出スクショ
│       └── _archive/            過去フェーズの開発スクショ (履歴保管用)
│
└── .github/workflows/         ← CI (ios-ci.yml)
```

### よく聞かれる「どこにある？」

| 探しもの | 場所 |
|---|---|
| **猫キャラの画像** | `app/GOExercise/GOExercise/Resources/Assets.xcassets/CatCharacter/` |
| アプリアイコン | `app/GOExercise/GOExercise/Resources/Assets.xcassets/AppIcon.appiconset/` |
| 画面の SwiftUI コード | `app/GOExercise/GOExercise/Views/` |
| データモデル (SwiftData) | `app/GOExercise/GOExercise/Models/` |
| App Store 提出用スクショ | `submission/screenshots/iphone-6.9/` `iphone-6.7/` `ipad-13/` |
| プライバシーポリシー (公開版) | `docs/privacy.md` (GitHub Pages 経由で公開) |
| プライバシーポリシー (申請用) | `submission/PrivacyPolicy.md` |
| 要件定義 | `specs/requirements_v1.md` |

## フェーズ

| Phase | 内容 |
|---|---|
| 1 | MVPコア (ホーム/記録/連続記録/週間達成率/休養日) |
| 2 | 習慣化体験 (通知/Widget/猫キャラ演出) |
| 3 | 改善 (履歴/通知設定/UIブラッシュアップ) |
| 3.5 | UI/UX 中優先項目 (ホーム余白、iPad、ハプティクス、Reduce Motion) |
| 3.6 | 細かい改善 (種目候補/秒削除/保存後 bug/曜日タップ) |
| 3.7 | 連続記録ロジック改修 + シェア画面 |
| 3.8 | アプリ名「GO エクササイズ」改名 + Widget 促進 |
| 3.9 | 累計カード/ヘッダー左揃え/月間カレンダー |
| 4.0 | 保険チケット / 装飾 / バッジ / 月次レビュー / 記念日 |
| 4.1 | UX 整理 + 完了画面「もう一種目」 |
| 4.2 | 筋膜リリース + 体重管理 + 体調・周期 |
| 4.3 | テーマカラー 5 種 / 保険チケットカレンダー UI / 体調 ON で +1 枚 |
| 5.0 | 友達機能 MVP (Mock + UI 完成) |
| 5.1 | 4 段階祝祭演出 (CelebrationOverlay + ShimmerText) |
| 5.2 | CoreHaptics 多層パターン + 自動休養日ルール明記 |
| 5.3 | 友達ボタンをホーム toolbar に移動、バッジ削除、設定順最適化 |
| 5.4 | 友達状態確認の完成版: FriendDetailView (週カレンダー / 装飾名 / cheer + 視覚フィードバック) / FriendsView 並び替え・refreshable・相対時刻 / FriendsStore を root 注入 |
| 5.5 | 音声演出を削除 (haptic 単独運用) / 写真保存バグ修正 (NSPhotoLibraryAddUsageDescription + ImageSaver による完了 callback 処理) |
| 5.6 | 厳格バグ回収: URL scheme handler (`goexercise://...`) / 通知タップ deep link (記録画面に遷移) / SettingsView の placeholder を実リンク (privacy/terms/support) に置換 / 装飾 chip の `scribble` symbol を emoji に / deep-link 経由で開いた画面に「閉じる」ボタン |
| 5.7 | バグ厳格回収 第二弾: 友達コード validation (6 桁固定 + 自動 sanitize) / cheer toast race (UUID トークン化) / NotificationScheduler default calendar を mondayFirst に / DemoDataSeeder の save エラーを OSLog 出力 / 演出セクションから「テスト再生」ボタン削除 |
| 5.8 | 当日メニュー詳細共有 (opt-in): `FriendSharingPreferences` + `SharedExerciseDetail` (回数/時間/セット) + FriendDetailView の二段表示 |
| 5.9 | 週間ランキング画面: `WeeklyRankingCalculator` (dense ranking, tiebreak on streak) + WeeklyRankingView (金銀銅メダル + 自分ハイライト) |
| 5.10 | Duolingo 風 5 段階リーグ (ブロンズ→ダイヤモンド): `League` enum / `LeagueStore` (月跨ぎ検知) / `LeagueRules` (上位 2 名昇格・下位 1 名降格) / LeagueView + 昇格演出 toast |
| 5.11 | UI test 拡充: Friends flow (5 件) + Settings links (1 件)、UI total 8 → 14 件 |
| 6.0 | UI/UX 改善 (Claude + Codex + Gemini 3 モデル横断レビュー → 7 batch 実装): 数字 keyboard 完了ボタン / 入力欄ラベル / 44pt tap area / カテゴリ Segmented / 種目 N ラベル / 体重 validation / 達成済 CTA 切替 / 連続記録 chip share アイコン / 友達カード簡素化 + cheer bottom sheet / QR DisclosureGroup / Section.footer / reduceMotion 対応 / monospacedDigit / 月カレンダー凡例 / 履歴日付フォーマット / 「先月のレビュー」disabled state |
| 6.1 | リーグ機能を廃止 (複雑すぎる)、週間ランキングを再設計: ソート基準を「連続日数 → 運動時間」のシンプル 2 段に / 順位ルールカードを最上部 / 「あなたは N 位 / 全 M 人中」サマリーカード / 各行に🔥連続 + ⏱時間で順位根拠を明示 |

## ビルド

Xcode 17+ が必要。

```bash
cd app/GOExercise
xcodegen generate   # project.yml から .xcodeproj を生成
open GOExercise.xcodeproj
# Cmd+R で Simulator 実行
```

## テスト実行

```bash
cd app/GOExercise
xcodebuild \
  -project GOExercise.xcodeproj \
  -scheme GOExercise \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  test
```

現状: ユニット **175** + UI **17** = **192 件全 PASS**。CI も green (`.github/workflows/ios-ci.yml`)。

> 注: App Group (`group.com.goexercise.app`) を使うため、テストは **ad-hoc 署名込み**で実行する
> (`CODE_SIGNING_ALLOWED=NO` を付けると entitlements が剥がれ、DEBUG 起動時に App Group ストアを
> 開けず `assertionFailure` でクラッシュする)。Simulator 宛なら provisioning profile は不要。

## 進捗・残タスク

- 完了履歴: [`MEMORY.md`](MEMORY.md)
- これからやること: [`NEXT_STEPS.md`](NEXT_STEPS.md)
