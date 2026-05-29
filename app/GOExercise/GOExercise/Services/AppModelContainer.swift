import Foundation
import OSLog
import SwiftData

private let containerLogger = Logger(subsystem: "com.goexercise.app", category: "AppModelContainer")

/// メインアプリと Widget Extension (QuickRecordIntent) が **同一の** SwiftData
/// ストアを共有するためのファクトリ。
///
/// 背景 (3 LLM 監査 B-Critical-1):
/// 旧構成ではメインアプリが `.modelContainer(for:)` でデフォルトのアプリ
/// サンドボックス内 `default.store` を使い、QuickRecordIntent は App Group の
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
        let schema = Schema([WorkoutRecord.self, WeightEntry.self, MenstrualEntry.self])

        if let url = sharedStoreURL {
            let shared = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            do {
                return try ModelContainer(for: schema, configurations: shared)
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
        assertionFailure("App Group SwiftData ストアを開けませんでした。App Group entitlement / provisioning を確認してください。Release ではローカルストアにフォールバックします。")
        // フォールバック: ローカルに保存。永続化自体が不能なら致命的として trap。
        let local = ModelConfiguration(schema: schema)
        // swiftlint:disable:next force_try
        return try! ModelContainer(for: schema, configurations: local)
    }
}
