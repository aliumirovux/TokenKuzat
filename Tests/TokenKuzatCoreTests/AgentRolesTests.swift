import XCTest
@testable import TokenKuzatCore

final class AgentRolesTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func agent(_ kind: String, main: Bool = false, tokens: Int = 100, reads: Int = 0) -> AgentSnap {
        AgentSnap(id: kind, title: kind, subtitle: "", kind: kind, isMain: main, tokens: TokenCounts(cacheRead: tokens), calls: 2,
                  topTools: [], lastAction: "", state: .idle, lastActivity: t0, firstActivity: t0,
                  steps: [], resources: [], usage: [], bigResults: [], reads: reads)
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
        XCTAssertEqual(AgentRole.of(agent("tokenkuzat:sinovchi")), .tester)
        XCTAssertEqual(AgentRole.of(agent("qa")), .tester)
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

    // MARK: Tejash hisobi

    private func at(_ sec: Double) -> Date { t0.addingTimeInterval(sec) }

    /// Bitta javob: kontekst `ctx` (birinchi chaqiruvda keshga yoziladi, keyingilarida o'qiladi), og'irligi `Pricing` bo'yicha
    private func pt(_ sec: Double, _ ctx: Int, write: Bool = false, out: Int = 0) -> UsagePoint {
        let w = write ? ctx : 0, r = write ? 0 : ctx
        let weighted = Pricing.weigh(input: 0, output: out, cacheRead: r, cacheWrite: w)
        return UsagePoint(date: at(sec), tokens: TokenCounts(output: out, cacheWrite: w, cacheRead: r, weighted: weighted))
    }

    private func sum(_ points: [UsagePoint]) -> TokenCounts { points.reduce(TokenCounts()) { $0 + $1.tokens } }

    private func lead(_ points: [UsagePoint], model: String? = "claude-opus-5-5", born: Date? = nil) -> AgentSnap {
        AgentSnap(id: "l", title: "l", subtitle: "", kind: "", isMain: true, tokens: sum(points), calls: points.count,
                  topTools: [], lastAction: "", state: .idle, lastActivity: points.last?.date, firstActivity: born ?? points.first?.date,
                  steps: [], resources: [], usage: points, model: model)
    }

    private func helper(_ points: [UsagePoint], model: String? = "claude-opus-5-5", last: Date? = nil, kind: String = "tokenkuzat:izlovchi") -> AgentSnap {
        AgentSnap(id: "h", title: "h", subtitle: "", kind: kind, isMain: false, tokens: sum(points), calls: points.count,
                  topTools: [], lastAction: "", state: .idle, lastActivity: last ?? points.last?.date, firstActivity: points.first?.date,
                  steps: [], resources: [], usage: points, model: model)
    }

    private func flat(_ times: [Double], ctx: Int) -> [UsagePoint] { times.map { pt($0, ctx) } }

    func testHaikuHelperUnderOpusLeadSavesIncludingModelTerm() {
        let l = lead(flat([0, 100, 200, 210, 220, 230], ctx: 100_000))
        let pts = [pt(10, 10_000, write: true), pt(80, 20_000), pt(150, 30_000, out: 500)]
        let e = AgentRoleUsage.estimate(helper: helper(pts, model: "claude-haiku-5-5"), lead: l)
        // H.weighted = 12500 + 2000 + (3000 + 2500) = 20000
        XCTAssertEqual(e.actual, 20_000 * 0.2, accuracy: 0.001)
        // ownWork = 20000 - 12500 - 10000*0.1*2 = 5500; leadRereads = 3*100000*0.1; kept = min(20000, 100000) - 500 (xulosa), 4 javob keyin
        let cf = 5_500.0 + 30_000 + 19_500 * 4 * 0.1
        XCTAssertEqual(try XCTUnwrap(e.saved), cf - 4_000, accuracy: 0.001)
        // Bir xil modelda tejash 20000*0.8 kam bo'lardi
        let same = AgentRoleUsage.estimate(helper: helper(pts), lead: l)
        XCTAssertEqual(try XCTUnwrap(e.saved) - XCTUnwrap(same.saved), 20_000 * 0.8, accuracy: 0.001)
    }

