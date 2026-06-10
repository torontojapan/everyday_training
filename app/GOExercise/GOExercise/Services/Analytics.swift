import Foundation

#if canImport(TelemetryDeck)
import TelemetryDeck
#endif

/// 計測する行動イベント。離脱・課金ファネルを後から分析できるよう、
/// チェックリストの主要ステップに対応させている。
enum AnalyticsEvent {
    case appOpen
    case onboardingCompleted
    case recordCreated(category: String)
    case paywallViewed(product: String)
    case purchaseStarted(product: String)
    case purchaseCompleted(product: String)
    case dataExported
    case dataDeleted

    /// TelemetryDeck の signal 名 (英小文字スネーク)。
    var name: String {
        switch self {
        case .appOpen:             return "app_open"
        case .onboardingCompleted: return "onboarding_complete"
        case .recordCreated:       return "record_created"
        case .paywallViewed:       return "view_paywall"
        case .purchaseStarted:     return "start_purchase"
        case .purchaseCompleted:   return "purchase_complete"
        case .dataExported:        return "data_exported"
        case .dataDeleted:         return "data_deleted"
        }
    }

    /// 個人を特定しない補助パラメータのみ。
    var parameters: [String: String] {
        switch self {
        case let .recordCreated(category):     return ["category": category]
        case let .paywallViewed(product):      return ["product": product]
        case let .purchaseStarted(product):    return ["product": product]
        case let .purchaseCompleted(product):  return ["product": product]
        default:                               return [:]
        }
    }
}

/// 計測の抽象。アプリ本体はこの protocol 越しに track するだけで、
/// 実体 (TelemetryDeck / Noop) を意識しない。
protocol AnalyticsService: Sendable {
    func track(_ event: AnalyticsEvent)
}

/// 何も送らない実装。テスト・DEBUG・App ID 未設定時のデフォルト。
struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {}
}

#if canImport(TelemetryDeck)
/// TelemetryDeck (プライバシー配慮型) への送信実装。
struct TelemetryDeckAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent) {
        TelemetryDeck.signal(event.name, parameters: event.parameters)
    }
}
#endif

/// アプリ全体から呼ぶ計測ファサード。
///
/// 既定は `NoopAnalytics` なので **App ID を設定するまで一切データを送らない**。
/// これにより「Apple Developer 加入 + TelemetryDeck App ID 設定」までは現状の
/// ゼロ収集 (プライバシーラベル「データ収集なし」) を維持できる。
@MainActor
enum Analytics {
    /// 差し替え可能な実体 (テストでは Noop のまま)。
    static var service: AnalyticsService = NoopAnalytics()

    /// 匿名分析を共有するか (既定 true = 匿名 ON)。設定の「利用状況の分析を共有」でオプトアウト可。
    /// UserDefaults に永続。false の間は [track]/[configureIfPossible] が一切送信・初期化しない。
    /// (Android `Analytics.consentGranted` と対称)。
    static let analyticsEnabledKey = "analyticsEnabled"
    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: analyticsEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: analyticsEnabledKey) }
    }

    static func track(_ event: AnalyticsEvent) {
        guard isEnabled else { return } // オプトアウト中は送らない
        service.track(event)
    }

    /// 設定トグルからの opt-in/out 切替。OFF にしたら **その場で** SDK 実体を Noop に戻し、
    /// セッション中も完全に送信を止める(GPT-5.5/Claude 監査: 旧実装は track の gate のみで、
    /// 既に初期化済みの TelemetryDeck はセッション中 live のまま=厳格なレビュアが残留を問題視し得る)。
    /// ON は次回 configureIfPossible(or 即時再構成)で再有効化。
    static func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            configureIfPossible()
        } else {
            service = NoopAnalytics()
        }
    }

    /// 起動時に一度だけ呼ぶ。**ユーザーが分析を許可** かつ App ID 設定済み かつ Release ビルドの
    /// ときだけ TelemetryDeck を有効化する。オプトアウト中は SDK 自体を起動しない。
    static func configureIfPossible() {
        #if canImport(TelemetryDeck) && !DEBUG
        guard isEnabled else { return } // オプトアウト中は初期化もしない
        guard let appID = telemetryAppID, !appID.isEmpty else { return }
        TelemetryDeck.initialize(config: TelemetryDeck.Config(appID: appID))
        service = TelemetryDeckAnalytics()
        #endif
    }

    private static var telemetryAppID: String? {
        Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String
    }
}
