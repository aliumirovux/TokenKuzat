import XCTest
@testable import TokenKuzatCore

final class AutoHandoffTests: XCTestCase {
    func rule(_ prev: AgentState?, _ state: AgentState, _ ctx: Int, waiting: Bool = false, done: Bool = false) -> Bool {
        AutoHandoffRule.shouldTrigger(previous: prev, state: state, context: ctx, thresholdK: 200,
                                      waitingPermission: waiting, alreadyDone: done)
    }

    func testTriggersWhenReplyFinishesAboveThreshold() {
        XCTAssertTrue(rule(.running, .idle, 210_000))
        XCTAssertTrue(rule(.waiting, .idle, 200_000))
    }

    func testNeverInterruptsWork() {
        XCTAssertFalse(rule(.running, .running, 300_000))
        XCTAssertFalse(rule(.idle, .waiting, 300_000))
    }

    func testIgnoresSmallContextOldSessionsAndRepeats() {
        XCTAssertFalse(rule(.running, .idle, 150_000))
        XCTAssertFalse(rule(nil, .idle, 300_000))        // ilova ochilganda mavjud sessiya
        XCTAssertFalse(rule(.idle, .idle, 300_000))       // allaqachon bo'sh edi
        XCTAssertFalse(rule(.running, .idle, 300_000, done: true))
        XCTAssertFalse(rule(.running, .idle, 300_000, waiting: true))
    }

    func testFirstMessageCarriesSummaryAndIsCapped() {
        let m = AutoHandoffRule.firstMessage(summary: "XULOSA", previousContext: 210_000)
        XCTAssertTrue(m.contains("210K") && m.hasSuffix("XULOSA"))
        let long = AutoHandoffRule.firstMessage(summary: String(repeating: "a", count: 20_000), previousContext: 1, limit: 100)
        XCTAssertLessThan(long.count, 1_000)
    }

    func testRepeatsAfterContextGrowsAnother100K() {
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: nil, known: false, context: 400_000, thresholdK: 200))
        XCTAssertTrue(AutoHandoffRule.alreadyDone(doneAt: 334_000, known: true, context: 420_000, thresholdK: 200))
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: 334_000, known: true, context: 434_000, thresholdK: 200))
        // Eski yozuv (kontekst noma'lum) — chegara + 100K
        XCTAssertTrue(AutoHandoffRule.alreadyDone(doneAt: nil, known: true, context: 290_000, thresholdK: 200))
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: nil, known: true, context: 395_000, thresholdK: 200))
    }
}