    func testRowTierAndEfficiency() {
        let l = lead(flat([0, 100, 200, 210, 220, 230], ctx: 100_000))
        let h = helper([pt(10, 10_000, write: true), pt(80, 20_000), pt(150, 30_000, out: 500)], model: "claude-haiku-5-5")
        let s = AgentRoleUsage.summary([session([l, h, agent("general-purpose")])], since: t0.addingTimeInterval(-60))
        let row = { (r: AgentRole) in s.rows.first { $0.role == r } }
        XCTAssertEqual(row(.lead)?.tier, .opus)
        XCTAssertEqual(row(.explorer)?.tier, .haiku)
        // Modeli noma'lum yordamchi — rahbar modelida; usage'siz — tejash hisoblanmaydi
        XCTAssertEqual(row(.other)?.tier, .opus)
        XCTAssertNil(row(.other)?.efficiency)
        let e = AgentRoleUsage.estimate(helper: h, lead: l)
        XCTAssertEqual(try XCTUnwrap(row(.explorer)?.efficiency), try XCTUnwrap(e.saved) / e.actual, accuracy: 0.001)
        XCTAssertEqual(s.helperAgents, 2)

        let sonnetLead = AgentSnap(id: "s", title: "s", subtitle: "", kind: "", isMain: true, tokens: TokenCounts(cacheRead: 10), calls: 1,
                                   topTools: [], lastAction: "", state: .idle, lastActivity: t0, firstActivity: t0,
                                   steps: [], resources: [], usage: [], model: "claude-sonnet-5-5")
        let mixed = AgentRoleUsage.summary([session([l]), session([sonnetLead])], since: t0.addingTimeInterval(-60))
        XCTAssertEqual(mixed.rows.first?.tier, .mixed)
        // Bir turda Haiku va rahbar modelidagi yordamchi — aralash; Claude bo'lmagan model rahbar darajasini olmaydi
        let explore = helper([pt(10, 5_000, write: true)], model: nil, kind: "Explore")
        let free = AgentSnap(id: "f", title: "f", subtitle: "", kind: "general-purpose", isMain: false, tokens: TokenCounts(cacheRead: 10), calls: 1,
                             topTools: [], lastAction: "", state: .idle, lastActivity: t0, firstActivity: t0,
                             steps: [], resources: [], usage: [], model: "llama-3")
        let helpers = AgentRoleUsage.summary([session([l, h]), session([l, explore, free])], since: t0.addingTimeInterval(-60))
        XCTAssertEqual(helpers.rows.first { $0.role == .explorer }?.tier, .mixed)
        XCTAssertNil(helpers.rows.first { $0.role == .other }?.tier)
        XCTAssertEqual(ModelTier.of("claude-haiku-5-5")?.multiplier, 1)
        XCTAssertNil(ModelTier.of("gpt"))
    }

    func testSameModelSmallLoadedSmallLeadContextIsNegative() {
        let l = lead(flat([0, 300], ctx: 5_000))
        let h = helper([pt(10, 20_000, write: true), pt(50, 20_000), pt(90, 20_000)])
        let e = AgentRoleUsage.estimate(helper: h, lead: l)
        // ownWork = 29000 - 25000 - 20000*0.1*2 -> 0; leadRereads = 3*5000*0.1 = 1500; loaded = 0
        XCTAssertEqual(try XCTUnwrap(e.saved), 1_500 - 29_000, accuracy: 0.001)
    }

    func testCallsAfterUsesLastActivity() {
        let l = lead(flat([0, 60, 120, 180], ctx: 1_000))
        let pts = [pt(30, 1_000, write: true), pt(90, 11_000)]
        func saved(_ last: Double) -> Double { AgentRoleUsage.estimate(helper: helper(pts, last: at(last)), lead: l).saved ?? .nan }
        // loaded = 10000 -> har keyingi javob 1000 token
        XCTAssertEqual(saved(90) - saved(200), 2_000, accuracy: 0.001)   // 120 va 180 keyin
        XCTAssertEqual(saved(120) - saved(200), 1_000, accuracy: 0.001)  // faqat 180 (120 > 120 emas)
    }

