import Foundation
import Testing
@testable import CerealExercise

/// 友達機能の v1 ゲーティング (AppFeatureFlags) が「無効時は friends/weeklyRanking を
/// 表に出さない」ことを build config に依存せず保証する。本番で MockFriendsService が
/// 露出する事故 (QA チェックリスト L) を防ぐのが目的。
struct AppFeatureFlagsTests {
    // MARK: - ルート振り替え

    @Test
    func resolvedRoute_whenFriendsDisabled_redirectsFriendsRoutesToHome() {
        #expect(AppFeatureFlags.resolvedRoute(.friends, friendsEnabled: false) == .home)
        #expect(AppFeatureFlags.resolvedRoute(.weeklyRanking, friendsEnabled: false) == .home)
    }

    @Test
    func resolvedRoute_whenFriendsDisabled_leavesOtherRoutesUntouched() {
        for route: AppRoute in [.home, .record, .history, .settings, .notificationSettings, .streakShare] {
            #expect(AppFeatureFlags.resolvedRoute(route, friendsEnabled: false) == route)
        }
    }

    @Test
    func resolvedRoute_whenFriendsEnabled_leavesFriendsRoutesUntouched() {
        #expect(AppFeatureFlags.resolvedRoute(.friends, friendsEnabled: true) == .friends)
        #expect(AppFeatureFlags.resolvedRoute(.weeklyRanking, friendsEnabled: true) == .weeklyRanking)
    }

    // MARK: - タブ / sidebar の可視性

    @Test
    func visibleTabs_excludeFriendsWhenDisabled() {
        let tabs = MainTabView.visibleTabs(friendsEnabled: false)
        #expect(!tabs.contains(.friends))
        // 他のタブは維持され、並び順も home が先頭・settings が末尾。
        #expect(tabs == [.home, .stats, .weight, .settings])
    }

    @Test
    func visibleTabs_includeFriendsWhenEnabled() {
        let tabs = MainTabView.visibleTabs(friendsEnabled: true)
        #expect(tabs.contains(.friends))
        #expect(tabs == [.home, .stats, .weight, .friends, .settings])
    }
}
