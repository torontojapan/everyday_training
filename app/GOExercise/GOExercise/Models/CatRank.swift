import Foundation

/// メタルの種別。色(SwiftUI)は `MetalStyle.swift` が担う。
/// `+`/`-` は同系統 ±8% 明度のバリアント。`rainbow` は AngularGradient。
enum MetalKind: Equatable, Sendable {
    case bronze, bronzePlus
    case silver, silverPlus
    case goldMinus, gold, goldPlus
    case platinum
    case rainbow
}

/// 達成の豪華演出の背骨。**現在の連続日数**で決まる統一11段ランク。
/// 連続が途切れたら rank も落ちる(降格)= 守る動機。フリーズで連続が保たれれば rank も保たれる。
/// A背景の濃さ・C称号名・Cメタル色・B昇格判定の唯一の入力。
struct CatRank: Equatable, Sendable {
    /// 連続閾値(昇順)。rank = この配列のうち streak 以下の要素数。
    static let thresholds = [7, 14, 30, 50, 75, 100, 150, 200, 300, 365, 500]

    /// 0..11。0 = 称号なし(連続7日未満)。
    let rank: Int

    init(currentStreak: Int) {
        let s = max(0, currentStreak)
        self.rank = Self.thresholds.filter { s >= $0 }.count
    }

    /// 0..1。背景 richness 等の連続的な濃さ。
    var richness: Double { Double(rank) / Double(Self.thresholds.count) }

    /// 称号(案B「ねこ仕立て」)。rank0 は nil。
    var title: String? {
        switch rank {
        case 1: return "みならいネコ"
        case 2: return "かけだしネコ"
        case 3: return "がんばりネコ"
        case 4: return "まいにちネコ"
        case 5: return "きたえネコ"
        case 6: return "つわものネコ"
        case 7: return "ベテランネコ"
        case 8: return "達人ネコ"
        case 9: return "仙人ネコ"
        case 10: return "レジェンドネコ"
        case 11: return "ぬしネコ"
        default: return nil
        }
    }

    /// メタル種別。rank0 は nil。
    var metalKind: MetalKind? {
        switch rank {
        case 1: return .bronze
        case 2: return .bronzePlus
        case 3: return .silver
        case 4: return .silverPlus
        case 5: return .goldMinus
        case 6, 7: return .gold
        case 8, 9: return .goldPlus
        case 10: return .platinum
        case 11: return .rainbow
        default: return nil
        }
    }

    /// 称号バッジの小アイコン(SF Symbol)。ブランド一貫性のため全 rank 共通の肉球。
    var iconSymbol: String { "pawprint.fill" }
}
