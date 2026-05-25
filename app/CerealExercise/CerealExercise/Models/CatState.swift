import Foundation

enum CatState: String, Codable, CaseIterable, Sendable {
    case waitingMorning
    case worriedNoon
    case beggingNight
    case celebrating
    case streakExtended
    case resting
    case encouraging

    var emoji: String {
        switch self {
        case .waitingMorning: "🐱"
        case .worriedNoon: "😿"
        case .beggingNight: "🙀"
        case .celebrating: "😸"
        case .streakExtended: "😻🔥"
        case .resting: "😽"
        case .encouraging: "🐱"
        }
    }

    var displayName: String {
        switch self {
        case .waitingMorning: "待機中"
        case .worriedNoon: "少し心配"
        case .beggingNight: "お願い中"
        case .celebrating: "達成"
        case .streakExtended: "連続更新"
        case .resting: "回復中"
        case .encouraging: "復帰応援"
        }
    }

    /// 同じ気持ち (state) を表現する画像バリエーション一覧。
    /// daily seed でローテーションして「飽きさせない」体験を作る。
    /// 全画像は assets/cat_character/ + Assets.xcassets/CatCharacter/ に
    /// 配置済み (オレンジトラ猫のスポーティーキャラ、Phase 6.3 で刷新)。
    var assetVariants: [String] {
        switch self {
        case .waitingMorning:
            // 朝の待機。+drinking で朝のボトル水分補給バリ
            return ["cat_waitingMorning", "cat_drinking"]
        case .worriedNoon:
            return ["cat_worriedNoon"]
        case .beggingNight:
            return ["cat_beggingNight"]
        case .celebrating:
            // 達成時。万歳/ハイファイブ/ボトルで飲む を rotate
            return ["cat_celebrating", "cat_highFive", "cat_drinking"]
        case .streakExtended:
            return ["cat_streakExtended"]
        case .resting:
            // 回復日。寝姿 + ヨガ瞑想 + ストレッチ
            return ["cat_resting", "cat_yogaPose", "cat_stretching"]
        case .encouraging:
            // 復帰応援。ガッツ + ランニング + ストレッチ
            return ["cat_encouraging", "cat_running", "cat_stretching"]
        }
    }

    /// 日付シードで variant を 1 つ選ぶ。同じ日に同じ画像が出続けるが、
    /// 翌日には別 variant に切り替わる。
    func assetName(seedDate: Date = Date(), calendar: Calendar = .current) -> String {
        let variants = assetVariants
        let day = calendar.ordinality(of: .day, in: .era, for: seedDate) ?? 0
        return variants[abs(day) % variants.count]
    }
}
