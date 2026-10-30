import XCTest
@testable import TokenKuzatCore

final class HandoffSavingsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func snap(_ id: String, prompt: String, contexts: [Int], from: Double, firstWrite: Int = 0, stepInput: String? = nil) -> SessionSnap {
        let usage = contexts.enumerated().map { i, c in
            UsagePoint(date: t0.addingTimeInterval(from + Double(i)),
                       tokens: TokenCounts(cacheWrite: i == 0 ? firstWrite : 0, cacheRead: i == 0 ? c - firstWrite : c))
        }
        var steps: [StepSnap] = []
        if let stepInput {
            var st = StepSnap(id: "g", date: t0, symbol: "doc", text: "Grep", category: .files, targetName: "", targetKey: "files|x",
                              targetDetail: "", access: .read, duration: 1, status: .done, turn: 1)
            st.input = stepInput
            steps.append(st)
        }
        let main = AgentSnap(id: "\(id)/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: contexts.count, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: usage, bigResults: [])
        let turn = TurnSnap(id: 1, prompt: String(prompt.prefix { $0 != "\n" }), text: prompt, start: t0.addingTimeInterval(from),
                            end: t0.addingTimeInterval(from), tokens: TokenCounts(), steps: 0, errors: 0, active: false)
        return SessionSnap(id: id, project: "Demo", title: "t", model: "Opus", contextTokens: contexts.last ?? 0,
                           tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                           lastActivity: t0, state: .idle, turns: [turn])
    }

    private func handoffPrompt(old: String) -> String {
        "↪ Ish\n\nToken Kuzatuv: ko'chirildi.\n\nOldingi sessiya yozuvlari (butun suhbat shu yerda):\n- /p/\(old).jsonl\n\nXulosa"
    }

    func testMeasuresSavingAgainstOldSessionTail() throws {
        let old = snap("old", prompt: "Xaritani yangila", contexts: [100_000, 150_000, 190_000, 200_000, 200_000, 210_000], from: 0)
        let new = snap("new", prompt: handoffPrompt(old: "old"), contexts: [60_000, 62_000, 64_000, 66_000], from: 100, firstWrite: 20_000)
        let p = try XCTUnwrap(HandoffSavings.pairs([old, new]).first)
        XCTAssertEqual(p.before, 200_000)
        XCTAssertEqual(p.after, 60_000)
        XCTAssertEqual(p.savedTokens, 140_000 * 4)
        // Narx: kamroq keshdan o'qish − yangi kontekstni bir marta keshga yozish
        XCTAssertEqual(p.savedWeighted, 560_000 * Pricing.cacheRead - 20_000 * (Pricing.cacheWrite5m - Pricing.cacheRead), accuracy: 0.01)
        XCTAssertFalse(p.reread)

        let s = HandoffSavings.summary([p])
        XCTAssertEqual(s.handoffs, 1)
        XCTAssertEqual(s.readTokens, 252_000)
        XCTAssertEqual(s.fraction, 560_000.0 / 812_000.0, accuracy: 0.0001)
        XCTAssertEqual(HandoffSavings.summary([p], since: t0.addingTimeInterval(200)).handoffs, 0)
    }

    func testOldCallsAfterHandoffAreIgnoredAndRereadIsSeen() throws {
        // Eski sessiyada ko'chirishdan keyin ham ishlangan — o'sha javoblar «oldin»ga kirmaydi
        let old = snap("old", prompt: "Ish", contexts: [200_000, 200_000, 200_000, 200_000, 200_000, 900_000], from: 95)
        let new = snap("new", prompt: handoffPrompt(old: "old"), contexts: [50_000], from: 100, stepInput: "{\"path\":\"/p/old.jsonl\"}")
        let p = try XCTUnwrap(HandoffSavings.pairs([old, new]).first)
        XCTAssertEqual(p.before, 200_000)
        XCTAssertTrue(p.reread)
    }

    func testNeedsOldSessionAndEnoughHistory() {
        let new = snap("new", prompt: handoffPrompt(old: "old"), contexts: [50_000], from: 100)
        XCTAssertTrue(HandoffSavings.pairs([new]).isEmpty)
        let short = snap("old", prompt: "Ish", contexts: [200_000, 200_000], from: 0)
        XCTAssertTrue(HandoffSavings.pairs([short, new]).isEmpty)
        let plain = snap("x", prompt: "oddiy so'rov", contexts: [10_000], from: 0)
        XCTAssertTrue(HandoffSavings.pairs([plain]).isEmpty)
    }
}
