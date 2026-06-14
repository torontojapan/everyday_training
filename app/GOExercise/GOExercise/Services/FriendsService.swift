import Foundation
import Observation

@MainActor
protocol FriendsService: AnyObject {
    var myProfile: FriendProfile? { get }

    func signIn(displayName: String, username: String) async throws
    func signOut() async

    func refreshFriends() async throws -> [FriendProfile]
    func pendingRequests() async throws -> [FriendRequest]

    func sendRequest(to code: String) async throws
    func acceptRequest(_ request: FriendRequest) async throws
    func declineRequest(_ request: FriendRequest) async throws
    func removeFriend(_ profile: FriendProfile) async throws

    func searchByUsername(_ query: String) async throws -> [FriendProfile]

    /// Push the user's own daily snapshot to the backend.
    func publishMyProfile(_ profile: FriendProfile) async throws

    func sendCheer(_ kind: CheerKind, to friendCode: String, message: String?) async throws

    // MARK: - 友達紹介 (リファラル)

    /// 招待コード(=紹介者の friend_code)を入力して自分を referee とする紹介行(pending)を
    /// 作成し、双方を自動で友達にする。自己/二重紹介/コード不明は throw。
    func submitInviteCode(_ code: String) async throws

    /// 自分(referee)の pending 紹介を、初運動記録到達時に confirmed へ更新する。
    /// 確定したら新規ポップ用の `ReferralConfirmation`(role=.referee)を返す。対象無し/既確定は nil。
    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation?

    /// 自分(referrer)が紹介し confirmed かつ未表示(seen_by_referrer=false)の確定を取得し、
    /// 取得分を seen=true にして返す(起動時ポーリング用、role=.referrer)。
    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation]

    /// 星バッジ数(累計 confirmed 紹介)と今月のフリーズ加算を集計して返す。
    func referralSummary() async throws -> ReferralSummary

    /// 自分が referee の紹介行が既に存在するか(後から入力の可否判定に使う)。
    func hasReferrer() async throws -> Bool

    /// デモ/モック実装で、サインイン状態を変えずに友達リスト (in-memory) を
    /// 再シードする。実バックエンドでは no-op。アプリ再起動で in-memory friends
    /// が消えるモックを補い、毎回 signIn (= friend code 再生成) を避けるため。
    func seedDemoFriendsIfNeeded() async

    // MARK: - アカウント連携 (Phase 2: 機種変復旧。匿名 uid を保持したまま永続化)

    /// 永続アカウント連携の状態 (匿名でないか)。
    var backupStatus: AccountBackupStatus { get }
    /// 現セッションから `backupStatus` を更新する。
    func refreshBackupStatus() async
    /// Apple の id_token で現匿名セッションを永続化 (uid 保持)。
    /// 既に別アカウントに紐付く場合は `AccountLinkError.alreadyLinkedToAnotherAccount`。
    func linkApple(idToken: String, nonce: String) async throws
    /// 衝突時の「既存アカウントに切替」。現匿名データは破棄され、Apple 側の既存アカウントに入る。
    func switchToAppleAccount(idToken: String, nonce: String) async throws
    /// 新端末/再インストール時の「Apple で復元」。既存プロフィールがあれば `.restored`、
    /// 無ければ新規作成して `.created`。welcome の復元入口から呼ぶ。
    func restoreWithApple(idToken: String, nonce: String) async throws -> RestoreOutcome

    // MARK: Google (web/PKCE。Apple のネイティブ id_token とは経路が違う)

    /// Google の web/PKCE フローで現匿名セッションを永続化 (uid 保持)。
    /// `flow` が認可 URL を提示しコールバック URL を返す ([[GoogleSignInCoordinator]])。
    /// 既に別アカウントに紐付く場合は `AccountLinkError.alreadyLinkedToAnotherAccount`。
    func linkGoogle(presenting flow: WebAuthFlow) async throws
    /// 衝突時の「既存アカウントに切替」(Google)。現匿名データは破棄され、Google 側の既存アカウントに入る。
    func switchToGoogleAccount(presenting flow: WebAuthFlow) async throws
    /// 新端末/再インストール時の「Google で復元」。既存があれば `.restored`、無ければ `.created`。
    func restoreWithGoogle(presenting flow: WebAuthFlow) async throws -> RestoreOutcome

    /// 復元/切替の前に、現在の匿名セッションに失われると困るデータ(友達)があるか。
    /// 上書き確認ダイアログを出すかの判定に使う。
    func anonymousSessionHasData() async -> Bool

    /// アカウント削除 (審査 Guideline 5.1.1(v): アプリ内のアカウント削除導線)。
    /// 匿名/連携済み(永続)を問わず、本人 uid の
    /// `profiles`/`friendships`/`friend_requests`/`cheers` をクラウドから削除し、
    /// ローカルサインアウトする。`signOut` (匿名のみ削除・連携済みは保持) とは異なり、
    /// **連携済みアカウントも含めて完全に消す**。
    /// `auth.users` 行自体の削除は service_role が必要なためクライアントは行わない
    /// (= 別途 Edge Function。本人のデータが消えれば残る行に PII は無く、cascade で連鎖削除される)。
    /// 失敗時は throw し、呼び出し側はサインアウトせず再試行可能にする。
    func deleteAccount() async throws

    // MARK: 記録のクラウドバックアップ (user_records, iOS/Android 共通スキーマ)

    /// 変更行をまとめて upsert する (PK = user_id × record_id で冪等)。
    func backupUpsert(_ records: [BackupRecord]) async throws
    /// 本人の全行 (tombstone 含む) を取得する。復元・同期のプル側。
    func backupFetchAll() async throws -> [BackupRecord]
    /// 指定 record_id を論理削除 (deleted=true, payload 空) にする。他端末へ削除を伝播。
    func backupMarkDeleted(_ recordIDs: [String]) async throws
    /// 本人の全行を物理削除 (設定「すべての記録を削除」用)。
    func backupWipeAll() async throws
}

