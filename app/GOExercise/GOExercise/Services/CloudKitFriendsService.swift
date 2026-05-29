import CloudKit
import Foundation
import OSLog

/// CloudKit (Public Database) backed implementation of `FriendsService`.
///
/// 設計 (v1):
/// - **識別**: iCloud アカウント (`CKContainer.userRecordID`)。Sign in with Apple は使わない。
///   端末が iCloud にサインインしていれば利用可能。未ログインなら `.iCloudUnavailable`。
/// - **friend code**: 初回 signIn で一意なコードを発行し、ユーザーの **Private DB**
///   (`MyAccount` レコード) に保存して端末間で復元する。公開プロフィールは
///   `Profile` レコード (recordName = friendCode) として **Public DB** に置く。
/// - **申請/承認**: `FriendRequest` は申請者が own。承認者は自分側の有向エッジ
///   `Friendship(owner=me, friend=other)` を作る。申請者は次回 refresh で相手側
///   エッジ (friend==me) を見て自分側エッジを作り、自分の申請レコードを削除する
///   (Public DB は作成者しか削除できないため、各自が自分の持ち物だけ操作する)。
/// - **共有**: `publishMyProfile` で自分の `Profile` を upsert。体重・体調データは
///   一切含めない (FriendProfile に存在しない)。
///
/// ⚠️ v1 既知の制限: `removeFriend` は自分側エッジのみ削除する。相手側の
/// 有向エッジは相手が refresh するまで残る (相手にはしばらく自分が表示される)。
/// 機能的な害はなく、CKShare ベースに移行する際に解消する想定。
///
/// ⚠️ このクラスは実 iCloud 2 アカウント × 実機でのみ最終検証可能。
/// CloudKit Console でスキーマ (QUERYABLE インデックス) を確認・本番デプロイすること。
@MainActor
final class CloudKitFriendsService: FriendsService {

    // MARK: - Schema

    private enum RT {
        static let profile = "Profile"
        static let request = "FriendRequest"
        static let friendship = "Friendship"
        static let cheer = "Cheer"
        static let myAccount = "MyAccount"   // private DB singleton
    }
    private enum K {
        // Profile
        static let friendCode = "friendCode"
        static let ownerUserRecordName = "ownerUserRecordName"
        static let username = "username"
        static let displayName = "displayName"
        static let currentStreak = "currentStreak"
        static let totalAchievedDays = "totalAchievedDays"
        static let todayAchieved = "todayAchieved"
        static let todayCategoryName = "todayCategoryName"
        static let todayExerciseNamesJSON = "todayExerciseNamesJSON"
        static let decorationTier = "decorationTier"
        static let weeklyAchievementsJSON = "weeklyAchievementsJSON"
        static let weeklyTotalMinutes = "weeklyTotalMinutes"
        static let monthlyTotalMinutes = "monthlyTotalMinutes"
        static let monthlyAchievedDays = "monthlyAchievedDays"
        static let myCatBreed = "myCatBreed"
        static let todayExerciseDetailsJSON = "todayExerciseDetailsJSON"
        static let lastUpdated = "lastUpdated"
        // FriendRequest / Friendship / Cheer
        static let fromCode = "fromCode"
        static let toCode = "toCode"
        static let ownerCode = "ownerCode"
        static let createdAt = "createdAt"
        static let kind = "kind"
    }

    // MARK: - Dependencies

    private let container: CKContainer
    private var publicDB: CKDatabase { container.publicCloudDatabase }
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.goexercise.app", category: "CloudKitFriends")

    private static let myProfileKey = "cloudkit.friends.myProfile.v1"
    private static let declinedCodesKey = "cloudkit.friends.declinedCodes.v1"

    private(set) var myProfile: FriendProfile?

