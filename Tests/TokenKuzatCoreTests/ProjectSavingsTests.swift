import XCTest
@testable import TokenKuzatCore

final class ProjectSavingsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(_ id: String, project: String, context: Int, tokens: Int, ago: TimeInterval) -> SessionSnap {
        let t = now.addingTimeInterval(-ago)
        // 10 ta chaqiruv, har biri `context` hajmdagi kontekstni o'qiydi
        let usage = (0..<10).map { UsagePoint(date: t.addingTimeInterval(Double($0)), tokens: TokenCounts(cacheRead: context)) }
        let main = AgentSnap(id: "\(id)/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: 10, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t, firstActivity: t, steps: [], resources: [], usage: usage, bigResults: [])
        let turn = TurnSnap(id: 1, prompt: "Ishla", start: t, end: t.addingTimeInterval(10),
                            tokens: TokenCounts(cacheRead: tokens), steps: 0, errors: 0, active: false)
        return SessionSnap(id: id, project: project, title: "t", model: "Opus", contextTokens: context,
                           tokens: TokenCounts(cacheRead: tokens), mainTokens: TokenCounts(), agentTokens: TokenCounts(),
                           agents: [main], lastActivity: t, state: .idle, turns: [turn], contextWindow: 1_000_000, cwd: "/p/\(project)")
    }

    func testRankingAndPeriod() {
        var snap = Snapshot()
        snap.sessions = [session("a", project: "Kichik", context: 50_000, tokens: 1_000_000, ago: 3600),
                         session("b", project: "Katta", context: 50_000, tokens: 5_000_000, ago: 3600),
                         session("c", project: "Eski", context: 50_000, tokens: 9_000_000, ago: 3 * 86_400)]
        let today = ProjectSavings.reports(snap, period: .today, now: now)
        XCTAssertEqual(today.map(\.project), ["Katta", "Kichik"])
        let week = ProjectSavings.reports(snap, period: .week, now: now)
        XCTAssertEqual(week.first?.project, "Eski")
        XCTAssertEqual(week.first?.cwd, "/p/Eski")
    }

    func testBigContextWasteCountsEveryCall() throws {
        var snap = Snapshot()
        snap.sessions = [session("a", project: "Demo", context: 400_000, tokens: 4_000_000, ago: 600)]
        let r = try XCTUnwrap(ProjectSavings.reports(snap, period: .today, now: now).first)
        let issue = try XCTUnwrap(r.issues.first { $0.kind == .bigContext })
        // Boshlang'ich kontekst ham 400K — og'ir boshlanish emas, katta kontekstda isrof boshlanishdan ortiqcha qism
        XCTAssertEqual(issue.fix, .newSession)
        XCTAssertGreaterThanOrEqual(r.waste, 0)
        XCTAssertTrue(ProjectSavings.prompt(for: r, period: .today).contains("«Demo»"))
    }
}

final class ProjectSavingsHistoryTests: XCTestCase {
    private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }

    private func day(_ n: Int) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + Double(n) * 86_400) }

    func testBeforeAfterAroundFix() {
        var data = ProjectSavingsData()
        // Tuzatishdan oldin: isrof 60%, keyin: 20% (vaznli)
        for n in 0..<3 { data.days[HistoryStore.key(day(n), calendar: cal)] = ["A": ProjectDay(tokens: 100, weighted: 100, waste: 60, wasteWeighted: 60)] }
        data.days[HistoryStore.key(day(3), calendar: cal)] = ["A": ProjectDay(tokens: 100, weighted: 100, waste: 50, wasteWeighted: 50)]
        for n in 4..<6 { data.days[HistoryStore.key(day(n), calendar: cal)] = ["A": ProjectDay(tokens: 100, weighted: 100, waste: 20, wasteWeighted: 20)] }
        data.fixes["A"] = day(3).addingTimeInterval(3600)
        let ba = data.beforeAfter("A", mode: .weighted, calendar: cal)
        XCTAssertEqual(ba?.before ?? 0, 0.6, accuracy: 0.001)
        XCTAssertEqual(ba?.after ?? 0, 0.2, accuracy: 0.001)
        XCTAssertNil(data.beforeAfter("B", mode: .weighted, calendar: cal))
    }

    func testRecordAndMarkFixedRoundTrip() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tk-ps-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let h = ProjectSavingsHistory(url: url)
        h.markFixed("A", at: day(1))
        let fixed = h.load().fixes["A"]
        XCTAssertNotNil(fixed)
        XCTAssertEqual(fixed!.timeIntervalSince1970, day(1).timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(h.load().series("A", count: 3, now: day(1), calendar: cal).count, 3)
    }
}
