import Foundation
import Testing
@testable import CerealExercise

/// Codex UX #1「今日のミニマムライン」永続化テスト。
/// - normal は default のため UserDefaults を肥大化させない
/// - day key は yyyy-MM-dd で分離されているので、日付が変わると別管理
@MainActor
struct DailyIntensityStoreTests {
    private func makeStore() -> (DailyIntensityStore, UserDefaults) {
        let suite = "intensity-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (DailyIntensityStore(defaults: defaults, calendar: .mondayFirst), defaults)
    }

    @Test
    func defaultsToNormal() {
        let (store, _) = makeStore()
        #expect(store.intensity(on: Date()) == .normal)
    }

    @Test
    func setAndGet_roundtrip() {
        let (store, _) = makeStore()
        let today = Date()
        store.set(.light, on: today)
        #expect(store.intensity(on: today) == .light)
        store.set(.recovery, on: today)
        #expect(store.intensity(on: today) == .recovery)
    }

    /// `.normal` をセットすると default に戻すためキー自体を削除して
    /// UserDefaults の肥大化を防ぐ。
    @Test
    func normal_removesKey() {
        let (store, defaults) = makeStore()
        let today = Date()
        store.set(.light, on: today)
        let cal = Calendar.mondayFirst
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let key = "intensity.\(fmt.string(from: cal.startOfDay(for: today)))"
        #expect(defaults.string(forKey: key) == DailyIntensity.light.rawValue)
        store.set(.normal, on: today)
        #expect(defaults.string(forKey: key) == nil, "normal は default なので key を消す")
    }

    /// 日付ごとに別管理。今日の選択が昨日の値を上書きしない。
    @Test
    func perDay_separation() {
        let (store, _) = makeStore()
        let cal = Calendar.mondayFirst
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        store.set(.light, on: today)
        store.set(.recovery, on: yesterday)
        #expect(store.intensity(on: today) == .light)
        #expect(store.intensity(on: yesterday) == .recovery)
    }
}