    func testCompactStopsCallsAfter() {
        let helperPts = [pt(10, 10_000, write: true), pt(150, 30_000)]   // loaded = 20000
        let plain = lead(flat([0, 100, 200, 210, 220, 230], ctx: 100_000))
        let compacted = lead(flat([0, 100, 200, 210], ctx: 100_000) + flat([220, 230], ctx: 10_000))
        let a = AgentRoleUsage.estimate(helper: helper(helperPts), lead: plain).saved
        let b = AgentRoleUsage.estimate(helper: helper(helperPts), lead: compacted).saved
        // /compact dan keyin (kontekst 60% dan past) sanalmaydi: 4 emas, 2 ta javob
        XCTAssertEqual(try XCTUnwrap(a) - XCTUnwrap(b), 20_000 * 2 * 0.1, accuracy: 0.001)
    }

    func testKeptContentCappedByContextWindow() {
        let l = lead(flat([0, 100, 200, 210], ctx: 190_000))
        let h = helper([pt(10, 10_000, write: true), pt(150, 60_000)])   // loaded = 50000, joy faqat 10000
        let e = AgentRoleUsage.estimate(helper: h, lead: l)
        // H.weighted = 12500 + 6000; ownWork = 18500 - 12500 - 1000 = 5000; leadRereads = 2*190000*0.1; kept = 10000 * 2 javob
        XCTAssertEqual(try XCTUnwrap(e.saved), 5_000 + 38_000 + 10_000 * 2 * 0.1 - 18_500, accuracy: 0.001)
    }

    func testWindowRoomIsSharedBetweenHelpers() {
        // Rahbar konteksti 154K -> oynada 46K joy; ikki yordamchi 40K dan yuklagan, ikkalasi ham rahbarning keyingi javoblarini kutadi
        let l = lead(flat([0, 100, 200, 210, 220], ctx: 154_000))
        func h(_ id: String, end: Double) -> AgentSnap {
            let pts = [pt(10, 10_000, write: true), pt(end, 50_000)]
            let a = helper(pts)
            return AgentSnap(id: id, title: id, subtitle: "", kind: "general-purpose", isMain: false, tokens: a.tokens, calls: a.calls,
                             topTools: [], lastAction: "", state: .idle, lastActivity: a.lastActivity, firstActivity: a.firstActivity,
                             steps: [], resources: [], usage: pts, model: a.model)
        }
        let h1 = h("h1", end: 120), h2 = h("h2", end: 140)
        let e1 = AgentRoleUsage.estimate(helper: h1, lead: l)
        XCTAssertEqual(e1.kept, 40_000, accuracy: 0.001)
        let e2 = AgentRoleUsage.estimate(helper: h2, lead: l, alreadyKept: e1.kept)
        XCTAssertEqual(e2.kept, 6_000, accuracy: 0.001)   // 46K - 40K
        XCTAssertLessThanOrEqual(e1.kept + e2.kept, 46_000)

        // summary() yordamchilarni tugash vaqti bo'yicha shu tarzda ketma-ket hisoblaydi (agentlar tartibidan qat'i nazar)
        let s = AgentRoleUsage.summary([session([l, h2, h1])], since: t0.addingTimeInterval(-60))
        let expected = try? XCTUnwrap(e1.saved) + XCTUnwrap(e2.saved)
        XCTAssertEqual(s.totalSaved, try XCTUnwrap(expected), accuracy: 0.001)
    }

    func testHelperStartingBeforeLeadFirstPoint() {
        let helperPts = [pt(10, 10_000, write: true), pt(50, 10_000)]
        // Rahbarning birinchi nuqtasi yordamchidan keyin va usage kesilmagan -> kontekst 0
        let intact = lead(flat([100, 200], ctx: 80_000))
        // Shu, lekin rahbar yozuvi boshidan kesilgan (firstActivity oldinroq) -> eng eski nuqta konteksti
        let truncated = lead(flat([100, 200], ctx: 80_000), born: at(-500))
        let a = try? XCTUnwrap(AgentRoleUsage.estimate(helper: helper(helperPts), lead: intact).saved)
        let b = try? XCTUnwrap(AgentRoleUsage.estimate(helper: helper(helperPts), lead: truncated).saved)
        XCTAssertEqual(try XCTUnwrap(b) - XCTUnwrap(a), 2 * 80_000 * 0.1, accuracy: 0.001)
    }