/// クラウドバックアップ1行ぶんのニュートラルDTO。payload は kind ごとの JSON (Data)。
/// スキーマ正本 = supabase/schema.sql の user_records。Android も同形式で読み書きする。
struct BackupRecord: Sendable, Equatable {
    let id: String          // record_id (workout/weight/menstrual は UUID 文字列, rescued_day は "rescued-YYYY-MM-DD")
    let kind: String        // workout / weight / menstrual / rescued_day
    let payloadJSON: Data   // jsonb に入る JSON オブジェクト
    let updatedAt: Date
    let deleted: Bool
}

extension FriendsService {
    func seedDemoFriendsIfNeeded() async {}

    // 既定 (Mock 等): 連携は未対応 = 匿名のまま。プロバイダ未設定環境の安全側。
    var backupStatus: AccountBackupStatus { .anonymous }
    func refreshBackupStatus() async {}
    func linkApple(idToken: String, nonce: String) async throws {
        throw AccountLinkError.providerUnavailable
    }
    func switchToAppleAccount(idToken: String, nonce: String) async throws {
        throw AccountLinkError.providerUnavailable
    }
    func restoreWithApple(idToken: String, nonce: String) async throws -> RestoreOutcome {
        throw AccountLinkError.providerUnavailable
    }
    func linkGoogle(presenting flow: WebAuthFlow) async throws {
        throw AccountLinkError.providerUnavailable
    }
    func switchToGoogleAccount(presenting flow: WebAuthFlow) async throws {
        throw AccountLinkError.providerUnavailable
    }
    func restoreWithGoogle(presenting flow: WebAuthFlow) async throws -> RestoreOutcome {
        throw AccountLinkError.providerUnavailable
    }
    func anonymousSessionHasData() async -> Bool { false }
    // 既定 (連携を扱わないスタブ等): 削除導線は実装側で必須。未実装は安全側で throw。
    func deleteAccount() async throws { throw FriendsServiceError.notSignedIn }

    // 応援の受信。既定は空(Mock/スタブ)。Supabase 実装が override する。
    func unseenReceivedCheers() async throws -> [ReceivedCheer] { [] }

    // 紹介を扱わないスタブ用の安全側既定。実バックエンド/Mock は override する。
    func submitInviteCode(_ code: String) async throws { throw FriendsServiceError.backendUnavailable }
    func confirmReferralIfEligible(hasFirstRecord: Bool) async throws -> ReferralConfirmation? { nil }
    func unseenReferrerConfirmations() async throws -> [ReferralConfirmation] { [] }
    func referralSummary() async throws -> ReferralSummary { .empty }
    func hasReferrer() async throws -> Bool { false }
}

