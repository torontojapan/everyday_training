import SwiftUI

struct RootSplitView: View {
    @Environment(WorkoutStore.self) private var store
    @State private var selection: RootSection? = .home

    var body: some View {
        NavigationSplitView {
            List(RootSection.allCases, selection: $selection) { section in
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
                    // iPad sidebar にも友達/ランキング導線を出す (3 LLM 監査 B-Major:
                    // 旧 RootSplitView は友達に到達不能だった)。
                    FriendsView()
                        .environment(store)
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