    func testNilModelsUseRatioOne() {
        let l = lead(flat([0, 100], ctx: 50_000), model: nil)
        let h = helper([pt(10, 10_000, write: true), pt(20, 10_000)], model: nil)
        let e = AgentRoleUsage.estimate(helper: h, lead: l)
        XCTAssertEqual(e.actual, h.tokens.weighted, accuracy: 0.001)
        XCTAssertNotNil(e.saved)
    }

    func testNoLeadOrNoUsageGivesNoEstimate() {
        let h = helper([pt(10, 10_000, write: true), pt(20, 10_000)], model: "claude-haiku-5-5")
        let noLead = AgentRoleUsage.estimate(helper: h, lead: nil)
        XCTAssertNil(noLead.saved)
        XCTAssertEqual(noLead.actual, h.tokens.weighted * 0.2, accuracy: 0.001)   // narx baribir hisobga olinadi

        let s1 = AgentRoleUsage.summary([session([h])], since: t0.addingTimeInterval(-60))
        XCTAssertFalse(s1.hasEstimate)
        XCTAssertEqual(s1.totalSaved, 0)
        XCTAssertEqual(s1.savedPercent, 0)
        XCTAssertEqual(s1.totalActual, h.tokens.weighted * 0.2, accuracy: 0.001)

        // Rahbar bor, lekin yordamchida usage yo'q
        let l = lead(flat([0, 100], ctx: 50_000))
        let s2 = AgentRoleUsage.summary([session([l, agent("tokenkuzat:izlovchi", tokens: 300)])], since: t0.addingTimeInterval(-60))
        XCTAssertFalse(s2.rows[1].hasEstimate)
        XCTAssertFalse(s2.hasEstimate)
    }

    func testModelRatioParsing() {
        XCTAssertEqual(ModelPrice.ratio("claude-haiku-5-5"), ModelPrice.haiku)
        XCTAssertEqual(ModelPrice.ratio("Sonnet 5.5"), ModelPrice.sonnet)
        XCTAssertEqual(ModelPrice.ratio("claude-OPUS-5"), ModelPrice.opus)
        XCTAssertNil(ModelPrice.ratio(nil))
        XCTAssertNil(ModelPrice.ratio("gpt-oss-120b"))
    }

    func testSummaryUsesOpusEquivalentUnitAndAggregates() {
        // Rahbar Sonnet: o'z sarfi ham Opus-ekvivalentga keltiriladi
        let l = lead(flat([0, 300], ctx: 100_000), model: "claude-sonnet-5-5")
        let h = helper([pt(10, 10_000, write: true), pt(50, 10_000)], model: "claude-haiku-5-5")
        let s = AgentRoleUsage.summary([session([l, h])], since: t0.addingTimeInterval(-60))
        let e = AgentRoleUsage.estimate(helper: h, lead: l)
        XCTAssertEqual(s.rows[0].actual, l.tokens.weighted * 0.6, accuracy: 0.001)
        XCTAssertFalse(s.rows[0].hasEstimate)
        XCTAssertEqual(s.rows[1].saved, try XCTUnwrap(e.saved), accuracy: 0.001)
        XCTAssertEqual(s.totalSaved, try XCTUnwrap(e.saved), accuracy: 0.001)
        XCTAssertEqual(s.totalActual, l.tokens.weighted * 0.6 + h.tokens.weighted * 0.2, accuracy: 0.001)
        XCTAssertEqual(s.savedPercent, s.totalSaved / (s.totalActual + s.totalSaved) * 100, accuracy: 0.001)
        XCTAssertEqual(AgentRoleUsage.summary([], since: t0).savedPercent, 0)
    }

    func testNegativeTotalSavedGivesNegativePercent() {
        let l = lead(flat([0, 300], ctx: 5_000))
        let h = helper([pt(10, 20_000, write: true), pt(50, 20_000), pt(90, 20_000)])
        let s = AgentRoleUsage.summary([session([l, h])], since: t0.addingTimeInterval(-60))
        XCTAssertLessThan(s.totalSaved, 0)
        XCTAssertLessThan(s.savedPercent, 0)
        XCTAssertEqual(s.savedPercent, s.totalSaved / (s.totalActual + s.totalSaved) * 100, accuracy: 0.001)
        // Maxraj nolga yoki undan pastga tushsa — 0
        var broken = AgentRoleUsage.Summary()
        broken.totalActual = 100
        broken.totalSaved = -150
        XCTAssertEqual(broken.savedPercent, 0)
    }
}
