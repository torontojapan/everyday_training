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

    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws

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
    func restoreWithApple(idToken: String, nonce: String) async throws -> AppleRestoreOutcome
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
    func restoreWithApple(idToken: String, nonce: String) async throws -> AppleRestoreOutcome {
        throw AccountLinkError.providerUnavailable
    }
    func anonymousSessionHasData() async -> Bool { false }
    // 既定 (連携を扱わないスタブ等): 削除導線は実装側で必須。未実装は安全側で throw。
    func deleteAccount() async throws { throw FriendsServiceError.notSignedIn }
}

enum CheerKind: String, CaseIterable, Sendable {
    case fight       // がんばれ
    case great       // すごい
    case clap        // 👏
    case fire        // 🔥

    var emoji: String {
        switch self {
        case .fight: return "💪"
        case .great: return "🌟"
        case .clap: return "👏"
        case .fire: return "🔥"
        }
    }

    var label: String {
        switch self {
        case .fight: return "がんばれ"
        case .great: return "すごい"
        case .clap: return "拍手"
        case .fire: return "応援"
        }
    }
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

    /// Apple 連携の結果。`collision` は「既存アカウントに切替/中止」の二択を UI に促す。
    enum AppleLinkResult: Equatable {
        case linked
        case collision   // この Apple ID は既に別アカウントに紐付く
        case failed(String)
    }

    func refreshBackupStatus() async {
        await service.refreshBackupStatus()
        backupStatus = service.backupStatus
    }

    /// View が `AppleSignInCoordinator` で取得した (idToken, nonce) を渡して連携する。
    func linkApple(idToken: String, nonce: String) async -> AppleLinkResult {
        do {
            try await service.linkApple(idToken: idToken, nonce: nonce)
            backupStatus = service.backupStatus
            return .linked
        } catch AccountLinkError.alreadyLinkedToAnotherAccount {
            return .collision
        } catch {
            let message = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription!
            return .failed(message)
        }
    }

    /// 衝突時の「既存アカウントに切替」。現匿名データは破棄され、プロフィール/友達は再取得。
    func switchToAppleAccount(idToken: String, nonce: String) async -> Bool {
        do {
            try await service.switchToAppleAccount(idToken: idToken, nonce: nonce)
            profile = service.myProfile
            backupStatus = service.backupStatus
            // identity 境界: 世代を進めて進行中の旧 refresh を無効化し、旧アカウントの
            // 友達/申請を持ち越さない (refresh 失敗/競合時の stale 防止, Codex)。
            bumpIdentity()
            friends = []
            requests = []
            await refresh()
            return true
        } catch {
            syncIdentityAfterFailure()
            lastError = (error as? AccountLinkError)?.errorDescription ?? AccountLinkError.failed.errorDescription
            return false
        }
    }

    /// Apple 復元の結果。`failed` はやさしい固定文を保持し UI にそのまま出す。
    enum AppleRestoreResult: Equatable {
        case restored   // 既存アカウントの友達/コードが戻った
        case created    // 既存データ無し → 新規アカウントを作成した
        case failed(String)
    }

    /// welcome の復元入口: Apple で既存アカウントを復元する。成功で profile/友達を反映し
    /// signedInBody に着地する。`restored`/`created` を区別して UI のメッセージを出し分ける。
    func restoreWithApple(idToken: String, nonce: String) async -> AppleRestoreResult {
        do {
            let outcome = try await service.restoreWithApple(idToken: idToken, nonce: nonce)
            profile = service.myProfile
            backupStatus = service.backupStatus
            // identity 境界: 世代を進めて進行中の旧 refresh を無効化し、旧アカウントの友達/申請を
            // 持ち越さない (refresh 失敗/競合時の stale 防止, Codex)。
            bumpIdentity()
            friends = []
            requests = []
            await refresh()
            return outcome == .restored ? .restored : .created
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
                // await 中に identity が切替わっていたら旧アカウントの結果を捨てる (Codex)。
                if gen == identityGeneration {
                    friends = loadedFriends
                    requests = loadedRequests
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

    func cheer(_ kind: CheerKind, to friendCode: String) async {
        guard !cheeringCodes.contains(friendCode) else { return }  // 多重送信ガード (Codex#3)
        cheeringCodes.insert(friendCode)
        defer { cheeringCodes.remove(friendCode) }
        do {
            try await service.sendCheer(kind, to: friendCode)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
