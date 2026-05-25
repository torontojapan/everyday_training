import Foundation

/// In-memory mock that mimics the eventual CloudKit-backed FriendsService.
/// Lets the UI be built and tested without an iCloud account.
@MainActor
final class MockFriendsService: FriendsService {
    /// `.v2` 以降は weeklyAchievements / connectedSince を含むため互換性確保のためキー bump。
    static let profileKey = "mock.friends.myProfile.v2"

    private(set) var myProfile: FriendProfile?
    private var friends: [String: FriendProfile] = [:]   // friendCode → profile
    private var requests: [String: FriendRequest] = [:]  // id → request
    private(set) var sentCheers: [(kind: CheerKind, code: String, at: Date)] = []

    private var defaults: UserDefaults
    private var demoPool: [FriendProfile]
    private var now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        if let data = defaults.data(forKey: Self.profileKey),
           let decoded = try? JSONDecoder().decode(StoredProfile.self, from: data) {
            self.myProfile = decoded.profile
        }
        self.demoPool = Self.seedDemoPool(now: now())
    }

    func signIn(displayName: String, username: String) async throws {
        let code = FriendCode.generate()
        let profile = FriendProfile(
            id: code,
            friendCode: code,
            username: username.isEmpty ? "you" : username,
            displayName: displayName.isEmpty ? "あなた" : displayName,
            currentStreak: 0,
            totalAchievedDays: 0,
            todayAchieved: false,
            todayCategoryName: nil,
            todayExerciseNames: [],
            decorationTier: 0,
            lastUpdated: now(),
            weeklyAchievements: Array(repeating: false, count: 7),
            connectedSince: now()
        )
        myProfile = profile
        persistProfile()

        // Pre-seed one pending request and a few friends so the UI has rich data to show.
        if requests.isEmpty {
            let sample = demoPool.removeFirst()
            requests[sample.friendCode] = FriendRequest(id: sample.friendCode, fromProfile: sample, requestedAt: now())
        }
        if friends.isEmpty {
            // Seed two friends so the friend list isn't lonely on first open.
            for _ in 0..<min(2, demoPool.count) {
                let pre = demoPool.removeFirst()
                friends[pre.friendCode] = pre
            }
        }
    }

    func signOut() async {
        myProfile = nil
        friends.removeAll()
        requests.removeAll()
        sentCheers.removeAll()
        defaults.removeObject(forKey: Self.profileKey)
    }

    func refreshFriends() async throws -> [FriendProfile] {
        guard myProfile != nil else { throw FriendsServiceError.notSignedIn }
        return friends.values.sorted { $0.currentStreak > $1.currentStreak }
    }

    func pendingRequests() async throws -> [FriendRequest] {
        guard myProfile != nil else { throw FriendsServiceError.notSignedIn }
        return requests.values.sorted { $0.requestedAt > $1.requestedAt }
    }

    func sendRequest(to code: String) async throws {
        guard myProfile != nil else { throw FriendsServiceError.notSignedIn }
        let upper = code.uppercased()
        guard let match = demoPool.first(where: { $0.friendCode == upper })
            ?? demoPool.first else {
            throw FriendsServiceError.codeNotFound
        }
        if friends[match.friendCode] != nil { throw FriendsServiceError.alreadyFriends }
        // In real CloudKit this would write a request to the target's private DB.
        // Mock: just auto-accept on their behalf.
        var newFriend = match
        newFriend.connectedSince = now()
        friends[match.friendCode] = newFriend
        demoPool.removeAll { $0.friendCode == match.friendCode }
    }

    func acceptRequest(_ request: FriendRequest) async throws {
        var added = request.fromProfile
        added.connectedSince = now()
        friends[request.fromProfile.friendCode] = added
        requests.removeValue(forKey: request.id)
    }

    func declineRequest(_ request: FriendRequest) async throws {
        requests.removeValue(forKey: request.id)
    }

    func removeFriend(_ profile: FriendProfile) async throws {
        friends.removeValue(forKey: profile.friendCode)
    }

    func searchByUsername(_ query: String) async throws -> [FriendProfile] {
        guard myProfile != nil else { throw FriendsServiceError.notSignedIn }
        let q = query.lowercased()
        return demoPool.filter { $0.username.lowercased().contains(q) || $0.displayName.lowercased().contains(q) }
    }

    func publishMyProfile(_ profile: FriendProfile) async throws {
        myProfile = profile
        persistProfile()
    }

    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws {
        sentCheers.append((kind, friendCode, now()))
    }

    // MARK: - Helpers

    private struct StoredProfile: Codable {
        let profile: FriendProfile
    }

    private func persistProfile() {
        guard let myProfile else { return }
        let data = try? JSONEncoder().encode(StoredProfile(profile: myProfile))
        defaults.set(data, forKey: Self.profileKey)
    }

    private static func seedDemoPool(now: Date) -> [FriendProfile] {
        let minute: TimeInterval = 60
        return [
            FriendProfile(id: "AKIRA1", friendCode: "AKIRA1",
                          username: "akira_t", displayName: "あきら",
                          currentStreak: 42, totalAchievedDays: 168,
                          todayAchieved: true, todayCategoryName: "筋トレ",
                          todayExerciseNames: ["スクワット", "腕立て伏せ", "プランク"],
                          decorationTier: 2,
                          lastUpdated: now.addingTimeInterval(-4 * minute),
                          weeklyAchievements: [true, true, false, true, true, true, true],
                          connectedSince: nil),
            FriendProfile(id: "YUKINA", friendCode: "YUKINA",
                          username: "yukina", displayName: "ゆきな",
                          currentStreak: 12, totalAchievedDays: 35,
                          todayAchieved: true, todayCategoryName: "ヨガ",
                          todayExerciseNames: ["太陽礼拝"],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-22 * minute),
                          weeklyAchievements: [true, false, true, true, true, false, true],
                          connectedSince: nil),
            FriendProfile(id: "HARUTO", friendCode: "HARUTO",
                          username: "haruto88", displayName: "はると",
                          currentStreak: 7, totalAchievedDays: 21,
                          todayAchieved: false, todayCategoryName: nil,
                          todayExerciseNames: [],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-9 * 60 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, false],
                          connectedSince: nil),
            FriendProfile(id: "MOMOKA", friendCode: "MOMOKA",
                          username: "momo", displayName: "ももか",
                          currentStreak: 100, totalAchievedDays: 312,
                          todayAchieved: true, todayCategoryName: "有酸素",
                          todayExerciseNames: ["ジョギング"],
                          decorationTier: 3,
                          lastUpdated: now.addingTimeInterval(-2 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, true],
                          connectedSince: nil)
        ]
    }
}
