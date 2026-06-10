import Foundation
import Observation

/// 友達紹介の状態を保持しアプリ全体へ供給する @Observable ストア。
/// - summary: 星バッジ数 + 今月のフリーズ加算(HomeViewModel が allowance に反映)。
/// - hasReferrer: 自分が referee の紹介行が既にあるか(後から入力の可否)。
/// - pendingWelcome: 新規(される側)の即ポップ1件。
/// - pendingReferrerPops: 紹介者(する側)の起動時ポップ(複数可)。
@MainActor
@Observable
final class ReferralStore {
    private let service: any FriendsService
    private let defaults: UserDefaults
    /// 未サインインのとき紹介ポーリングで匿名アカウントを作らせないためのガード。
    private let isSignedIn: () -> Bool
    static let firstLaunchKey = "referral.firstLaunchAt.v1"
    /// お祝い済みフラグはアカウント(friend_code)ごとに分ける。device 全体で1つだと
    /// 別アカウントが10到達してもお祝いが出ない(Codex round2 指摘)。
    private func breedUnlockCelebratedKey() -> String {
        "referral.breedUnlockCelebrated.v1.\(service.myProfile?.friendCode ?? "none")"
    }

    var summary: ReferralSummary = .empty
    var pendingBreedUnlock = false
    var hasReferrer = false
    /// 現在の `summary` がどのアカウント(friend_code)由来かを記録し、口座跨ぎの
    /// stale entitlement を防ぐ(Codex round3)。
    private var summaryAccountCode: String?
    var pendingWelcome: ReferralConfirmation?
    var pendingReferrerPops: [ReferralConfirmation] = []
    var lastError: String?
    private(set) var firstLaunchAt: Date

    init(service: any FriendsService,
         defaults: UserDefaults = .standard,
         isSignedIn: @escaping () -> Bool,
         now: Date = Date()) {
        self.service = service
        self.defaults = defaults
        self.isSignedIn = isSignedIn
        if let t = defaults.object(forKey: Self.firstLaunchKey) as? Double {
            firstLaunchAt = Date(timeIntervalSince1970: t)
        } else {
            firstLaunchAt = now
            defaults.set(now.timeIntervalSince1970, forKey: Self.firstLaunchKey)
        }
    }

    /// 設定からの「後から招待コードを入力」を出してよいか。
    var canEnterCodeLater: Bool {
        ReferralEntryPolicy.canEnterCodeLater(firstLaunchAt: firstLaunchAt,
                                              now: Date(),
                                              hasExistingReferral: hasReferrer)
    }

    /// 起動時/サインイン後に状態を取り込む。未サインインなら何もしない(孤児防止)。
    func refresh() async {
        guard isSignedIn() else {
            // 未サインイン(サインアウト/切替/削除後)は前アカウントの状態を持ち越さない。
            // pendingBreedUnlock も落とし、次のユーザーに stale なお祝いを出さない(Codex round2)。
            // 紹介ポップ(ウェルカム/紹介者)も identity が消えた時点で破棄する。これが無いと
            // アカウント A のポップ待ちを抱えたまま B に切替/削除した先で A 宛の祝祭が出る(監査 P2)。
            summary = .empty
            hasReferrer = false
            pendingBreedUnlock = false
            pendingWelcome = nil
            pendingReferrerPops = []
            summaryAccountCode = nil
            return
        }
        let account = service.myProfile?.friendCode
        // アカウント切替直後は、現アカウントと異なる古い summary をフェッチ前に空へ。
        // こうすると referralSummary()/hasReferrer() が throw しても前アカウントの星(=有料猫解放)
        // が残らない(Codex round3)。同一アカウントの一時失敗では空にせず既存値を保つ(無駄な flicker回避)。
        if account != summaryAccountCode {
            summary = .empty
            hasReferrer = false
            pendingBreedUnlock = false
            // 別アカウントへ移ったら前アカウント宛の未消化ポップも捨てる(監査 P2)。
            pendingWelcome = nil
            pendingReferrerPops = []
        }
        do {
            // 全フェッチ成功後にまとめて publish する。部分代入だと summary だけ更新され
            // summaryAccountCode と乖離し、口座跨ぎの stale entitlement を生む(Codex round4)。
            let fetchedSummary = try await service.referralSummary()
            let fetchedHasReferrer = try await service.hasReferrer()
            summary = fetchedSummary
            hasReferrer = fetchedHasReferrer
            summaryAccountCode = account
            #if DEBUG
            // スクショ/QA の星注入は sticky。profile 変化で走る refresh() が mock の実集計(0星)で
            // 上書きするのを防ぐ(Codex R3)。bonus は実集計を尊重し星数だけ固定する。
            if let n = debugStarOverride {
                summary = ReferralSummary(starBadges: n, freezeBonusThisMonth: fetchedSummary.freezeBonusThisMonth)
            }
            #endif
            // ⭐10 到達なら(現アカウントで未お祝いのとき)お祝い待ちにする。毎回 deterministic に
            // 上書きするので、星<10 やアカウント切替で前の true が残らない(Codex round2)。
            // celebrated フラグは consumeBreedUnlock(ポップ閉)で立てる(kill時の取りこぼし防止)。
            pendingBreedUnlock = ReferralReward.isBreedUnlocked(starBadges: fetchedSummary.starBadges)
                && !defaults.bool(forKey: breedUnlockCelebratedKey())
        } catch { lastError = error.localizedDescription }
    }

