import Foundation

/// ペイウォールの**トライアル適格による出し分け**コピー(純粋関数)。Android `PaywallCopy` と同型。
///
/// 適格でない(イントロ消化済み)のに「14日間無料」を出すと App Store 審査リジェクト/誤認の元になる。
/// 出し分け文言を 1 か所に集約し、`eligible=false` のとき「無料」表現が一切出ないことを
/// `PaywallCopyTests` で機械的に担保する(eligibility 出し分けの自動テスト)。
enum PaywallCopy {
    struct Strings: Equatable {
        /// ヘッダー下の補足。
        let subhead: String
        /// 購入 CTA ボタン。
        let cta: String
        /// サブスク開示の自動更新行。
        let autoRenewDisclosure: String
        /// トライアル中解約=無課金の注記。適格時のみ表示(非適格は nil=非表示)。
        let freeTrialCancelNote: String?
    }

    static func strings(trialEligible: Bool) -> Strings {
        if trialEligible {
            return Strings(
                subhead: "14日間無料。いつでも解約できます。",
                cta: "14日間無料で始める",
                autoRenewDisclosure: "・14日間の無料体験後、選択したプランで自動更新されます",
                freeTrialCancelNote: "・無料体験中に解約すれば課金されません"
            )
        } else {
            return Strings(
                subhead: "いつでも解約できます。",
                cta: "プレミアムを始める",
                autoRenewDisclosure: "・選択したプランで自動更新されます",
                freeTrialCancelNote: nil
            )
        }
    }
}
