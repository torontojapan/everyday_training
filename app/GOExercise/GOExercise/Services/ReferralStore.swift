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
            summary = .empty
            hasReferrer = false
            pendingBreedUnlock = false
            return
        }
        do {
            summary = try await service.referralSummary()
            hasReferrer = try await service.hasReferrer()
            // ⭐10 到達なら(現アカウントで未お祝いのとき)お祝い待ちにする。毎回 deterministic に
            // 上書きするので、星<10 やアカウント切替で前の true が残らない(Codex round2)。
            // celebrated フラグは consumeBreedUnlock(ポップ閉)で立てる(kill時の取りこぼし防止)。
            pendingBreedUnlock = ReferralReward.isBreedUnlocked(starBadges: summary.starBadges)
                && !defaults.bool(forKey: breedUnlockCelebratedKey())
        } catch { lastError = error.localizedDescription }
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

    func consumeWelcome() { pendingWelcome = nil }
    func consumeReferrerPops() { pendingReferrerPops = [] }
    func consumeBreedUnlock() {
        // ユーザーがポップを見て閉じた時点で初めて、現アカウントの「祝った」フラグを永続化する。
        defaults.set(true, forKey: breedUnlockCelebratedKey())
        pendingBreedUnlock = false
    }
}