/// 応援スタンプ。rawValue はサーバ `cheers.kind` の契約値(Android と共通。変更時は両OS同時に)。
/// 絵文字は使わず SF Symbol で描く(ユーザー要望)。旧 kind(great/clap/fire)は送信しないが、
/// 受信側は `received(fromRaw:)` で互換表示する(旧クライアント/過去データ)。
enum CheerKind: String, CaseIterable, Sendable {
    case fight                  // がんばれ
    case wontLose = "wontlose"  // 負けないぞ
    case protein                // プロテイン
    case catPunch = "catpunch"  // ねこぱんち

    var symbolName: String {
        switch self {
        case .fight: return "megaphone.fill"
        case .wontLose: return "bolt.fill"
        case .protein: return "waterbottle.fill"
        case .catPunch: return "pawprint.fill"
        }
    }

    var label: String {
        switch self {
        case .fight: return "がんばれ"
        case .wontLose: return "負けないぞ"
        case .protein: return "プロテイン"
        case .catPunch: return "ねこぱんち"
        }
    }

    /// 受信表示用: 未知/旧 kind も解釈して落とさない。
    static func received(fromRaw raw: String) -> (label: String, symbolName: String) {
        if let kind = CheerKind(rawValue: raw) { return (kind.label, kind.symbolName) }
        switch raw {
        case "great": return ("すごい", "star.fill")
        case "clap": return ("拍手", "hands.clap")
        case "fire": return ("応援", "flame.fill")
        default: return ("応援", "heart.fill")
        }
    }
}

/// 自分宛てに届いた応援(前回チェック以降の未読分)。
struct ReceivedCheer: Identifiable, Sendable, Equatable {
    let id: String
    let fromDisplayName: String
    let kindRaw: String
    /// 任意の一言コメント(message 列。旧クライアント/旧データは nil → kind のラベルで表示)。
    let message: String?
    let createdAt: Date
}

enum FriendsServiceError: LocalizedError {
    case notSignedIn
    case codeNotFound
    case alreadyFriends
    case duplicateRequest
    case cannotAddSelf
    case iCloudUnavailable
    case backendUnavailable

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "サインインが必要です"
        case .codeNotFound: return "そのコードのユーザーは見つかりませんでした"
        case .alreadyFriends: return "既に友達です"
        case .duplicateRequest: return "申請は既に送信済みです"
        case .cannotAddSelf: return "自分のコードは追加できません"
        case .iCloudUnavailable: return "iCloud にサインインすると友達機能が使えます (設定 → Apple ID → iCloud)"
        case .backendUnavailable: return "ネットワークに接続できませんでした。時間をおいて再度お試しください"
        }
    }
}

@MainActor
@Observable
final class FriendsStore {
    private let service: any FriendsService

    var profile: FriendProfile?
    var friends: [FriendProfile] = []
    var requests: [FriendRequest] = []
    var lastError: String?
    /// 初回ロード中だけ true (スピナー表示用)。友達0人の正常状態と区別する。
    private(set) var isLoading = false
    /// 初回ロードを一度でも試みたか。`isLoading` 判定に使う (Codex#2)。
    private(set) var hasLoadedOnce = false
    /// チア送信中の friendCode 集合。多重送信ガード + UI disabled に使う (Codex#3)。
    private(set) var cheeringCodes: Set<String> = []
    /// 自分宛てに届いた応援(未読分)。refresh で取り込み、View が consume して表示する。
    private(set) var receivedCheers: [ReceivedCheer] = []
    /// refresh の再入ガード。
    private var isRefreshing = false
    /// identity (サインイン中の uid) の世代トークン。サインアウト/復元/切替で +1 する。
    /// 進行中の `refresh()` が await から戻った時に世代が変わっていたら結果を破棄し、
    /// 旧アカウントの友達/申請を新プロフィール上へ書き込まない (identity 切替の stale 競合防止, Codex)。
    private var identityGeneration = 0
    private func bumpIdentity() { identityGeneration &+= 1 }
    /// ensureSignedIn の再入ガード (.task / deep link / 再試行が重なる多重サインイン防止, Codex)。
    /// View 側は lazy 化のため「未サインイン welcome / サインイン中 spinner」を出し分ける
    /// のに参照する (`private(set)`)。
    private(set) var isSigningIn = false

    init(service: any FriendsService) {
        self.service = service
        self.profile = service.myProfile
    }

