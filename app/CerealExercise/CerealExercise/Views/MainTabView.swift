import SwiftUI

/// Phase 7.0 で導入したアプリ全体のボトムタブ。
/// 旧 HomeView の toolbar 隅にあった「友達 / 履歴 / 設定」を
/// ボトムタブの 1 級市民に格上げし、親指で届く位置に。
struct MainTabView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var selection: Tab = .home

    enum Tab: String, Hashable {
        case home
        case stats
        case friends
        case settings

        var label: String {
            switch self {
            case .home:     return "ホーム"
            case .stats:    return "履歴"   // Gemini 指摘: 「記録」だと記録入力と混同するため
            case .friends:  return "友達"
            case .settings: return "設定"
            }
        }

        var systemImage: String {
            switch self {
            case .home:     return "house.fill"
            case .stats:    return "chart.bar.fill"
            case .friends:  return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .environment(store)
                .tabItem { Label(Tab.home.label, systemImage: Tab.home.systemImage) }
                .tag(Tab.home)

            StatsView()
                .environment(store)
                .tabItem { Label(Tab.stats.label, systemImage: Tab.stats.systemImage) }
                .tag(Tab.stats)

            NavigationStack { FriendsView() }
                .tabItem { Label(Tab.friends.label, systemImage: Tab.friends.systemImage) }
                .tag(Tab.friends)

            NavigationStack { SettingsView() }
                .tabItem { Label(Tab.settings.label, systemImage: Tab.settings.systemImage) }
                .tag(Tab.settings)
        }
        .tint(Palette.primary)
    }
}
