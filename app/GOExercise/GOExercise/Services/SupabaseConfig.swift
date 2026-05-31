import Foundation

/// Supabase 接続情報。値は Secrets.xcconfig (gitignore) → Info.plist 経由で注入。
/// 空の間は `isConfigured == false` で friends は Mock にフォールバックする。
enum SupabaseConfig {
    static var host: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseHost") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    static var anonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    /// xcconfig は scheme を書けない (`//` がコメント) ため host のみ保存し、ここで https を付与。
    static var url: URL? {
        guard !host.isEmpty else { return nil }
        return URL(string: "https://\(host)")
    }
    static var isConfigured: Bool { url != nil && !anonKey.isEmpty }
}