    var isSignedIn: Bool { profile != nil }

    /// エラーバナーの「閉じる」用。
    func clearError() { lastError = nil }
    /// 受信した応援を取り出してクリアする(View がトースト表示する)。
    func consumeReceivedCheers() -> [ReceivedCheer] {
        let cheers = receivedCheers
        receivedCheers = []
        return cheers
    }
    /// エラーバナーの「更新」用 (直前操作の再試行ではなく状態の再取得, Codex#4)。
    func reload() async { await refresh() }

    func signIn(displayName: String, username: String) async {
        do {
            try await service.signIn(displayName: displayName, username: username)
            profile = service.myProfile
            await refresh()
            await refreshBackupStatus()   // lazy サインイン後もバックアップ状態を正しく反映
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - アカウント連携 (Phase 2: 機種変復旧)

    /// 永続アカウント連携の状態 (匿名でないか)。
    private(set) var backupStatus: AccountBackupStatus = .anonymous
    var isBackedUp: Bool { backupStatus.isBackedUp }

    /// 連携の結果 (Apple/Google 共通)。`collision` は「既存アカウントに切替/中止」の二択を UI に促す。
    enum LinkResult: Equatable {
        case linked
        case collision   // この Apple/Google ID は既に別アカウントに紐付く
        case cancelled   // ユーザーが認可をキャンセル (web flow 内など)。エラー表示しない。
        case failed(String)
    }

    func refreshBackupStatus() async {
        await service.refreshBackupStatus()
        backupStatus = service.backupStatus
    }

    /// View が `AppleSignInCoordinator` で取得した (idToken, nonce) を渡して連携する。
    func linkApple(idToken: String, nonce: String) async -> LinkResult {
        do {
            try await service.linkApple(idToken: idToken, nonce: nonce)
            backupStatus = service.backupStatus
            return .linked
        } catch AccountLinkError.alreadyLinkedToAnotherAccount {
            return .collision
        } catch AccountLinkError.cancelled {
            return .cancelled
        } catch {
            let message = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription!
            return .failed(message)
        }
    }

    /// View が `GoogleSignInCoordinator` の web/PKCE フローを渡して連携する (Apple と対称)。
    func linkGoogle(presenting flow: WebAuthFlow) async -> LinkResult {
        do {
            try await service.linkGoogle(presenting: flow)
            backupStatus = service.backupStatus
            return .linked
        } catch AccountLinkError.alreadyLinkedToAnotherAccount {
            return .collision
        } catch AccountLinkError.cancelled {
            return .cancelled
        } catch {
            let message = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription!
            return .failed(message)
        }
    }

    /// 衝突時の「既存アカウントに切替」。現匿名データは破棄され、プロフィール/友達は再取得。
    func switchToAppleAccount(idToken: String, nonce: String) async -> Bool {
        await performSwitch { try await self.service.switchToAppleAccount(idToken: idToken, nonce: nonce) }
    }

    /// 衝突時の「既存アカウントに切替」(Google)。再度 web flow を通る (Apple と異なり creds を再利用できない)。
    func switchToGoogleAccount(presenting flow: WebAuthFlow) async -> Bool {
        await performSwitch { try await self.service.switchToGoogleAccount(presenting: flow) }
    }

    /// Apple/Google 共通の切替処理。成功で identity 境界を張り直し友達/申請を再取得する。
    /// キャンセルは静かに false (エラー表示しない)。失敗は lastError をセットして false。
    private func performSwitch(_ op: () async throws -> Void) async -> Bool {
        do {
            try await op()
            profile = service.myProfile
            backupStatus = service.backupStatus
            // identity 境界: 世代を進めて進行中の旧 refresh を無効化し、旧アカウントの
            // 友達/申請を持ち越さない (refresh 失敗/競合時の stale 防止, Codex)。
            bumpIdentity()
            friends = []
            requests = []
            await refresh()
            return true
        } catch AccountLinkError.cancelled {
            // 認可前のキャンセルは identity 不変。状態を触らず静かに false。
            return false
        } catch {
            syncIdentityAfterFailure()
            lastError = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription
            return false
        }
    }

    /// 復元の結果 (Apple/Google 共通)。`failed` はやさしい固定文を保持し UI にそのまま出す。
    enum RestoreResult: Equatable {
        case restored   // 既存アカウントの友達/コードが戻った
        case created    // 既存データ無し → 新規アカウントを作成した
        case cancelled  // ユーザーが認可をキャンセル。エラー表示しない。
        case failed(String)
    }

    /// welcome の復元入口: Apple で既存アカウントを復元する。成功で profile/友達を反映し
    /// signedInBody に着地する。`restored`/`created` を区別して UI のメッセージを出し分ける。
    func restoreWithApple(idToken: String, nonce: String) async -> RestoreResult {
        await performRestore { try await self.service.restoreWithApple(idToken: idToken, nonce: nonce) }
    }

    /// welcome の復元入口: Google (web/PKCE) で既存アカウントを復元する (Apple と対称)。
    func restoreWithGoogle(presenting flow: WebAuthFlow) async -> RestoreResult {
        await performRestore { try await self.service.restoreWithGoogle(presenting: flow) }
    }

    /// Apple/Google 共通の復元処理。成功で identity 境界を張り直し友達/申請を再取得する。
    /// キャンセルは静かに `.cancelled` (エラー表示しない)。失敗は lastError + `.failed`。
    private func performRestore(_ op: () async throws -> RestoreOutcome) async -> RestoreResult {
        do {
            let outcome = try await op()
            profile = service.myProfile
            backupStatus = service.backupStatus
            // identity 境界: 世代を進めて進行中の旧 refresh を無効化し、旧アカウントの友達/申請を
            // 持ち越さない (refresh 失敗/競合時の stale 防止, Codex)。
            bumpIdentity()
            friends = []
            requests = []
            await refresh()
            return outcome == .restored ? .restored : .created
        } catch AccountLinkError.cancelled {
            // 認可前のキャンセルは identity 不変。profile を変えず静かに welcome に留まる。
            return .cancelled
        } catch {
            syncIdentityAfterFailure()
            let message = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription!
            lastError = message
            return .failed(message)
        }
    }

    /// 復元/切替の前に、現在の匿名セッションに失われると困るデータ(友達)があるか。
    func anonymousSessionHasData() async -> Bool {
        await service.anonymousSessionHasData()
    }

    /// 連携(復元/切替)失敗後にサービスの実状態へ同期する。`signInWithIdToken` 成立後に
    /// profile ロードが失敗した場合、サービスは session を巻き戻し `myProfile` を nil 化している
    /// = identity が実際に動いている。その時だけ identity 境界を張り、進行中の旧 refresh を
    /// 無効化し、旧アカウントの友達/申請を残さない。認可前に失敗した場合 (backend 不可等) は
    /// identity 不変なので、サインイン済みユーザーの友達リストを誤って消さない (Codex)。
    private func syncIdentityAfterFailure() {
        let identityChanged = profile?.friendCode != service.myProfile?.friendCode
        profile = service.myProfile
        backupStatus = service.backupStatus
        guard identityChanged else { return }
        bumpIdentity()
        friends = []
        requests = []
    }

    /// 自動サインイン時の既定表示名。これと一致する間だけ「初回の表示名入力」を促す。
    static let autoDisplayName = "ねこの友"

    /// 能動操作 (友達とつながる / deep link 承認) の瞬間に匿名サインインする (lazy / opt-in)。
    /// タブを開いただけでは呼ばれない = 未使用ユーザーの孤児アカウントを作らない。
    /// `signIn` は upsert で冪等なので、既存プロフィールがあれば friendCode 等を引き継ぐ。
    /// 失敗時は `lastError` がセットされ、UI 側で再試行できる。
    func ensureSignedIn() async {
        guard profile == nil, !isSigningIn else { return }
        isSigningIn = true
        defer { isSigningIn = false }
        await signIn(displayName: Self.autoDisplayName, username: Self.generatedUsername())
    }

    /// 検索用の自動 username。一意制約は無いが衝突しにくい短い英数字。
    private static func generatedUsername() -> String {
        let suffix = UUID().uuidString
            .replacingOccurrences(of: "-", with: "")
            .prefix(6)
            .lowercased()
        return "neko\(suffix)"
    }

    /// 表示名のみ変更する (username/friendCode は不変)。`publishMyProfile` で送信。
    func updateDisplayName(_ name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var updated = profile, updated.displayName != trimmed else { return }
        updated.displayName = trimmed
        updated.lastUpdated = Date()
        await publishMyProfile(updated)
    }

    func signOut() async {
        // 削除進行中は signOut を弾く (Codex round3)。削除は複数の await を挟むため、
        // 途中で signOut が割り込むとセッション/ローカル状態が消え、in-flight な削除が
        // 部分削除のまま失敗 + ユーザーはサインアウト済みという不整合になり、
        // 「失敗時はサインアウトせず再試行」の契約が壊れる。
        guard !isDeletingAccount else { return }
        await service.signOut()
        bumpIdentity()   // 進行中の refresh が旧アカウントの結果を書き戻すのを防ぐ (Codex)
        profile = nil
        friends = []
        requests = []
        backupStatus = .anonymous
    }

    /// 削除進行中フラグ (連打防止 + UI のスピナー/disabled)。
    private(set) var isDeletingAccount = false

    /// アカウント削除 (審査 5.1.1(v))。本人のクラウドデータを全消去しローカルサインアウトする。
    /// 成功で welcome (profile==nil) に着地。失敗は `lastError` をセットし**サインアウトしない**
    /// = 再試行できる (部分削除は冪等なので再実行で完了する)。連携済みアカウントも消える。
    /// - Returns: 削除に成功したか。
    @discardableResult
    func deleteAccount() async -> Bool {
        guard !isDeletingAccount else { return false }   // 連打ガード (await 前に立てる)
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await service.deleteAccount()
            bumpIdentity()   // 進行中の refresh が結果を書き戻すのを防ぐ (signOut と同様)
            profile = nil
            friends = []
            requests = []
            backupStatus = .anonymous
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }   // 再入ガード: 通常の重複はドロップ (await前に立てる, Codex)
        isRefreshing = true
        isLoading = !hasLoadedOnce             // 初回のみスピナー
        defer { isRefreshing = false; isLoading = false; hasLoadedOnce = true }
        var gen = identityGeneration           // この反復が属する identity 世代
        while true {
            do {
                let loadedFriends = try await service.refreshFriends()
                let loadedRequests = try await service.pendingRequests()
                // 自分宛ての応援(未読分)。失敗しても友達一覧は出す(致命でない)。
                let loadedCheers = (try? await service.unseenReceivedCheers()) ?? []
                // await 中に identity が切替わっていたら旧アカウントの結果を捨てる (Codex)。
                if gen == identityGeneration {
                    friends = loadedFriends
                    requests = loadedRequests
                    if !loadedCheers.isEmpty { receivedCheers.append(contentsOf: loadedCheers) }
                    lastError = nil
                }
            } catch {
                if gen == identityGeneration { lastError = error.localizedDescription }
            }
            // 走行中に identity が変わっていたら、新 identity で**もう一度だけ**ロードして
            // 切替/復元後の新アカウントの友達を確実に反映する。サインアウト (profile==nil) は
            // 再ロードしない。通常の重複 refresh は冒頭の再入ガードでドロップ済み (Codex)。
            guard gen != identityGeneration, profile != nil else { break }
            gen = identityGeneration
        }
    }

    func sendRequest(to code: String) async {
        do {
            try await service.sendRequest(to: code.uppercased())
            lastError = nil
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func accept(_ request: FriendRequest) async {
        do {
            try await service.acceptRequest(request)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func decline(_ request: FriendRequest) async {
        do {
            try await service.declineRequest(request)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func remove(_ friend: FriendProfile) async {
        do {
            try await service.removeFriend(friend)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func search(_ query: String) async -> [FriendProfile] {
        do {
            return try await service.searchByUsername(query)
        } catch {
            lastError = error.localizedDescription
            return []
        }
    }

    func publishMyProfile(_ profile: FriendProfile) async {
        do {
            try await service.publishMyProfile(profile)
            self.profile = profile
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// サインイン状態を保ったまま (friend code を変えずに) デモ友達を再シードする。
    func ensureDemoFriendsSeeded() async {
        await service.seedDemoFriendsIfNeeded()
        await refresh()
    }

    func cheer(_ kind: CheerKind, to friendCode: String, message: String? = nil) async {
        guard !cheeringCodes.contains(friendCode) else { return }  // 多重送信ガード (Codex#3)
        cheeringCodes.insert(friendCode)
        defer { cheeringCodes.remove(friendCode) }
        do {
            try await service.sendCheer(kind, to: friendCode, message: message)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
