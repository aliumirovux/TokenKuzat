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
}
