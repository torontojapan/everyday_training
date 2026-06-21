import SwiftUI

/// ウィジェット / ライブアクティビティ共通の「今週ストリップ」。
/// アプリアイコンと同じ肉球マーク + 今週の達成度(X/7)+ 月〜日の達成/休/未ドット。
/// キャラ表示を廃し、ひと目で「今週どれだけ動けたか」を見せる(2026-06 ユーザー要望)。
struct WidgetWeekStrip: View {
    /// 月→日の7日分。空なら 7 個の未記録で補完。
    let statuses: [DailyStatus]
    let weeklyAchieved: Int
    let weeklyTotal: Int
    /// コンパクト表示(小ウィジェット/ライブアクティビティ)で余白を詰める。
    var compact: Bool = false

    /// ライブアクティビティ色(= アプリアイコンの肉球色)。
    static let pawColor = Color(red: 1.00, green: 0.55, blue: 0.30)
    private static let dayLabels = ["月", "火", "水", "木", "金", "土", "日"]

    private var normalized: [DailyStatus] {
        if statuses.count == 7 { return statuses }
        // 古いスナップショット等で欠ける場合は未記録で埋める。
        return Array((statuses + Array(repeating: .todayPending, count: 7)).prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 5) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: compact ? 12 : 14, weight: .bold))
                    .foregroundStyle(Self.pawColor)
                Text("今週")
                    .font(.system(size: compact ? 11 : 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 0.40, green: 0.34, blue: 0.28))
                Spacer(minLength: 0)
                Text("\(weeklyAchieved)/\(max(weeklyTotal, 7))")
                    .font(.system(size: compact ? 12 : 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Self.pawColor)
            }
            HStack(spacing: compact ? 3 : 5) {
                ForEach(Array(normalized.enumerated()), id: \.offset) { idx, status in
                    VStack(spacing: 2) {
                        dot(for: status)
                        Text(Self.dayLabels[idx])
                            .font(.system(size: compact ? 8 : 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.60, green: 0.54, blue: 0.47))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func dot(for status: DailyStatus) -> some View {
        let size: CGFloat = compact ? 14 : 18
        switch status {
        case .achieved, .todayAchieved:
            Circle().fill(Self.pawColor).frame(width: size, height: size)
        case .rescued:
            Circle().strokeBorder(Self.pawColor, lineWidth: 2).frame(width: size, height: size)
        case .rest:
            Text("休")
                .font(.system(size: compact ? 9 : 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.62, blue: 0.85))
                .frame(width: size, height: size)
                .background(Circle().fill(Color(red: 0.45, green: 0.62, blue: 0.85).opacity(0.16)))
        case .missed:
            Image(systemName: "xmark")
                .font(.system(size: compact ? 8 : 10, weight: .bold))
                .foregroundStyle(Color(red: 0.80, green: 0.45, blue: 0.40))
                .frame(width: size, height: size)
        case .future, .todayPending:
            Circle().fill(Color(red: 0.88, green: 0.83, blue: 0.77)).frame(width: size * 0.5, height: size * 0.5)
                .frame(width: size, height: size)
        }
    }
}
