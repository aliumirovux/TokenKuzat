import XCTest
@testable import TokenKuzatCore

final class SavingsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func step(_ i: Int, _ key: String, access: ToolAccess, failed: Bool = false) -> StepSnap {
        StepSnap(id: "s\(i)", date: t0.addingTimeInterval(Double(i)), symbol: "doc", text: "O'qiyapti · \(key)",
                 category: .files, targetName: key, targetKey: "files|/p/\(key)", targetDetail: "/p", access: access,
                 duration: 1, status: failed ? .failed : .done, turn: 1)
    }

    private func point(_ i: Int, context: Int, longCache: Bool? = nil) -> UsagePoint {
        UsagePoint(date: t0.addingTimeInterval(Double(i)), tokens: TokenCounts(cacheRead: context), longCache: longCache)
    }

    private func session(context: Int, steps: [StepSnap], calls: Int = 60, usage: [UsagePoint] = [],
                         bigResults: [BigResult] = []) -> SessionSnap {
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: calls, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: usage,
                             bigResults: bigResults)
        let turn = TurnSnap(id: 1, prompt: "Xaritani yangila", start: t0, end: t0.addingTimeInterval(60),
                            tokens: TokenCounts(), steps: steps.count, errors: 0, active: false)
        return SessionSnap(id: "s", project: "Demo", title: "t", model: "Opus", contextTokens: context,
                           tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                           lastActivity: t0, state: .idle, turns: [turn], contextWindow: 1_000_000)
    }

    func testBigContextTip() throws {
        let tips = SavingsAdvisor.tips(for: session(context: 500_000, steps: []), now: t0)
        let tip = try XCTUnwrap(tips.first { $0.kind == .bigContext })
        XCTAssertEqual(tip.level, .high)
        XCTAssertEqual(tip.tokens, 500_000 - SavingsAdvisor.baseline)
        XCTAssertTrue(tip.perCall)
    }

    func testSmallContextHasNoTip() {
        XCTAssertTrue(SavingsAdvisor.tips(for: session(context: 60_000, steps: []), now: t0).isEmpty)
    }

    func testRepeatedReadsResetAfterWrite() {
        // a.swift 4 marta o'qildi (3 takror), keyin yozildi, yana 1 marta — takror emas; b.swift 2 marta (1 takror)
        var st: [StepSnap] = (0..<4).map { step($0, "a.swift", access: .read) }
        st.append(step(10, "a.swift", access: .write))
        st.append(step(11, "a.swift", access: .read))
        st += [step(20, "b.swift", access: .read), step(21, "b.swift", access: .read)]
        let tip = SavingsAdvisor.tips(for: session(context: 60_000, steps: st), now: t0).first { $0.kind == .repeatedReads }
        XCTAssertEqual(tip?.title, "4 ta takroriy fayl o'qish")
    }

    func testHandoffListsChangedFiles() {
        let s = session(context: 400_000, steps: [step(1, "Map.swift", access: .write)])
        let text = SavingsAdvisor.handoff(for: s)
        XCTAssertTrue(text.contains("/p/Map.swift"))
        XCTAssertTrue(text.contains("#1: Xaritani yangila"))
    }

    func testCacheTTLFollowsLastWrite() {
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: session(context: 60_000, steps: [])), 300)
        let long = session(context: 60_000, steps: [], usage: [point(0, context: 50_000, longCache: true), point(1, context: 51_000)])
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: long), 3600)
        let short = session(context: 60_000, steps: [], usage: [point(0, context: 50_000, longCache: false)])
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: short), 300)
    }

    func testBigContextSavingUsesRealStart() throws {
        let s = session(context: 500_000, steps: [], usage: [point(0, context: 100_000), point(1, context: 500_000)])
        let tip = try XCTUnwrap(SavingsAdvisor.tips(for: s, now: t0).first { $0.kind == .bigContext })
        XCTAssertEqual(tip.tokens, 400_000)
    }

    func testCarriedStopsAtCompact() {
        // natija 5-soniyada; keyin 3 chaqiruv, so'ng /compact (kontekst 300K → 50K) — undan keyingilari sanalmaydi
        let usage = [point(4, context: 280_000), point(6, context: 290_000), point(7, context: 295_000),
                     point(8, context: 300_000), point(9, context: 50_000), point(10, context: 55_000)]
        let r = BigResult(date: t0.addingTimeInterval(5), tokens: 10_000, label: "Bash")
        XCTAssertEqual(SavingsAdvisor.carried(r, usage: usage), 30_000)
        XCTAssertTrue(SavingsAdvisor.liveResults([r], usage: usage).isEmpty)
    }

    func testBigResultsTip() throws {
        let usage = (0..<200).map { point($0, context: 200_000) }
        let r = BigResult(date: t0, tokens: 13_000, label: "c0f5615a-4595-4276-aa56-75e4262a0883: search_screens")
        let s = session(context: 200_000, steps: [], usage: usage, bigResults: [r, r])
        let tip = try XCTUnwrap(SavingsAdvisor.tips(for: s, now: t0).first { $0.kind == .bigResults })
        XCTAssertEqual(tip.tokens, 2 * 13_000 * 199)
        XCTAssertTrue(tip.detail.contains("search_screens ×2 — 26,0K"), tip.detail)
        XCTAssertFalse(tip.detail.contains("c0f5615a"))
    }

    func testHeavyStartTip() {
        let heavy = session(context: 120_000, steps: [], calls: 40, usage: [point(0, context: 103_000)])
        XCTAssertNotNil(SavingsAdvisor.tips(for: heavy, now: t0).first { $0.kind == .heavyStart })
        let light = session(context: 120_000, steps: [], calls: 40, usage: [point(0, context: 45_000)])
        XCTAssertNil(SavingsAdvisor.tips(for: light, now: t0).first { $0.kind == .heavyStart })
    }

    func testResultTokens() {
        XCTAssertEqual(TranscriptParser.resultTokens(String(repeating: "a", count: 4000)), 1000)
        let blocks: [[String: Any]] = [["type": "text", "text": String(repeating: "b", count: 400)], ["type": "image"]]
        XCTAssertEqual(TranscriptParser.resultTokens(blocks), 100 + 1_600)
    }
}
