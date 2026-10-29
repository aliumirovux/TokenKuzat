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

    func testWaitsForTheTurnToEnd() {
        // Uzoq buyruq: 10 daqiqa yozuv yo'q — holat «bo'sh», lekin javob tugamagan
        let now = Date()
        let before = Engine.state(lastActivity: now.addingTimeInterval(-540), lastStop: "tool_use", now: now)
        let after = Engine.state(lastActivity: now.addingTimeInterval(-660), lastStop: "tool_use", now: now)
        XCTAssertEqual(after, .idle)
        XCTAssertFalse(AutoHandoffRule.shouldTrigger(previous: before, state: after, context: 300_000, thresholdK: 200,
                                                     waitingPermission: false, alreadyDone: false,
                                                     turnEnded: Engine.turnEnded(lastStop: "tool_use")))
        XCTAssertFalse(Engine.turnEnded(lastStop: "tool_result"))
        XCTAssertFalse(Engine.turnEnded(lastStop: "prompt"))
        XCTAssertTrue(Engine.turnEnded(lastStop: "end_turn"))
        XCTAssertTrue(AutoHandoffRule.shouldTrigger(previous: .running, state: .idle, context: 300_000, thresholdK: 200,
                                                    waitingPermission: false, alreadyDone: false,
                                                    turnEnded: Engine.turnEnded(lastStop: "end_turn")))
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

    func testRepeatsAfterContextGrowsAnother30K() {
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: nil, known: false, context: 400_000, thresholdK: 200))
        XCTAssertTrue(AutoHandoffRule.alreadyDone(doneAt: 214_000, known: true, context: 240_000, thresholdK: 200))
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: 214_000, known: true, context: 244_000, thresholdK: 200))
        // Eski yozuv (kontekst noma'lum) — chegara + 30K
        XCTAssertTrue(AutoHandoffRule.alreadyDone(doneAt: nil, known: true, context: 225_000, thresholdK: 200))
        XCTAssertFalse(AutoHandoffRule.alreadyDone(doneAt: nil, known: true, context: 230_000, thresholdK: 200))
    }

    func testContinuationTitlePicksLastMeaningfulTask() {
        let msg = AutoHandoffRule.firstMessage(summary: "Bu — davomi.\n\nSo'nggi vazifalar:\n- #3: kartalar joylashuvini tuzat\n- #4: Ha, chiqar\n\nO'zgartirilgan fayllar:\n- a.swift",
                                           previousContext: 400_000, english: false)
        XCTAssertEqual(AutoHandoffRule.continuationTitle(from: msg), "kartalar joylashuvini tuzat")
        XCTAssertNil(AutoHandoffRule.continuationTitle(from: "oddiy so'rov"))
        XCTAssertEqual(AutoHandoffRule.continuationTitle(from: "Token Kuzatuv: xulosasiz"), Lang.with(english: Lang.isEnglish) { tr("Oldingi sessiya davomi", "Continued session") })
    }

    func testHeadlineLeadsTheMessageAndBecomesTheTitle() {
        let msg = AutoHandoffRule.firstMessage(summary: "↪ TokenKuzat — Ofis paneli\n\nBu — davomi.", previousContext: 210_000, english: false)
        XCTAssertTrue(msg.hasPrefix("↪ TokenKuzat — Ofis paneli\n\nToken Kuzatuv:"))
        XCTAssertTrue(msg.hasSuffix("Bu — davomi."))
        XCTAssertEqual(AutoHandoffRule.continuationTitle(from: msg), "Ofis paneli")
        XCTAssertEqual(AutoHandoffRule.headline(project: nil, task: "Ofis paneli"), "↪ Ofis paneli")
        XCTAssertTrue(AutoHandoffRule.isHandoffPrompt("↪ TokenKuzat — Ofis paneli"))
        // Foydalanuvchi o'zi «↪» bilan boshlagan oddiy xabar — ko'chirilgan sessiya emas
        XCTAssertNil(AutoHandoffRule.continuationTitle(from: "↪ shu yerdan davom et"))
    }
}
