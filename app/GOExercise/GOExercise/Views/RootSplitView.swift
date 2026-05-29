import SwiftUI

struct RootSplitView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var selection: RootSection? = .home

    var body: some View {
        NavigationSplitView {
            List(RootSection.visibleSections, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .navigationTitle("メニュー")
        } detail: {
            NavigationStack {
                switch selection ?? .home {
                case .home:
                    HomeView()
                        .environment(store)
                case .history:
                    HistoryView()
                        .environment(store)
                case .weight:
                    // 体重タブの paywall gate を iPad sidebar 経路でも適用する。
                    // 旧コード `WeightView()` は gate をバイパスしていた (LLM A 致命的指摘)。
                    WeightTabRootView()
                case .friends:
                    // 友達が無効 (v1) なら sidebar から除外済みだが、選択状態の
                    // 取りこぼし対策でホームにフォールバックする。
                    if AppFeatureFlags.friendsEnabled {
                        FriendsView()
                            .environment(store)
                    } else {
                        HomeView()
                            .environment(store)
                    }
                case .settings:
                    SettingsView()
                }
            }
        }
    }
}

private enum RootSection: String, CaseIterable, Identifiable {
    case home
    case history
    case weight
    case friends
    case settings

    var id: String { rawValue }

    /// 友達機能が無効な間 (v1) は `.friends` を除外したメニューを返す。
    static var visibleSections: [RootSection] {
        allCases.filter { $0 != .friends || AppFeatureFlags.friendsEnabled }
    }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .history: "履歴"
        case .weight: "体重"
        case .friends: "友達"
        case .settings: "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.arrow.circlepath"
        case .weight: "scalemass.fill"
        case .friends: "person.2.fill"
        case .settings: "gearshape.fill"
        }
    }
}