    init(containerIdentifier: String = "iCloud.com.goexercise.app",
         defaults: UserDefaults = .standard) {
        self.container = CKContainer(identifier: containerIdentifier)
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.myProfileKey),
           let decoded = try? JSONDecoder().decode(FriendProfile.self, from: data) {
            self.myProfile = decoded
        }
    }

    // MARK: - Account / identity

    /// iCloud アカウントが使えることを確認し、ユーザーレコード名を返す。
    private func ensureAccount() async throws -> String {
        let status = try await container.accountStatus()
        guard status == .available else {
            logger.error("iCloud account status not available: \(String(describing: status), privacy: .public)")
            throw FriendsServiceError.iCloudUnavailable
        }
        let id = try await container.userRecordID()
        return id.recordName
    }

    private var myCode: String? { myProfile?.friendCode }

    // MARK: - Sign in / out

    func signIn(displayName rawDisplayName: String, username rawUsername: String) async throws {
        let ownerName = try await ensureAccount()
        let displayName = rawDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = rawUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        let code = try await recoverOrCreateFriendCode(ownerName: ownerName)

        // 既存プロフィール (同一コード) があれば stats を引き継ぐ。無ければ 0 始まり。
        let base = (myProfile?.friendCode == code) ? myProfile : nil
        var profile = base ?? FriendProfile(
            id: code, friendCode: code,
            username: username.isEmpty ? "you" : username,
            displayName: displayName.isEmpty ? "あなた" : displayName,
            currentStreak: 0, totalAchievedDays: 0,
            todayAchieved: false, todayCategoryName: nil, todayExerciseNames: [],
            decorationTier: 0, lastUpdated: Date(),
            weeklyAchievements: Array(repeating: false, count: 7),
            connectedSince: nil, todayExerciseDetails: nil, weeklyTotalMinutes: 0
        )
        profile.username = username.isEmpty ? profile.username : username
        profile.displayName = displayName.isEmpty ? profile.displayName : displayName
        profile.lastUpdated = Date()

        try await upsertProfile(profile, ownerName: ownerName)
        cache(profile)
    }

    func signOut() async {
        // ベストエフォートで公開プロフィールと自分側エッジを消す (失敗は無視)。
        if let code = myCode {
            try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: code))
            await deleteRecords(type: RT.friendship, where: K.ownerCode, equals: code, db: publicDB)
            await deleteRecords(type: RT.request, where: K.fromCode, equals: code, db: publicDB)
        }
        try? await privateDB.deleteRecord(withID: CKRecord.ID(recordName: RT.myAccount))
        myProfile = nil
        defaults.removeObject(forKey: Self.myProfileKey)
        defaults.removeObject(forKey: Self.declinedCodesKey)
    }

    /// Private DB に保存した自分の friend code を復元、無ければ一意なコードを発行して保存。
    private func recoverOrCreateFriendCode(ownerName: String) async throws -> String {
        let accountID = CKRecord.ID(recordName: RT.myAccount)
        if let existing = try? await privateDB.record(for: accountID),
           let code = existing[K.friendCode] as? String, FriendCodeValidator.isValid(code) {
            return code
        }
        // 公開 Profile に存在しないコードを最大 8 回まで試行。
        var code = FriendCode.generate()
        for _ in 0..<8 {
            let exists = (try? await publicDB.record(for: CKRecord.ID(recordName: code))) != nil
            if !exists { break }
            code = FriendCode.generate()
        }
        let accountRecord = CKRecord(recordType: RT.myAccount, recordID: accountID)
        accountRecord[K.friendCode] = code as CKRecordValue
        accountRecord[K.ownerUserRecordName] = ownerName as CKRecordValue
        _ = try? await privateDB.save(accountRecord)
        return code
    }

    // MARK: - Publish

    func publishMyProfile(_ profile: FriendProfile) async throws {
        let ownerName = try await ensureAccount()
        try await upsertProfile(profile, ownerName: ownerName)
        cache(profile)
    }

    private func upsertProfile(_ profile: FriendProfile, ownerName: String) async throws {
        let id = CKRecord.ID(recordName: profile.friendCode)
        // 既存があれば取得して更新、無ければ新規 (Public DB は作成者のみ更新可)。
        let record = (try? await publicDB.record(for: id)) ?? CKRecord(recordType: RT.profile, recordID: id)
        apply(profile, to: record, ownerName: ownerName)
        _ = try await publicDB.save(record)
    }

    // MARK: - Friends / requests

    func refreshFriends() async throws -> [FriendProfile] {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }

        let myEdges = await fetchRecords(type: RT.friendship, where: K.ownerCode, equals: me, db: publicDB)
        var myFriendCodes = Set(myEdges.compactMap { $0[K.friendCode] as? String })

        // リコンサイル: 自分が承認された (相手側エッジ friend==me がある) のに自分側
        // エッジが無いものは、自分側エッジを作り、対応する送信済み申請を削除する。
        let incoming = await fetchRecords(type: RT.friendship, where: K.friendCode, equals: me, db: publicDB)
        let incomingOwners = Set(incoming.compactMap { $0[K.ownerCode] as? String })
        for code in incomingOwners.subtracting(myFriendCodes) {
            // 自分が申請していた相手のみ自動確定する (一方的な追加を防ぐ)。
            let sent = await fetchRecords(type: RT.request, where: K.fromCode, equals: me, db: publicDB)
                .contains { ($0[K.toCode] as? String) == code }
            guard sent else { continue }
            await createFriendshipEdge(owner: me, friend: code)
            myFriendCodes.insert(code)
            await deleteRecords(type: RT.request, where: K.fromCode, equals: me, db: publicDB,
                                extraEquals: (K.toCode, code))
        }

        // 各友達の公開 Profile を取得。
        var result: [FriendProfile] = []
        for code in myFriendCodes {
            if let rec = try? await publicDB.record(for: CKRecord.ID(recordName: code)),
               var p = profile(from: rec) {
                // connectedSince はエッジの作成日を流用。
                if let edge = myEdges.first(where: { ($0[K.friendCode] as? String) == code }) {
                    p.connectedSince = edge[K.createdAt] as? Date ?? edge.creationDate
                }
                result.append(p)
            }
        }
        return result.sorted { $0.currentStreak > $1.currentStreak }
    }

    func pendingRequests() async throws -> [FriendRequest] {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }

        let declined = declinedCodes()
        let myEdges = await fetchRecords(type: RT.friendship, where: K.ownerCode, equals: me, db: publicDB)
        let alreadyFriends = Set(myEdges.compactMap { $0[K.friendCode] as? String })

        let reqRecords = await fetchRecords(type: RT.request, where: K.toCode, equals: me, db: publicDB)
        var result: [FriendRequest] = []
        for rec in reqRecords {
            guard let from = rec[K.fromCode] as? String,
                  !declined.contains(from), !alreadyFriends.contains(from) else { continue }
            guard let rec2 = try? await publicDB.record(for: CKRecord.ID(recordName: from)),
                  let p = profile(from: rec2) else { continue }
            result.append(FriendRequest(id: rec.recordID.recordName,
                                        fromProfile: p,
                                        requestedAt: rec[K.createdAt] as? Date ?? rec.creationDate ?? Date()))
        }
        return result.sorted { $0.requestedAt > $1.requestedAt }
    }

    func sendRequest(to code: String) async throws {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }
        let target = code.uppercased()
        if target == me { throw FriendsServiceError.cannotAddSelf }

        // 相手プロフィールの存在確認。
        guard (try? await publicDB.record(for: CKRecord.ID(recordName: target))) != nil else {
            throw FriendsServiceError.codeNotFound
        }
        // 既に友達?
        let myEdges = await fetchRecords(type: RT.friendship, where: K.ownerCode, equals: me, db: publicDB)
        if myEdges.contains(where: { ($0[K.friendCode] as? String) == target }) {
            throw FriendsServiceError.alreadyFriends
        }
        // 重複申請?
        let sent = await fetchRecords(type: RT.request, where: K.fromCode, equals: me, db: publicDB)
        if sent.contains(where: { ($0[K.toCode] as? String) == target }) {
            throw FriendsServiceError.duplicateRequest
        }
        let rec = CKRecord(recordType: RT.request)
        rec[K.fromCode] = me as CKRecordValue
        rec[K.toCode] = target as CKRecordValue
        rec[K.createdAt] = Date() as CKRecordValue
        _ = try await publicDB.save(rec)
    }

    func acceptRequest(_ request: FriendRequest) async throws {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }
        let from = request.fromProfile.friendCode
        // 承認者は自分側エッジを作る。相手側は相手が refresh で作る。
        await createFriendshipEdge(owner: me, friend: from)
        // 申請レコードは申請者が own のため削除できない場合がある。ベストエフォート。
        try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: request.id))
        // 承認したので declined からは外す。
        removeDeclined(from)
    }

    func declineRequest(_ request: FriendRequest) async throws {
        // 申請レコードは相手 own のため消せないことがある → ローカルで非表示にする。
        addDeclined(request.fromProfile.friendCode)
        try? await publicDB.deleteRecord(withID: CKRecord.ID(recordName: request.id))
    }

    func removeFriend(_ profile: FriendProfile) async throws {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }
        // 自分側エッジのみ削除 (自分が作成者なので削除可)。
        await deleteRecords(type: RT.friendship, where: K.ownerCode, equals: me, db: publicDB,
                            extraEquals: (K.friendCode, profile.friendCode))
    }

    func searchByUsername(_ query: String) async throws -> [FriendProfile] {
        _ = try await ensureAccount()
        guard myProfile != nil else { throw FriendsServiceError.notSignedIn }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        // CloudKit は部分一致 (CONTAINS) を string field で直接サポートしないため、
        // 完全一致検索とする (UI 側でユーザー名を正確に入れてもらう想定)。
        let recs = await fetchRecords(type: RT.profile, where: K.username, equals: q, db: publicDB)
        return recs.compactMap { profile(from: $0) }.filter { $0.friendCode != myCode }
    }

    func sendCheer(_ kind: CheerKind, to friendCode: String) async throws {
        _ = try await ensureAccount()
        guard let me = myCode else { throw FriendsServiceError.notSignedIn }
        let rec = CKRecord(recordType: RT.cheer)
        rec[K.fromCode] = me as CKRecordValue
        rec[K.toCode] = friendCode as CKRecordValue
        rec[K.kind] = kind.rawValue as CKRecordValue
        rec[K.createdAt] = Date() as CKRecordValue
        _ = try await publicDB.save(rec)
    }

    // MARK: - Helpers (CloudKit query / mutate)

    private func createFriendshipEdge(owner: String, friend: String) async {
        let rec = CKRecord(recordType: RT.friendship)
        rec[K.ownerCode] = owner as CKRecordValue
        rec[K.friendCode] = friend as CKRecordValue
        rec[K.createdAt] = Date() as CKRecordValue
        _ = try? await publicDB.save(rec)
    }

    /// 指定フィールドが値に一致するレコードを取得 (任意で 2 条件目)。
    private func fetchRecords(type: String, where field: String, equals value: String,
                              db: CKDatabase) async -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@", field, value)
        let query = CKQuery(recordType: type, predicate: predicate)
        do {
            let (matches, _) = try await db.records(matching: query)
            return matches.compactMap { try? $0.1.get() }
        } catch {
            logger.error("query \(type, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func deleteRecords(type: String, where field: String, equals value: String,
                               db: CKDatabase, extraEquals: (String, String)? = nil) async {
        var recs = await fetchRecords(type: type, where: field, equals: value, db: db)
        if let (f2, v2) = extraEquals {
            recs = recs.filter { ($0[f2] as? String) == v2 }
        }
        for rec in recs {
            _ = try? await db.deleteRecord(withID: rec.recordID)
        }
    }

    // MARK: - declined set (local)

    private func declinedCodes() -> Set<String> {
        Set(defaults.stringArray(forKey: Self.declinedCodesKey) ?? [])
    }
    private func addDeclined(_ code: String) {
        var s = declinedCodes(); s.insert(code)
        defaults.set(Array(s), forKey: Self.declinedCodesKey)
    }
    private func removeDeclined(_ code: String) {
        var s = declinedCodes(); s.remove(code)
        defaults.set(Array(s), forKey: Self.declinedCodesKey)
    }

    // MARK: - cache

    private func cache(_ profile: FriendProfile) {
        myProfile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Self.myProfileKey)
        }
    }

    // MARK: - CKRecord <-> FriendProfile

    private func apply(_ p: FriendProfile, to r: CKRecord, ownerName: String) {
        r[K.friendCode] = p.friendCode as CKRecordValue
        r[K.ownerUserRecordName] = ownerName as CKRecordValue
        r[K.username] = p.username as CKRecordValue
        r[K.displayName] = p.displayName as CKRecordValue
        r[K.currentStreak] = p.currentStreak as CKRecordValue
        r[K.totalAchievedDays] = p.totalAchievedDays as CKRecordValue
        r[K.todayAchieved] = (p.todayAchieved ? 1 : 0) as CKRecordValue
        r[K.todayCategoryName] = (p.todayCategoryName as CKRecordValue?)
        r[K.todayExerciseNamesJSON] = Self.json(p.todayExerciseNames) as CKRecordValue?
        r[K.decorationTier] = p.decorationTier as CKRecordValue
        r[K.weeklyAchievementsJSON] = Self.json(p.weeklyAchievementsOrEmpty) as CKRecordValue?
        r[K.weeklyTotalMinutes] = (p.weeklyTotalMinutes ?? 0) as CKRecordValue
        r[K.monthlyTotalMinutes] = (p.monthlyTotalMinutes ?? 0) as CKRecordValue
        r[K.monthlyAchievedDays] = (p.monthlyAchievedDays ?? 0) as CKRecordValue
        r[K.myCatBreed] = (p.myCatBreed?.rawValue as CKRecordValue?)
        r[K.todayExerciseDetailsJSON] = (p.todayExerciseDetails.flatMap { Self.json($0) } as CKRecordValue?)
        r[K.lastUpdated] = p.lastUpdated as CKRecordValue
    }

    private func profile(from r: CKRecord) -> FriendProfile? {
        guard let code = r[K.friendCode] as? String else { return nil }
        let details: [SharedExerciseDetail]? = (r[K.todayExerciseDetailsJSON] as? String)
            .flatMap { Self.decode([SharedExerciseDetail].self, from: $0) }
        return FriendProfile(
            id: code, friendCode: code,
            username: r[K.username] as? String ?? "user",
            displayName: r[K.displayName] as? String ?? "ともだち",
            currentStreak: (r[K.currentStreak] as? Int) ?? 0,
            totalAchievedDays: (r[K.totalAchievedDays] as? Int) ?? 0,
            todayAchieved: ((r[K.todayAchieved] as? Int) ?? 0) == 1,
            todayCategoryName: r[K.todayCategoryName] as? String,
            todayExerciseNames: (r[K.todayExerciseNamesJSON] as? String)
                .flatMap { Self.decode([String].self, from: $0) } ?? [],
            decorationTier: (r[K.decorationTier] as? Int) ?? 0,
            lastUpdated: r[K.lastUpdated] as? Date ?? r.modificationDate ?? Date(),
            weeklyAchievements: (r[K.weeklyAchievementsJSON] as? String)
                .flatMap { Self.decode([Bool].self, from: $0) },
            connectedSince: nil,
            todayExerciseDetails: details,
            weeklyTotalMinutes: r[K.weeklyTotalMinutes] as? Int,
            monthlyTotalMinutes: r[K.monthlyTotalMinutes] as? Int,
            monthlyAchievedDays: r[K.monthlyAchievedDays] as? Int,
            myCatBreed: (r[K.myCatBreed] as? String).flatMap { CatBreed(rawValue: $0) }
        )
    }

    private static func json<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }
    private static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        string.data(using: .utf8).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }
}
