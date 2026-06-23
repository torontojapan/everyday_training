import Foundation
import OSLog
import SwiftData

private let containerLogger = Logger(subsystem: "com.goexercise.app", category: "AppModelContainer")

/// メインアプリと Widget Extension が **同一の** SwiftData
/// ストアを共有するためのファクトリ。
///
/// 背景 (3 LLM 監査 B-Critical-1):
/// 旧構成ではメインアプリが `.modelContainer(for:)` でデフォルトのアプリ
/// サンドボックス内 `default.store` を使い、Widget Extension は App Group の
/// `WorkoutStore.sqlite` を使っていた。両者が別ファイルだったため、ウィジェット/
/// Live Activity の「やった！」記録がメインアプリに反映されず、連続記録も伸びな
/// かった。両ターゲットが本ファクトリ経由で同じ App Group ストアを開くことで解消する。
enum AppModelContainer {
    static let appGroupIdentifier = "group.com.goexercise.app"
    static let storeFileName = "WorkoutStore.sqlite"

    /// App Group 配下の共有ストア URL。App Group が使えない環境では nil。
    static var sharedStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(storeFileName)
    }

    /// 共有ストアでコンテナを生成する。App Group が使えない / 生成に失敗した
    /// 場合はローカル (デフォルト) ストアにフォールバックしてクラッシュを避ける。
    static func make() -> ModelContainer {
        // ⚠️ footgun 注意(GPT-5.5/Claude 監査): WorkoutRecord/WeightEntry/MenstrualEntry は
        //   @Attribute(.unique) を使う。CloudKit バックストアは .unique を禁止するため、
        //   cloudKitDatabase は **.none 固定**(下の両 ModelConfiguration とも .none)。
        //   将来 CloudKit 同期を入れる場合は先に .unique を除去すること。安易に .automatic に
        //   変えると init が throw → ローカル分断フォールバック(Widget と別ストア)になる。
        //   (entitlements の icloud-* は現状未使用。除去は provisioning 影響があるためローンチ後に。)
        let schema = Schema([WorkoutRecord.self, WeightEntry.self, MenstrualEntry.self])

        if let url = sharedStoreURL {
            // ストアを **開く前に** 親ディレクトリの既定ファイル保護を .completeUnlessOpen に設定する。
            // iOS ではディレクトリの protectionKey が「以後そこに作られるファイルの既定保護クラス」に
            // なるため、SwiftData が後から生成する -wal/-shm も弱い既定 (App Group 既定) を継承せず
            // 確実に保護される (Codex/GPT-5.5 監査)。開いた後の個別ファイル設定 (applyFileProtection) と二段構え。
            applyDirectoryProtection(forStoreAt: url)
            let shared = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            do {
                let container = try ModelContainer(for: schema, configurations: shared)
                // 保存時のファイル保護 (健康データの at-rest 暗号化)。iOS 既定の
                // completeUntilFirstUserAuthentication は初回アンロック後はファイルが
                // 復号可能なまま残る。WorkoutRecord/WeightEntry/MenstrualEntry は機微なので
                // ファイルを閉じている間は保護する .completeUnlessOpen に引き上げる。
                // .complete ではなく .completeUnlessOpen を選ぶのは、Widget Extension が
                // ロック画面 (初回アンロック後の再ロック中) でもストアを開いて読めるように
                // するため (.complete だと施錠中はファイルを開けず Widget が更新できない)。
                applyFileProtection(to: url)
                return container
            } catch {
                // App Group ストアが開けない場合のみフォールバックする。これは
                // entitlement/provisioning の異常 (= ビルド構成ミス) を意味し、
                // この時アプリと Widget が別々のローカルストアに書いて分断する恐れが
                // あるため、Console に大きく警告を出して検知可能にする (Codex 指摘)。
                containerLogger.error("App Group store を開けず local にフォールバック (widget と分断の恐れ): \(error.localizedDescription, privacy: .public)")
            }
        } else {
            containerLogger.error("App Group container URL が取得できず local にフォールバック (entitlement 確認要)")
        }
        // App Group ストアに到達できないのは entitlement/provisioning のビルド構成ミス
        // を意味し、本番ではアプリと Widget が別ストアに分断する重大事故になる。
        // DEBUG/CI では assertionFailure で **必ず気付ける** ようにし (Release では
        // -O で no-op)、アーカイブ前にミスを検知する。Release では transient な失敗で
        // 起動不能にしないよう、ログを残しつつローカルに graceful フォールバックする
        // (3 LLM 監査 / Codex 指摘)。
        // ただし XCTest 実行中はトラップしない: ユニットテストのホストアプリは headless の
        // xcodebuild 環境で App Group entitlement が適用されず containerURL が nil になり、
        // ここで assertionFailure するとホストが起動前にクラッシュして
        // 「test runner hung before establishing connection」になる。テストでは
        // ローカルストアに graceful フォールバックして起動を妨げない。
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil
        if !isRunningTests {
            assertionFailure("App Group SwiftData ストアを開けませんでした。App Group entitlement / provisioning を確認してください。Release ではローカルストアにフォールバックします。")
        }
        // フォールバック: ローカルに保存。永続化自体が不能なら致命的として trap。
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        // フォールバック経路でも健康データの at-rest 保護を維持する (App Group 経路と同じ
        // 二段構え)。これが無いと万一フォールバックした端末で健康データが既定保護のまま残る
        // (Codex P3)。開く前にディレクトリ既定保護 → 開いた後に個別ファイル保護。
        applyDirectoryProtection(forStoreAt: local.url)
        // swiftlint:disable:next force_try
        let localContainer = try! ModelContainer(for: schema, configurations: local)
        applyFileProtection(to: local.url)
        return localContainer
    }

    /// 共有ストア (.sqlite) と SQLite の同伴ファイル (-wal / -shm) に
    /// `.completeUnlessOpen` のファイル保護属性を付与する。存在しないファイルは
    /// `try?` で握り潰す (新規作成直後は -wal/-shm が無いことがある)。
    private static func applyFileProtection(to storeURL: URL) {
        let storePath = storeURL.path
        let paths = [storePath, storePath + "-wal", storePath + "-shm"]
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUnlessOpen]
        for path in paths where FileManager.default.fileExists(atPath: path) {
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: path)
        }
    }

    /// ストアの親ディレクトリの既定ファイル保護を `.completeUnlessOpen` に設定する。
    /// ストアを開く前に呼ぶことで、後から生成される -wal/-shm を含む新規ファイルが
    /// この保護クラスを既定で継承する (個別ファイル設定だけでは取りこぼす後発ファイルを塞ぐ)。
    private static func applyDirectoryProtection(forStoreAt storeURL: URL) {
        let dir = storeURL.deletingLastPathComponent().path
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.completeUnlessOpen]
        try? FileManager.default.setAttributes(attributes, ofItemAtPath: dir)
    }
}
