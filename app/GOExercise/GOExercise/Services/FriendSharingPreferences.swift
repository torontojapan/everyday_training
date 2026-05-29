import Foundation
import Observation

/// User-controlled privacy slider for what their own profile broadcasts to
/// friends. Default: minimal (category + names only).
@MainActor
@Observable
final class FriendSharingPreferences {
    static let detailKey = "friend.sharing.includeDetail"
    static let shared = FriendSharingPreferences()

    private let defaults: UserDefaults

    /// When true, the profile published to friends includes per-exercise
    /// duration / reps / sets in addition to category + name.
    var includeExerciseDetail: Bool {
        didSet { defaults.set(includeExerciseDetail, forKey: Self.detailKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Default OFF — opt-in for the more revealing share.
        self.includeExerciseDetail = defaults.bool(forKey: Self.detailKey)
    }
}
