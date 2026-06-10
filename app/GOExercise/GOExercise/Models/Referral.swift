import Foundation

/// 自分の紹介状況の集計。
/// - starBadges: 累計 confirmed 紹介数(referrer 側・無制限の永続バニティ)。
/// - freezeBonusThisMonth: 今月 confirmed になった「自分向け」フリーズ加算
///   (= 今月 confirmed の referrer 件数 + 自分が referee で今月 confirmed なら +1)。
///   `RescueTicketAllowance.current(isPremium:referralBonus:)` に渡す。
struct ReferralSummary: Equatable, Sendable {
    var starBadges: Int
    var freezeBonusThisMonth: Int
    static let empty = ReferralSummary(starBadges: 0, freezeBonusThisMonth: 0)
}

/// 確定(confirmed)イベント1件。ポップ表示に使う。
struct ReferralConfirmation: Identifiable, Equatable, Sendable {
    enum Role: Sendable { case referrer, referee }
    let id: String              // referee_user_id (referrals の主キー = ユニーク)
    var friendDisplayName: String
    var role: Role
}

/// timestamptz 文字列の解析と「今月か」判定。supabase-swift のデコーダ戦略に依存せず
/// 文字列で受けて自前パースする(決定的・テスト可能)。
enum ReferralClock {
    static func parseTimestamp(_ iso: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: iso) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)
    }
    static func monthKey(_ date: Date, calendar: Calendar) -> String {
        // フリーズ allowance の月判定(Calendar.mondayFirst = 端末ローカル/JST)と一致させる。
        // UTC で割ると月境界の最大 9h でローカル月とずれ、今月ボーナスが隣月の allowance に
        // 効いてしまう(GPT-5.5 監査: bonus月=UTC vs allowance月=local の不一致)。
        let c = calendar.dateComponents([.year, .month], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)"
    }
    /// `iso`(timestamptz 文字列)が `now` と同じ暦月か。nil/解析不能は false。
    /// 月判定は allowance と同じローカル暦(calendar)で行う。
    static func isInMonth(_ iso: String?, of now: Date, calendar: Calendar = .mondayFirst) -> Bool {
        guard let iso, let d = parseTimestamp(iso) else { return false }
        return monthKey(d, calendar: calendar) == monthKey(now, calendar: calendar)
    }
}

/// オンボ以外(設定)から招待コードを入力できるかの判定。新規性を担保するため
/// 初回起動から `graceDays` 以内 かつ まだ紹介者がいない場合のみ許可する。
enum ReferralEntryPolicy {
    static let graceDays = 7
    static func canEnterCodeLater(firstLaunchAt: Date?,
                                  now: Date,
                                  hasExistingReferral: Bool,
                                  graceDays: Int = graceDays) -> Bool {
        guard !hasExistingReferral, let start = firstLaunchAt else { return false }
        // 経過を秒で厳密比較する。`Int(interval/86400) <= 7` は切り捨てで実質8日まで許可してしまい、
        // 文言「登録7日以内」とズレる(監査)。ちょうど 7×24h までを「7日以内」とする。
        let elapsed = now.timeIntervalSince(start)
        return elapsed >= 0 && elapsed <= Double(graceDays) * 86_400
    }
}
