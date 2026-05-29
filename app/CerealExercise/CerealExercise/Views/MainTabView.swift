import SwiftUI

/// Phase 7.0 で導入したアプリ全体のボトムタブ。
/// 旧 HomeView の toolbar 隅にあった「友達 / 履歴 / 設定」を
/// ボトムタブの 1 級市民に格上げし、親指で届く位置に。
struct MainTabView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var selection: Tab = MainTabView.initialSelectionFromLaunchArgs()

    /// `--initial-tab <home|stats|weight|friends|settings>` でデモ/スクショ起動時に
    /// 初期タブを指定可能。指定なし or 不正値は `.home`。
    private static func initialSelectionFromLaunchArgs() -> Tab {
        // --initial-tab はデモ / スクショ専用。Release では常にホーム起動とし、
        // 外部からの初期タブ指定を無効化する (debug 引数は Release で無効)。
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "--initial-tab"), idx + 1 < args.count,
              let tab = Tab(rawValue: args[idx + 1]),
              // 非表示タブ (friends 無効時など) を選択状態にすると空表示になるため弾く。
              visibleTabs().contains(tab) else { return .home }
        return tab
        #else
        return .home
        #endif
    }

    /// 表示するタブの並び。友達機能が無効な間 (v1) は `.friends` を除外する。
    /// build config に依存せずテストできるよう friendsEnabled を引数化。
    static func visibleTabs(friendsEnabled: Bool = AppFeatureFlags.friendsEnabled) -> [Tab] {
        var tabs: [Tab] = [.home, .stats, .weight]
        if friendsEnabled { tabs.append(.friends) }
        tabs.append(.settings)
        return tabs
    }

    enum Tab: String, Hashable, Identifiable {
        case home
        case stats
        case weight
        case friends
        case settings

        var id: String { rawValue }

        var label: String {
            switch self {
            case .home:     return "ホーム"
            case .stats:    return "履歴"   // Gemini 指摘: 「記録」だと記録入力と混同するため
            case .weight:   return "体重"
            case .friends:  return "友達"
            case .settings: return "設定"
            }
        }

        var systemImage: String {
            switch self {
            case .home:     return "house.fill"
            case .stats:    return "chart.bar.fill"
            case .weight:   return "scalemass.fill"
            case .friends:  return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Self.visibleTabs()) { tab in
                tabContent(for: tab)
                    .tabItem { Label(tab.label, systemImage: tab.systemImage) }
                    .tag(tab)
            }
        }
        .tint(Palette.primary)
    }

    @ViewBuilder
    private func tabContent(for tab: Tab) -> some View {
        switch tab {
        case .home:
            HomeView()
                .environment(store)
        case .stats:
            StatsView()
                .environment(store)
        case .weight:
            NavigationStack { WeightTabRootView() }
        case .friends:
            NavigationStack { FriendsView() }
        case .settings:
            NavigationStack { SettingsView() }
        }
    }
}
