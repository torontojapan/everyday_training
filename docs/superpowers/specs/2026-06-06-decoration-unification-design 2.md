# 装飾の一本化(コード装飾)設計

- 作成日: 2026-06-06 / iOS 先行
- 経緯: 装飾系統が4つに分裂([[growth-feature-specs-v11]] の監査)。`CatDecoration`(7/30/100/365)・`MilestoneItem`(30/100・オレンジ画像のみ)・`MilestoneBackdrop`(背景)・celebration。閾値バラバラ + アバターアイテムがほぼ死んでいる。
- 方針(ユーザー承認 2026-06-06): **コード装飾に一本化**。

## 1. 単一ソース
**`CatDecoration(totalAchievedDays:)`** を装飾段階の正本にする:none(0-6)/bandana(7)/headband(30)/medal(100)/crown(365)。tier 0-4 = `decorationTier`(friends publish 済)。閾値はこれに統一。

## 2. コード装飾エンブレム(全猫種・全ポーズ対応)
`CatDecorationEmblem(decoration:)`: SF Symbol + `accentColor` の小さな浮遊エンブレム。
- **重要制約**: 猫の体/顔の上には描かない。**新アートにヘッドバンド/ジャケットが焼き込み済**で、上描きすると二重描画→顔のシミ(Phase 7.1 で overlay 撤去済の再発)。→ **猫の頭の上の空きスペースに浮かせる**(体に触れない)。
- 段階で象徴/色/サイズ/グローが上がる(bandana→headband→medal→crown)。crown は最大+柔らかいグロー+ゆっくり bob。
- ホームの大猫(BigCatView)上部に浮かせる。reduceMotion 配慮。

## 3. アバターアイテム(MilestoneItem)退役
`FriendAvatarView` の `breed.avatarAssetName(totalAchievedDays:)`(オレンジ専用 shaker/crown 画像)を素の `breed.avatarAssetName` に戻す。`MilestoneItem` 参照を消す(全猫種で画像欠落 fallback していた死に機能の除去)。友達アバターは既存の `decorationBorder` リング(tier 色)で段階を表現済=据え置き。

## 4. 背景
`MilestoneBackdrop` は据え置き(細粒度の全面アンビエンス)。crown=365 が CatDecoration と一致=整合。

## 5. テスト/検証
- 純ロジック(CatDecoration 既存、emblem の symbol/size マッピングがあれば)= XCTest コンパイル。
- **自前スクショ**で home 大猫の各段階(yearly=crown / monthly=headband)を目視し、位置/サイズ/グローを調整(体に被らない・チープにならない)。
- Codex 改善ループ。

## 6. 非ゴール
- 全猫種×全ポーズの画像アイテム生成(コード装飾で不要化)。celebration sheet の変更。Android(後追い)。
