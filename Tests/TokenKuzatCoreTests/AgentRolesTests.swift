import XCTest
@testable import TokenKuzatCore

final class AgentRolesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func agent(_ kind: String, main: Bool = false, tokens: Int = 100, reads: Int = 0) -> AgentSnap {
        AgentSnap(id: kind, title: kind, subtitle: "", kind: kind, isMain: main, tokens: TokenCounts(cacheRead: tokens), calls: 2,
                  topTools: reads > 0 ? [("Read", reads)] : [], lastAction: "", state: .idle, lastActivity: t0, firstActivity: t0,
                  steps: [], resources: [], usage: [], bigResults: [])
    }

    private func session(_ agents: [AgentSnap]) -> SessionSnap {
        SessionSnap(id: UUID().uuidString, project: "Demo", title: "t", model: "Opus", contextTokens: 0, tokens: TokenCounts(),
                    mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: agents, lastActivity: t0, state: .idle, turns: [])
    }

    func testRolesFromAgentTypes() {
        XCTAssertEqual(AgentRole.of(agent("", main: true)), .lead)
        XCTAssertEqual(AgentRole.of(agent("tokenkuzat:izlovchi")), .explorer)
        XCTAssertEqual(AgentRole.of(agent("Explore")), .explorer)
        XCTAssertEqual(AgentRole.of(agent("tokenkuzat:bajaruvchi")), .builder)
        XCTAssertEqual(AgentRole.of(agent("tokenkuzat:tekshiruvchi")), .reviewer)
        XCTAssertEqual(AgentRole.of(agent("general-purpose")), .other)
    }

    func testSummaryByRoleAndHeavyLead() {
        let a = session([agent("", main: true, tokens: 1000), agent("tokenkuzat:izlovchi", tokens: 300), agent("Explore", tokens: 200)])
        let b = session([agent("", main: true, tokens: 500, reads: 40)])
        let s = AgentRoleUsage.summary([a, b], since: t0.addingTimeInterval(-60))
        XCTAssertEqual(s.rows.map(\.role), [.lead, .explorer])
        XCTAssertEqual(s.rows[0].tokens.cacheRead, 1500)
        XCTAssertEqual(s.rows[1].agents, 2)
        XCTAssertEqual(s.heavyLeadSessions, 1)
        XCTAssertTrue(s.helpersUsed)
        XCTAssertEqual(AgentRoleUsage.summary([a], since: t0.addingTimeInterval(60)).sessions, 0)
    }
}
