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

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "サインインが必要です"
        case .codeNotFound: return "そのコードのユーザーは見つかりませんでした"
        case .alreadyFriends: return "既に友達です"
        case .duplicateRequest: return "申請は既に送信済みです"
        case .cannotAddSelf: return "自分のコードは追加できません"
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

    init(service: any FriendsService) {
        self.service = service
        self.profile = service.myProfile
    }

    var isSignedIn: Bool { profile != nil }

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

    func cheer(_ kind: CheerKind, to friendCode: String) async {
        do {
            try await service.sendCheer(kind, to: friendCode)
        } catch {
            lastError = error.localizedDescription
        }
    }
}
