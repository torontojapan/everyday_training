import Foundation
import SwiftData

/// 7 日移動平均などのトレンド曲線用の値オブジェクト。SwiftData @Model ではなく
/// 計算結果なので Identifiable + plain struct。`date` は表現上の calendar 日
/// (startOfDay)、`average` はその日を含む trailing window の平均 kg。
struct WeightTrendPoint: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let average: Double
}

@Model
final class WeightEntry: Identifiable {
    @Attribute(.unique) var id: UUID
    /// 計測時刻 (timestamp)。同一日に複数記録できるように **startOfDay 正規化はしない**。
    /// 過去日入力時は呼び出し側で「その日 00:00」を渡すことで日単位の入力もできる。
    /// 日単位でグルーピングしたい箇所では `Calendar.isDate(_:inSameDayAs:)` を使うこと。
    var date: Date
    var weightKilograms: Double
    var memo: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        date: Date,
        weightKilograms: Double,
        memo: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.weightKilograms = weightKilograms
        self.memo = memo
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
