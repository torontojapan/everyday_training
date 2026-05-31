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
}

extension FriendsService {
    func seedDemoFriendsIfNeeded() async {}
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
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        await service.signOut()
        profile = nil
        friends = []
        requests = []
    }

    func refresh() async {
        guard !isRefreshing else { return }   // 再入ガード (Codex: await前に立てる)
        isRefreshing = true
        isLoading = !hasLoadedOnce             // 初回のみスピナー
        defer { isRefreshing = false; isLoading = false; hasLoadedOnce = true }
        do {
            friends = try await service.refreshFriends()
            requests = try await service.pendingRequests()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
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
