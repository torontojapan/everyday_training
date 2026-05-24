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
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .history: "履歴"
        case .settings: "設定"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .history: "clock.arrow.circlepath"
        case .settings: "gearshape.fill"
        }
    }
}
