import Foundation
import Testing
@testable import GOExercise

/// Codex UX #6「通知の性格」モード:
/// - quiet: streak が危険でなければ何も鳴らない
/// - voice: 朝・夕の標準挙動 (現状互換)
/// - friendDriven: 日常 push は完全に抑制 (push 基盤完成まで degrade)
@MainActor
struct NotificationPersonalityTests {
    @Test
    func defaults_isVoice() {
        let suite = "notif-personality-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = NotificationPersonalityPreferences(defaults: defaults)
        #expect(prefs.current == .voice, "デフォルトは voice (現行互換)")
    }

    @Test
    func persistence_roundtrip() {
        let suite = "notif-personality-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let prefs = NotificationPersonalityPreferences(defaults: defaults)
        prefs.current = .quiet
        let reloaded = NotificationPersonalityPreferences(defaults: defaults)
        #expect(reloaded.current == .quiet)
    }

    @Test
    func quietMode_messageProvider_returnsQuietBucket() {
        let msg = NotificationMessageProvider.message(
            for: .evening,
            personality: .quiet,
            currentStreak: 3,
            weeklyProgressRate: 0.8,
            seedDate: Date(),
            calendar: .mondayFirst
        )
        // quiet バケットは "1分だけ" を頻出させる短い文面集 (provider 実装と整合)
        #expect(!msg.isEmpty)
        // weeklyProgressRate >= 0.5 でも quiet なら voice の高達成バケットには
        // 入らない (= 「今週いい感じ」「あと少しで今週の達成率」などが出ない)。
        #expect(!msg.contains("今週いい感じ"))
        #expect(!msg.contains("今週の達成率"))
    }

    @Test
    func voiceMode_messageProvider_returnsExistingBuckets() {
        let msg = NotificationMessageProvider.message(
            for: .morning,
            personality: .voice,
            currentStreak: 0,
            weeklyProgressRate: 0.0,
            seedDate: Date(),
            calendar: .mondayFirst
        )
        // voice + 連続なし + 朝 = 「やさしく誘うトーン」バケット
        #expect(!msg.isEmpty)
    }
}