    /// 現アカウント(friendCode)の summary に基づく猫種解放判定。summary が別アカウント由来
    /// (切替/復元直後で未 refresh)なら false=口座跨ぎの stale entitlement を防ぐ(Codex round5)。
    func isBreedUnlocked(forAccount friendCode: String?) -> Bool {
        guard let friendCode, friendCode == summaryAccountCode else { return false }
        return ReferralReward.isBreedUnlocked(starBadges: summary.starBadges)
    }

    /// 現在サインイン中アカウント由来のときだけ返す星バッジ数(口座跨ぎ stale 防止)。
    /// 直読み(summary.starBadges)は切替/復元直後に前アカウントの星を新アカウントの
    /// friend_code 文脈で描いてしまう。表示は必ずこの口座ガード経由にする(監査 P2)。
    var currentAccountStarBadges: Int {
        guard let code = summaryAccountCode, code == service.myProfile?.friendCode else { return 0 }
        return summary.starBadges
    }

    /// 今月のフリーズ加算。summary が現在サインイン中のアカウント由来のときだけ返す。
    /// breed unlock と同じ口座ガード(GPT-5.5 監査): サインアウト/アカウント切替の直後で
    /// まだ refresh() が走っていない間も、前アカウントの加算が allowance に残らないようにする。
    var currentAccountFreezeBonus: Int {
        guard let code = summaryAccountCode, code == service.myProfile?.friendCode else { return 0 }
        return summary.freezeBonusThisMonth
    }

    /// 招待コードを送信(オンボ/設定)。成功で hasReferrer を立て再集計する。
    @discardableResult
    func submitCode(_ raw: String) async -> Bool {
        let code = FriendCodeValidator.sanitize(raw)
        guard FriendCodeValidator.isValid(code) else {
            lastError = "招待コードは6文字です。もう一度確認してください"
            return false
        }
        do {
            try await service.submitInviteCode(code)
            hasReferrer = true
            await refresh()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// 初運動記録到達時に呼ぶ。確定したら新規ポップをセットする。
    func confirmFirstRecordIfNeeded(hasFirstRecord: Bool) async {
        guard isSignedIn(), hasFirstRecord, hasReferrer else { return }
        do {
            if let conf = try await service.confirmReferralIfEligible(hasFirstRecord: true) {
                pendingWelcome = conf
                await refresh()
            }
        } catch { lastError = error.localizedDescription }
    }

    /// 起動時に紹介者ポップを取り込む(取得分は seen 済みになる)。
    func pollReferrerPops() async {
        guard isSignedIn() else { return }
        do {
            let pops = try await service.unseenReferrerConfirmations()
            if !pops.isEmpty {
                pendingReferrerPops = pops
                await refresh()
            }
        } catch { lastError = error.localizedDescription }
    }

    #if DEBUG
    /// スクショ/QA 用の星注入値(sticky)。設定中は refresh() の実集計より優先する。
    @ObservationIgnored private var debugStarOverride: Int?
    /// スクショ/QA 用: 星数を**現在アカウント文脈**で直接注入する。表示は口座ガード経由
    /// (currentAccountStarBadges)になったため、summary だけでなく summaryAccountCode も
    /// 現プロフィールに合わせないと 0 表示になる(Codex R2)。Release では存在しない。
    func debugInjectStars(_ n: Int) {
        debugStarOverride = n
        summary = ReferralSummary(starBadges: n, freezeBonusThisMonth: 0)
        summaryAccountCode = service.myProfile?.friendCode
    }
    #endif

    func consumeWelcome() { pendingWelcome = nil }
    func consumeReferrerPops() { pendingReferrerPops = [] }
    func consumeBreedUnlock() {
        // ユーザーがポップを見て閉じた時点で初めて、現アカウントの「祝った」フラグを永続化する。
        defaults.set(true, forKey: breedUnlockCelebratedKey())
        pendingBreedUnlock = false
    }
}
