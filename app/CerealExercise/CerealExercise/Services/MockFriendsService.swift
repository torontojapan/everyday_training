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

    func signIn(displayName rawDisplayName: String, username rawUsername: String) async throws {
        // 空白だけの入力でサインインを通さない (空白 trim 後の判定)。
        let displayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)
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
            connectedSince: now(),
            todayExerciseDetails: nil,
            weeklyTotalMinutes: 0
        )
        myProfile = profile
        persistProfile()
        seedPendingAndFriends()
    }

    /// サインイン状態を変えずに pending/friends を (空なら) シードする。
    /// アプリ再起動で in-memory friends が消えるため、毎回 signIn (= friend code
    /// 再生成 + profile リセット) を避けつつ友達リストを復元する用途 (3 LLM 監査 C2)。
    func seedDemoFriendsIfNeeded() async {
        guard myProfile != nil else { return }
        seedPendingAndFriends()
    }

    /// pending 1 件 + friends 最大 10 件をシード。`demoPool` の先頭から消費する。
    /// demoPool には rich な 11 名の後ろに追加候補が控えており、シード後も
    /// `sendRequest`/`searchByUsername` 用の候補が残る (3 LLM 監査 B-Major)。
    private func seedPendingAndFriends() {
        if requests.isEmpty, !demoPool.isEmpty {
            let sample = demoPool.removeFirst()
            requests[sample.friendCode] = FriendRequest(id: sample.friendCode, fromProfile: sample, requestedAt: now())
        }
        if friends.isEmpty {
            // 末尾 3 名は追加/検索候補として温存。demoPool が 3 以下のときに
            // 負の範囲で trap しないよう max(0, ...) でガードする (Codex 指摘)。
            let seedCount = min(10, max(0, demoPool.count - 3))
            for _ in 0..<seedCount where !demoPool.isEmpty {
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
        guard let me = myProfile else { throw FriendsServiceError.notSignedIn }
        let upper = code.uppercased()
        // 自分自身のコードは追加させない (Gemini 指摘)。
        if upper == me.friendCode { throw FriendsServiceError.cannotAddSelf }
        // 入力コード厳格一致のみ。以前は ?? demoPool.first で先頭にフォールバック
        // していたが、任意コードが偶然成功してしまうため Codex 指摘で撤回。
        guard let match = demoPool.first(where: { $0.friendCode == upper }) else {
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
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "スクワット", reps: 20, sets: 3),
                              SharedExerciseDetail(name: "腕立て伏せ", reps: 10, sets: 3),
                              SharedExerciseDetail(name: "プランク", durationMinutes: 2, sets: 3)
                          ],
                          weeklyTotalMinutes: 180,
                          monthlyTotalMinutes: 620,
                          monthlyAchievedDays: 22,
                          myCatBreed: .silvertabby),
            FriendProfile(id: "YUKINA", friendCode: "YUKINA",
                          username: "yukina", displayName: "ゆきな",
                          currentStreak: 12, totalAchievedDays: 35,
                          todayAchieved: true, todayCategoryName: "ヨガ",
                          todayExerciseNames: ["太陽礼拝"],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-22 * minute),
                          weeklyAchievements: [true, false, true, true, true, false, true],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 95,
                          monthlyTotalMinutes: 340,
                          monthlyAchievedDays: 15,
                          myCatBreed: .calico),   // 詳細共有 OFF の友達
            FriendProfile(id: "HARUTO", friendCode: "HARUTO",
                          username: "haruto88", displayName: "はると",
                          currentStreak: 7, totalAchievedDays: 21,
                          todayAchieved: false, todayCategoryName: nil,
                          todayExerciseNames: [],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-9 * 60 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, false],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 60,
                          monthlyTotalMinutes: 210,
                          monthlyAchievedDays: 11,
                          myCatBreed: .tuxedo),
            FriendProfile(id: "MOMOKA", friendCode: "MOMOKA",
                          username: "momo", displayName: "ももか",
                          currentStreak: 100, totalAchievedDays: 312,
                          todayAchieved: true, todayCategoryName: "有酸素",
                          todayExerciseNames: ["ジョギング"],
                          decorationTier: 3,
                          lastUpdated: now.addingTimeInterval(-2 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "ジョギング", durationMinutes: 45)
                          ],
                          weeklyTotalMinutes: 225,
                          monthlyTotalMinutes: 880,
                          monthlyAchievedDays: 26,
                          myCatBreed: .persian),
            // 以下、フルフル demo (10 名) 用に追加した 7 名。
            // streak / 達成日 / 今日達成有無 / 詳細共有 OFF パターンをばらつかせて、
            // 友達タブの並び替え・ソート・カテゴリ別表示などが豊富に見えるようにする。
            FriendProfile(id: "RIKUTO", friendCode: "RIKUTO",
                          username: "rikuto_g", displayName: "りくと",
                          currentStreak: 58, totalAchievedDays: 201,
                          todayAchieved: true, todayCategoryName: "筋トレ",
                          todayExerciseNames: ["デッドリフト", "ベンチプレス"],
                          decorationTier: 2,
                          lastUpdated: now.addingTimeInterval(-12 * minute),
                          weeklyAchievements: [true, true, true, true, true, false, true],
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "デッドリフト", reps: 8, sets: 4),
                              SharedExerciseDetail(name: "ベンチプレス", reps: 10, sets: 4)
                          ],
                          weeklyTotalMinutes: 210,
                          monthlyTotalMinutes: 740,
                          monthlyAchievedDays: 24,
                          myCatBreed: .browntabby),
            FriendProfile(id: "SAKURA", friendCode: "SAKURA",
                          username: "sakura_y", displayName: "さくら",
                          currentStreak: 3, totalAchievedDays: 58,
                          todayAchieved: false, todayCategoryName: nil,
                          todayExerciseNames: [],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-3 * 60 * minute),
                          weeklyAchievements: [true, false, false, true, true, true, false],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 75,
                          monthlyTotalMinutes: 260,
                          monthlyAchievedDays: 13,
                          myCatBreed: .white),
            FriendProfile(id: "DAICHI", friendCode: "DAICHI",
                          username: "daichi_p", displayName: "だいち",
                          currentStreak: 21, totalAchievedDays: 102,
                          todayAchieved: true, todayCategoryName: "ストレッチ",
                          todayExerciseNames: ["前屈ストレッチ", "肩回し"],
                          decorationTier: 2,
                          lastUpdated: now.addingTimeInterval(-30 * minute),
                          weeklyAchievements: [true, true, true, false, true, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "前屈ストレッチ", durationMinutes: 3, sets: 2),
                              SharedExerciseDetail(name: "肩回し", durationMinutes: 2, sets: 2)
                          ],
                          weeklyTotalMinutes: 90,
                          monthlyTotalMinutes: 380,
                          monthlyAchievedDays: 18,
                          myCatBreed: .gray),
            FriendProfile(id: "MIKAKO", friendCode: "MIKAKO",
                          username: "mikako", displayName: "みかこ",
                          currentStreak: 75, totalAchievedDays: 240,
                          todayAchieved: true, todayCategoryName: "ヨガ",
                          todayExerciseNames: ["太陽礼拝", "戦士のポーズ"],
                          decorationTier: 3,
                          lastUpdated: now.addingTimeInterval(-7 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: nil,    // 詳細共有 OFF
                          weeklyTotalMinutes: 175,
                          monthlyTotalMinutes: 700,
                          monthlyAchievedDays: 25,
                          myCatBreed: .siamese),
            FriendProfile(id: "TAKUYA", friendCode: "TAKUYA",
                          username: "takuya_b", displayName: "たくや",
                          currentStreak: 0, totalAchievedDays: 14,
                          todayAchieved: false, todayCategoryName: nil,
                          todayExerciseNames: [],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-30 * 60 * minute),
                          weeklyAchievements: [false, false, true, false, false, false, false],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 15,
                          monthlyTotalMinutes: 65,
                          monthlyAchievedDays: 4,
                          myCatBreed: .black),
            FriendProfile(id: "EMIRIN", friendCode: "EMIRIN",
                          username: "emi_run", displayName: "えみ",
                          currentStreak: 33, totalAchievedDays: 130,
                          todayAchieved: true, todayCategoryName: "有酸素",
                          todayExerciseNames: ["サイクリング"],
                          decorationTier: 2,
                          lastUpdated: now.addingTimeInterval(-50 * minute),
                          weeklyAchievements: [true, true, false, true, true, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "サイクリング", durationMinutes: 35)
                          ],
                          weeklyTotalMinutes: 165,
                          monthlyTotalMinutes: 540,
                          monthlyAchievedDays: 19,
                          myCatBreed: .scottish),
            FriendProfile(id: "KENJI1", friendCode: "KENJI1",
                          username: "kenji_z", displayName: "けんじ",
                          currentStreak: 200, totalAchievedDays: 410,
                          todayAchieved: true, todayCategoryName: "筋トレ",
                          todayExerciseNames: ["懸垂", "ディップス", "スクワット"],
                          decorationTier: 3,
                          lastUpdated: now.addingTimeInterval(-1 * minute),
                          weeklyAchievements: [true, true, true, true, true, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: [
                              SharedExerciseDetail(name: "懸垂", reps: 12, sets: 4),
                              SharedExerciseDetail(name: "ディップス", reps: 15, sets: 4),
                              SharedExerciseDetail(name: "スクワット", reps: 25, sets: 4)
                          ],
                          weeklyTotalMinutes: 245,
                          monthlyTotalMinutes: 980,
                          monthlyAchievedDays: 30,
                          myCatBreed: .orange),
            // --- 以下 3 名は「追加/検索候補」として温存される (友達には自動シードしない)。
            // friend code でこれらを検索・申請するとデモで友達追加フローを試せる。
            FriendProfile(id: "NANAMI", friendCode: "NANAMI",
                          username: "nanami_k", displayName: "ななみ",
                          currentStreak: 15, totalAchievedDays: 70,
                          todayAchieved: false, todayCategoryName: nil,
                          todayExerciseNames: [],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-120 * minute),
                          weeklyAchievements: [true, true, false, true, false, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 80,
                          monthlyTotalMinutes: 300,
                          monthlyAchievedDays: 14,
                          myCatBreed: .calico),
            FriendProfile(id: "SOTA22", friendCode: "SOTA22",
                          username: "sota", displayName: "そうた",
                          currentStreak: 5, totalAchievedDays: 40,
                          todayAchieved: true, todayCategoryName: "有酸素",
                          todayExerciseNames: ["ランニング"],
                          decorationTier: 1,
                          lastUpdated: now.addingTimeInterval(-15 * minute),
                          weeklyAchievements: [false, true, true, true, false, true, true],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 110,
                          monthlyTotalMinutes: 360,
                          monthlyAchievedDays: 16,
                          myCatBreed: .browntabby),
            FriendProfile(id: "YUZUKI", friendCode: "YUZUKI",
                          username: "yuzu", displayName: "ゆずき",
                          currentStreak: 48, totalAchievedDays: 160,
                          todayAchieved: true, todayCategoryName: "ヨガ",
                          todayExerciseNames: ["太陽礼拝"],
                          decorationTier: 2,
                          lastUpdated: now.addingTimeInterval(-8 * minute),
                          weeklyAchievements: [true, true, true, true, true, false, true],
                          connectedSince: nil,
                          todayExerciseDetails: nil,
                          weeklyTotalMinutes: 150,
                          monthlyTotalMinutes: 560,
                          monthlyAchievedDays: 21,
                          myCatBreed: .white)
        ]
    }
}
