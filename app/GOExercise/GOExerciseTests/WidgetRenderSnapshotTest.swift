import SwiftUI
import XCTest
@testable import GOExercise

/// iOS ウィジェット(SmallWidgetView)の golden を ImageRenderer で実描画して PNG 添付する。
/// widget 拡張ターゲットは UI test から ImageRenderer 到達不可のため、view を app target にも
/// 含め(project.yml)、ここで実際の view・実アセット・実フォントで描画して Android 実レンダと
/// 横並び照合できるようにする(パリティ #4)。
@MainActor
final class WidgetRenderSnapshotTest: XCTestCase {

    /// GOExerciseWidget.swift の containerBackground と同一のグラデを再現したコンテナで
    /// SmallWidgetView を small widget サイズ(iPhone 17 Pro Max: 170pt)に載せて描画する。
    private func widgetContainer(_ snapshot: WidgetSnapshot) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.95, blue: 0.86),
                    Color(red: 1.00, green: 0.89, blue: 0.78),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color(red: 1.00, green: 0.78, blue: 0.55).opacity(0.55), .clear],
                center: .topTrailing, startRadius: 4, endRadius: 180
            )
            SmallWidgetView(snapshot: snapshot)
                .padding(16)   // WidgetKit の既定 content margins 相当
        }
        .frame(width: 170, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shoot(_ snapshot: WidgetSnapshot, _ name: String) {
        let renderer = ImageRenderer(content: widgetContainer(snapshot))
        renderer.scale = 3   // 170pt @3x = 510px(Android StreakWidgetRenderer の 510px と一致)
        guard let img = renderer.uiImage, let data = img.pngData() else {
            XCTFail("render failed: \(name)"); return
        }
        let att = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        att.name = name; att.lifetime = .keepAlways
        add(att)
        print("SHOT \(name) \(Int(img.size.width))x\(Int(img.size.height))")
    }

    func testRenderSmallWidgetStates() {
        // 固定日時(2026-06-20 14:30)で nightDeadlineHoursLeft を決定論化。
        var dc = DateComponents()
        dc.year = 2026; dc.month = 6; dc.day = 20; dc.hour = 14; dc.minute = 30
        let gen = Calendar.current.date(from: dc) ?? Date(timeIntervalSince1970: 1_781_000_000)

        let pending = WidgetSnapshot.make(
            generatedAt: gen, todayAchieved: false, isRestDay: false,
            currentStreak: 5, weeklyAchieved: 4, weeklyTotal: 7,
            catState: .waitingMorning, message: ""
        )
        let achieved = WidgetSnapshot.make(
            generatedAt: gen, todayAchieved: true, isRestDay: false,
            currentStreak: 5, weeklyAchieved: 5, weeklyTotal: 7,
            catState: .celebrating, message: ""
        )
        let rest = WidgetSnapshot.make(
            generatedAt: gen, todayAchieved: false, isRestDay: true,
            currentStreak: 5, weeklyAchieved: 4, weeklyTotal: 7,
            catState: .resting, message: ""
        )

        shoot(pending, "widget_ios_pending")
        shoot(achieved, "widget_ios_achieved")
        shoot(rest, "widget_ios_rest")
    }

    // 中ウィジェット(systemMedium 相当)を実サイズで描画。週ストリップを大きくした
    // 変更が medium 内で収まり、曜日/達成が読みやすいかを目視検証する。
    private func mediumContainer(_ snapshot: WidgetSnapshot) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 1.00, green: 0.95, blue: 0.86), Color(red: 1.00, green: 0.89, blue: 0.78)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            MediumWidgetView(snapshot: snapshot).padding(16)
        }
        .frame(width: 364, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // ライブアクティビティ(ロック画面)の週ストリップ相当を cream 背景・実幅で描画。
    private func liveActivityStrip(_ snapshot: WidgetSnapshot) -> some View {
        ZStack {
            Color(red: 1.00, green: 0.97, blue: 0.93)
            WidgetWeekStrip(
                statuses: snapshot.weeklyStatuses,
                weeklyAchieved: snapshot.weeklyAchieved,
                weeklyTotal: snapshot.weeklyTotal,
                compact: false
            )
            .padding(.horizontal, 14).padding(.vertical, 10)
        }
        .frame(width: 360, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func shoot<V: View>(_ view: V, _ name: String, w: Int, h: Int) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let img = renderer.uiImage, let data = img.pngData() else { XCTFail("render failed: \(name)"); return }
        let att = XCTAttachment(data: data, uniformTypeIdentifier: "public.png")
        att.name = name; att.lifetime = .keepAlways
        add(att); print("SHOT \(name) \(Int(img.size.width))x\(Int(img.size.height))")
    }

    func testRenderMediumAndLiveActivity() {
        var dc = DateComponents()
        dc.year = 2026; dc.month = 6; dc.day = 20; dc.hour = 14; dc.minute = 30
        let gen = Calendar.current.date(from: dc) ?? Date(timeIntervalSince1970: 1_781_000_000)
        let pending = WidgetSnapshot.make(
            generatedAt: gen, todayAchieved: false, isRestDay: false,
            currentStreak: 5, weeklyAchieved: 4, weeklyTotal: 7, catState: .waitingMorning, message: ""
        )
        let achieved = WidgetSnapshot.make(
            generatedAt: gen, todayAchieved: true, isRestDay: false,
            currentStreak: 5, weeklyAchieved: 5, weeklyTotal: 7, catState: .celebrating, message: ""
        )
        shoot(mediumContainer(pending), "medium_pending", w: 364, h: 170)
        shoot(mediumContainer(achieved), "medium_achieved", w: 364, h: 170)
        shoot(liveActivityStrip(pending), "liveactivity_strip", w: 360, h: 96)
    }
}
