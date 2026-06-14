# GO エクササイズ (GO Exercise)

猫キャラクターと一緒に毎日1分から運動を習慣化するアプリ。**iOS 先行リリース**(App Store 公開中)、Android は iOS で製品を磨いた後に追って提供予定。

- iOS: SwiftUI / SwiftData / WidgetKit / Swift Charts (iOS 17+)
- Android: Kotlin / Jetpack Compose / Room / DataStore / Glance (compileSdk 36)
- バックエンド(友達・バックアップのみ): Supabase(匿名認証 + RLS)
- Pages: https://torontojapan.github.io/everyday_training/
- 要件: [`specs/requirements_v1.md`](specs/requirements_v1.md)

## 主要機能

- 運動記録(6 カテゴリ)+ 連続記録(休養日スキップ・達成日のみカウント)+ 週間/月間カレンダー
- 表情ゆたかな猫キャラ(全 11 種・状態×日付で変化)+ 連続日数ベースの称号・達成演出
- 通知(1日1〜2回・性格モード)+ ホーム画面ウィジェット
- 連続記録シェア画像 / 月次レビュー / 記念日演出 / CoreHaptics(iOS)
- フリーズ(保険チケット)で連続を救済 / 体重管理 / 体調・周期記録(オプトイン)
- **友達**(友達コード / QR / ユーザー名検索・連続記録共有・スタンプ応援・週間ランキング・友達紹介)
- **クラウドバックアップ/復元**(任意・既定オフ・機種変更対応)
- GOプレミアム(体重グラフ・周期・レポート / 月¥500・年¥3,800・14日無料トライアル)

## ディレクトリ構成

```
serial_training/
├── README.md                    ← このファイル
├── docs/REMAINING_TASKS.md      ← 残タスクの正本(現況はここ)
├── STORE_SUBMISSION_ANSWERS.md  ← 両OS共通の Data safety / App Privacy 回答
├── IOS_SUBMISSION.md            ← iOS 提出シート(ASC 転記用)
├── ANDROID_SUBMISSION.md        ← Android 提出シート(Play 転記用・将来用)
│
├── app/GOExercise/              ← iOS アプリ(SwiftUI / iOS 17+, xcodegen 生成 .xcodeproj)
│   ├── GOExercise/                App/Models/Views/ViewModels/Services/Theme/Resources
│   ├── GOExerciseTests/           ユニットテスト
│   ├── GOExerciseUITests/         UI テスト
│   └── GOExerciseWidget/          ホーム画面ウィジェット
│
├── app-android/                 ← Android アプリ(Kotlin/Compose, Gradle)
│   └── app/src/main/java/com/goexercise/app/  data/domain/presentation/notification/widget
│
├── supabase/                    ← schema.sql / RLS trigger / 回帰テスト SQL
├── specs/requirements_v1.md     ← 要件定義書
├── docs/                        ← GitHub Pages(index/privacy/terms/support)+ 監査ランブック・spec
│   ├── AUDIT_RUNBOOK.md            「漏れなく厳格にテスト」の再現手順(Phase 0–D)
│   ├── AUDIT_*_2026-06-13.md       横断監査の所見・マトリクス
│   ├── DEVICE_QA_RUNBOOK.md        実機限定 QA(課金/サインイン/QR/通知)
│   └── superpowers/specs/          設計 spec(Android 移植計画・友達堅牢化・達成演出 等)
│
├── submission/                  ← App Store 提出パッケージ(メタデータ v1/v1.1 + スクショ)
└── .github/workflows/           ← CI
```

### よく聞かれる「どこにある？」

| 探しもの | 場所 |
|---|---|
| 現況・残タスク | `docs/REMAINING_TASKS.md` |
| 猫キャラの画像 | `app/GOExercise/GOExercise/Resources/Assets.xcassets/CatCharacter/` |
| iOS の画面コード | `app/GOExercise/GOExercise/Views/` |
| Android の画面コード | `app-android/app/src/main/java/com/goexercise/app/presentation/` |
| データモデル(iOS / Android) | `.../Models/` / `.../data/` |
| App Store 提出スクショ | `submission/screenshots/iphone-6.9/` `ipad-13/` |
| プライバシーポリシー(公開版) | `docs/privacy.md`(GitHub Pages で公開) |
| 提出メタデータ / Data safety | `IOS_SUBMISSION.md` / `ANDROID_SUBMISSION.md` / `STORE_SUBMISSION_ANSWERS.md` |
| 要件定義 | `specs/requirements_v1.md` |

## ビルド / テスト

**iOS**(Xcode 17+):
```bash
cd app/GOExercise
xcodegen generate        # project.yml から .xcodeproj を生成(.xcodeproj は gitignore)
xcodebuild -project GOExercise.xcodeproj -scheme GOExercise \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" test
```
> App Group(`group.com.goexercise.app`)のため ad-hoc 署名込みで実行する(`CODE_SIGNING_ALLOWED=NO` は DEBUG 起動クラッシュの原因)。

**Android**(JAVA_HOME = Android Studio JBR):
```bash
cd app-android
./gradlew :app:testDebugUnitTest          # ユニットテスト
./gradlew :app:assembleDebug              # ビルド
```

## 進捗・残タスク

現況と残タスクの正本は [`docs/REMAINING_TASKS.md`](docs/REMAINING_TASKS.md)(担当 [Me]/[User]・優先度つき)。横断監査の再現手順は [`docs/AUDIT_RUNBOOK.md`](docs/AUDIT_RUNBOOK.md)。
