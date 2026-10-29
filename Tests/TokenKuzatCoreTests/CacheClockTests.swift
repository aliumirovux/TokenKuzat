import XCTest
@testable import TokenKuzatCore

final class CacheClockTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(context: Int, usage: [UsagePoint]) -> SessionSnap {
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: usage.count, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: [], resources: [], usage: usage)
        return SessionSnap(id: "s", project: "Demo", title: "t", model: "Opus", contextTokens: context,
                           tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                           lastActivity: t0, state: .idle, turns: [])
    }

    private func point(_ at: TimeInterval, longCache: Bool? = nil) -> UsagePoint {
        UsagePoint(date: t0.addingTimeInterval(at), tokens: TokenCounts(cacheRead: 300_000), longCache: longCache)
    }

    func testFiveMinuteCacheExpiresAfterLastCall() throws {
        let c = try XCTUnwrap(CacheClock.of(session(context: 300_000, usage: [point(0), point(40)])))
        XCTAssertEqual(c.expiresAt, t0.addingTimeInterval(40 + 300))
        XCTAssertEqual(c.tokens, 300_000)
        XCTAssertEqual(c.warnBefore, 60)
        XCTAssertEqual(c.coldMultiplier, 13)
        XCTAssertFalse(c.isEnding(at: t0.addingTimeInterval(200)))
        XCTAssertTrue(c.isEnding(at: t0.addingTimeInterval(300)))
        XCTAssertFalse(c.isWarm(at: t0.addingTimeInterval(341)))
        XCTAssertEqual(c.remaining(at: t0.addingTimeInterval(400)), 0)
    }

    func testOneHourCacheFromLastCacheWrite() throws {
        // Oxirgi chaqiruv faqat o'qigan — muddat oxirgi yozuvdan (1 soat) olinadi
        let c = try XCTUnwrap(CacheClock.of(session(context: 300_000, usage: [point(0, longCache: true), point(30)])))
        XCTAssertEqual(c.ttl, SavingsAdvisor.longCacheTTL)
        XCTAssertEqual(c.expiresAt, t0.addingTimeInterval(30 + 3600))
        XCTAssertEqual(c.warnBefore, 300)
        XCTAssertEqual(c.coldMultiplier, 20)
    }

    func testSmallContextOrNoCallsHasNoClock() {
        XCTAssertNil(CacheClock.of(session(context: 20_000, usage: [point(0)])))
        XCTAssertNil(CacheClock.of(session(context: 300_000, usage: [])))
    }

    func testCountdown() {
        XCTAssertEqual(CacheClock.countdown(245), "4:05")
        XCTAssertEqual(CacheClock.countdown(0.2), "0:01")
        Lang.with(english: false) { XCTAssertEqual(CacheClock.countdown(3000), "50 daq") }
    }
}
