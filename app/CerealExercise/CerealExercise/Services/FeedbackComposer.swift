import Foundation
import UIKit

/// アプリ内から「ご意見・不具合報告」をメールで送るための mailto URL を組み立てる。
///
/// バックエンドを持たないローカルファースト構成のため、外部 SDK を足さずに
/// 端末標準のメール composer へ受け渡す。本文には診断情報 (アプリ版 / OS /
/// 端末モデル / 言語) を自動付与して、不具合の再現・切り分けを楽にする。
enum FeedbackComposer {
    static let supportEmail = "218350578+torontojapan@users.noreply.github.com"

    enum Kind {
        case feedback
        case bugReport

        var subject: String {
            switch self {
            case .feedback:  return "GOエクササイズ ご意見・ご要望"
            case .bugReport: return "GOエクササイズ 不具合のご報告"
            }
        }

        var template: String {
            switch self {
            case .feedback:
                return "いただいたご意見・ご要望をお書きください:\n\n\n"
            case .bugReport:
                return """
                どんな操作で何が起きたか、できるだけ詳しくお書きください:

                ・行った操作:
                ・起きたこと:
                ・期待していた動作:


                """
            }
        }
    }

    /// 件名と診断情報入りの本文を持つ mailto URL。生成に失敗した場合は nil。
    static func mailtoURL(for kind: Kind) -> URL? {
        let body = kind.template + diagnosticsFooter()
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: kind.subject),
            URLQueryItem(name: "body", value: body),
        ]
        // mailto の query は space を + ではなく %20 にする必要がある。
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    /// 診断情報フッター (返信解析用)。個人を特定する情報は含めない。
    static func diagnosticsFooter() -> String {
        """
        ----------------------------------------
        以下は不具合解析用の情報です (削除しても構いません)
        アプリ: GOエクササイズ \(appVersion) (\(buildNumber))
        OS: iOS \(UIDevice.current.systemVersion)
        端末: \(deviceModelIdentifier)
        言語: \(Locale.current.identifier)
        """
    }

    private static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "1.0"
    }

    private static var buildNumber: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "-"
    }

    /// "iPhone16,2" のようなハードウェア識別子。
    private static var deviceModelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = Mirror(reflecting: systemInfo.machine)
        let identifier = machine.children.reduce(into: "") { result, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            result.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "Unknown" : identifier
    }
}
