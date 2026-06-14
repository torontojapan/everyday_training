import XCTest
@testable import GOExercise

final class CheerWatermarkLogicTests: XCTestCase {

    private func cheer(_ id: String, _ at: TimeInterval) -> ReceivedCheer {
        ReceivedCheer(id: id, fromDisplayName: "ともだち", kindRaw: "fight", message: nil,
                      createdAt: Date(timeIntervalSince1970: at))
    }

    func test_firstTime_surfacesNothing_andAnchorsToNow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let out = CheerWatermarkLogic.evaluate(lastSeen: nil, now: now, candidates: [])
        XCTAssertTrue(out.unseen.isEmpty)
        XCTAssertEqual(out.newWatermark, now)
    }

    func test_firstTime_ignoresBacklog() {
        // 初回は既存の受信応援(過去分)があっても surface しない。
        let now = Date(timeIntervalSince1970: 1_000)
        let out = CheerWatermarkLogic.evaluate(lastSeen: nil, now: now,
                                               candidates: [cheer("a", 500), cheer("b", 900)])
        XCTAssertTrue(out.unseen.isEmpty)
        XCTAssertEqual(out.newWatermark, now)
    }

    func test_surfacesOnlyStrictlyNewer_boundaryExcluded() {
        // watermark と同時刻(==)は既読扱いで除外。より後(>)だけ出す。
        let out = CheerWatermarkLogic.evaluate(lastSeen: Date(timeIntervalSince1970: 100),
                                               now: Date(timeIntervalSince1970: 9_999),
                                               candidates: [cheer("eq", 100), cheer("new", 150)])
        XCTAssertEqual(out.unseen.map(\.id), ["new"])
        XCTAssertEqual(out.newWatermark, Date(timeIntervalSince1970: 150))
    }

    func test_advancesToNewest_andSortsAscending() {
        let out = CheerWatermarkLogic.evaluate(lastSeen: Date(timeIntervalSince1970: 0),
                                               now: Date(timeIntervalSince1970: 9_999),
                                               candidates: [cheer("c", 30), cheer("a", 10), cheer("b", 20)])
        XCTAssertEqual(out.unseen.map(\.id), ["a", "b", "c"])
        XCTAssertEqual(out.newWatermark, Date(timeIntervalSince1970: 30))
    }

    func test_noNewCheers_keepsWatermark() {
        let last = Date(timeIntervalSince1970: 200)
        let out = CheerWatermarkLogic.evaluate(lastSeen: last,
                                               now: Date(timeIntervalSince1970: 9_999),
                                               candidates: [cheer("a", 100), cheer("b", 200)])
        XCTAssertTrue(out.unseen.isEmpty)
        XCTAssertEqual(out.newWatermark, last)
    }

    func test_reEvaluatingWithAdvancedWatermark_surfacesNothing() {
        // 一度 surface した応援は、前進後の watermark で再評価しても二度と出ない。
        let candidates = [cheer("a", 10), cheer("b", 20)]
        let first = CheerWatermarkLogic.evaluate(lastSeen: Date(timeIntervalSince1970: 0),
                                                 now: Date(timeIntervalSince1970: 9_999),
                                                 candidates: candidates)
        XCTAssertEqual(first.unseen.map(\.id), ["a", "b"])
        let second = CheerWatermarkLogic.evaluate(lastSeen: first.newWatermark,
                                                  now: Date(timeIntervalSince1970: 9_999),
                                                  candidates: candidates)
        XCTAssertTrue(second.unseen.isEmpty)
        XCTAssertEqual(second.newWatermark, Date(timeIntervalSince1970: 20))
    }
}
