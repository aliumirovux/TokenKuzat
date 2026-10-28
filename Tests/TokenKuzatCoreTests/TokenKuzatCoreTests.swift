import XCTest
@testable import TokenKuzatCore

final class ParserTests: XCTestCase {
    func testAssistantUsageAndWeight() throws {
        let line = """
        {"type":"assistant","timestamp":"2026-10-28T08:50:48.625Z","cwd":"/Users/x/proj","requestId":"r1",\
        "message":{"id":"m1","model":"claude-opus-5-5","stop_reason":"tool_use",\
        "content":[{"type":"thinking","thinking":""},{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/a/Engine.swift"}}],\
        "usage":{"input_tokens":10,"output_tokens":100,"output_tokens_details":{"thinking_tokens":40},\
        "cache_creation_input_tokens":1000,"cache_read_input_tokens":2000,\
        "cache_creation":{"ephemeral_1h_input_tokens":1000,"ephemeral_5m_input_tokens":0}}}}
        """
        let ev = try XCTUnwrap(TranscriptParser.parse(Data(line.utf8)))
        guard case .assistant(let a) = ev.kind else { return XCTFail("assistant kutilgan edi") }
        XCTAssertEqual(ev.cwd, "/Users/x/proj")
        XCTAssertEqual(a.model, "claude-opus-5-5")
        XCTAssertEqual(a.usageKey, "m1|r1")
        let u = try XCTUnwrap(a.usage)
        XCTAssertEqual(u.total, 3110)
        XCTAssertEqual(u.thinking, 40)
        // 10 + 100×5 + 1000×2 (1 soatlik kesh) + 2000×0,1
        XCTAssertEqual(u.weighted, 10 + 500 + 2000 + 200, accuracy: 0.001)
        XCTAssertEqual(a.items.count, 2)
        if case .tool(_, let name, let d) = a.items[1] {
            XCTAssertEqual(name, "Read")
            XCTAssertEqual(d.text, "O'qiyapti · Engine.swift")
        } else {
            XCTFail("tool kutilgan edi")
        }
    }

    func testUserPromptSkipsSystemTextAndMeta() throws {
        let line = """
        {"type":"user","message":{"role":"user","content":[\
        {"type":"text","text":"<system-reminder>ichki</system-reminder>"},\
        {"type":"text","text":"Loyihani ko'rib chiq\\nikkinchi qator"}]}}
        """
        let ev = try XCTUnwrap(TranscriptParser.parse(Data(line.utf8)))
        guard case .user(let u) = ev.kind else { return XCTFail() }
        XCTAssertEqual(u.prompts, ["Loyihani ko'rib chiq\nikkinchi qator"])

        let meta = #"{"type":"user","isMeta":true,"message":{"content":"Salom"}}"#
        guard case .user(let m) = try XCTUnwrap(TranscriptParser.parse(Data(meta.utf8))).kind else { return XCTFail() }
        XCTAssertTrue(m.prompts.isEmpty)
    }

    func testCustomTitleAndIgnoredTypes() {
        let t = #"{"type":"custom-title","customTitle":"Mening sessiyam"}"#
        if case .title(let s)? = TranscriptParser.parse(Data(t.utf8))?.kind {
            XCTAssertEqual(s, "Mening sessiyam")
        } else {
            XCTFail()
        }
        XCTAssertNil(TranscriptParser.parse(Data(#"{"type":"queue-operation"}"#.utf8)))
        XCTAssertNil(TranscriptParser.parse(Data("buzuq json".utf8)))
    }
}

final class FormatTests: XCTestCase {
    func testTokens() {
        XCTAssertEqual(Fmt.tokens(950), "950")
        XCTAssertEqual(Fmt.tokens(1_234), "1,2K")
        XCTAssertEqual(Fmt.tokens(123_456), "123K")
        XCTAssertEqual(Fmt.tokens(1_500_000), "1,5M")
        XCTAssertEqual(Fmt.tokens(25_000_000), "25M")
    }

    func testModel() {
        XCTAssertEqual(Fmt.model("claude-opus-5-5"), "Opus 5.5")
        XCTAssertEqual(Fmt.model("claude-sonnet-4-5-20250929"), "Sonnet 4.5")
        XCTAssertEqual(Fmt.model(""), "")
    }

    func testPercent() {
        XCTAssertEqual(Fmt.percent(1, of: 0), "0%")
        XCTAssertEqual(Fmt.percent(0.5, of: 100), "<1%")
        XCTAssertEqual(Fmt.percent(25, of: 100), "25%")
    }

    func testMcpShortName() {
        XCTAssertEqual(ToolDescriber.shortName("mcp__github__create_issue"), "github: create_issue")
        XCTAssertEqual(ToolDescriber.shortName("Bash"), "Bash")
    }
}

final class EngineTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("proj/s1/subagents"),
                                                withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    private func assistant(_ id: String, _ ts: Date, output: Int, cacheRead: Int = 0, agentId: String? = nil) -> String {
        let side = agentId.map { #","isSidechain":true,"agentId":"\#($0)""# } ?? ""
        return """
        {"type":"assistant","timestamp":"\(iso(ts))","cwd":"/tmp/MyApp","requestId":"r-\(id)"\(side),\
        "message":{"id":"\(id)","model":"claude-opus-5-5","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],\
        "usage":{"input_tokens":0,"output_tokens":\(output),"cache_creation_input_tokens":0,"cache_read_input_tokens":\(cacheRead)}}}
        """
    }

    private func write(_ rel: String, _ lines: [String]) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent(rel), atomically: true, encoding: .utf8)
    }

    func testDedupeSubagentsAndTotals() throws {
        let now = Date()
        let prompt = #"{"type":"user","timestamp":"\#(iso(now.addingTimeInterval(-60)))","message":{"content":"Testni yoz"}}"#
        // m1 ikki qatorga bo'lingan (bir xil usage) — bir marta sanalishi kerak
        try write("proj/s1.jsonl", [
            prompt,
            assistant("m1", now.addingTimeInterval(-30), output: 100),
            assistant("m1", now.addingTimeInterval(-30), output: 100),
            #"{"type":"custom-title","customTitle":"Test sessiyasi"}"#,
        ])
        try write("proj/s1/subagents/agent-abc.jsonl", [
            #"{"type":"user","isSidechain":true,"agentId":"abc","timestamp":"\#(iso(now.addingTimeInterval(-20)))","message":{"content":"Fayllarni top"}}"#,
            assistant("m2", now.addingTimeInterval(-10), output: 50, cacheRead: 1000, agentId: "abc"),
        ])
        try #"{"description":"Kod qidiruvchi","agentType":"Explore"}"#
            .write(to: root.appendingPathComponent("proj/s1/subagents/agent-abc.meta.json"), atomically: true, encoding: .utf8)

        let engine = Engine(config: Engine.Config(roots: [root]))
        let snap = engine.tick(now: now)

        XCTAssertEqual(snap.sessions.count, 1)
        let s = try XCTUnwrap(snap.sessions.first)
        XCTAssertEqual(s.project, "MyApp")
        XCTAssertEqual(s.title, "Test sessiyasi")
        XCTAssertEqual(s.mainTokens.total, 100)
        XCTAssertEqual(s.agentTokens.total, 1050)
        XCTAssertEqual(s.agents.count, 2)
        let helper = try XCTUnwrap(s.agents.first { !$0.isMain })
        XCTAssertEqual(helper.title, "Kod qidiruvchi")
        XCTAssertEqual(helper.subtitle, "Explore")
        XCTAssertEqual(helper.state, .running)
        XCTAssertEqual(snap.today.total, 1150)
        XCTAssertEqual(snap.lastFiveHours.total, 1150)
        XCTAssertEqual(snap.days.last?.tokens.total, 1150)
        XCTAssertGreaterThan(snap.rateRaw, 0)
        XCTAssertTrue(snap.feed.contains { $0.text == "Siz: Testni yoz" })
    }

    func testIncrementalTailAndPartialLine() throws {
        let now = Date()
        let url = root.appendingPathComponent("proj/s2.jsonl")
        try write("proj/s2.jsonl", [assistant("a1", now.addingTimeInterval(-5), output: 10)])
        let engine = Engine(config: Engine.Config(roots: [root]))
        XCTAssertEqual(engine.tick(now: now).today.total, 10)

        // Qator yarmi yozilgan — hali sanalmaydi
        let next = assistant("a2", now.addingTimeInterval(-2), output: 20)
        let h = try FileHandle(forWritingTo: url)
        h.seekToEndOfFile()
        h.write(Data(next.prefix(40).utf8))
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(1)).today.total, 10)
        h.write(Data((next.dropFirst(40) + "\n").utf8))
        try h.close()
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(2)).today.total, 30)
    }

    func testHistoryStoreKeepsLargerDay() throws {
        let url = root.appendingPathComponent("history.json")
        let store = HistoryStore(url: url)
        store.save(scanned: ["2026-10-01": TokenCounts(input: 500)])
        // Keyinroq transcript'ning faqat bir qismi qolgan — saqlangani kattaroq, o'zi qoladi
        let merged = store.merged(with: ["2026-10-01": TokenCounts(input: 100), "2026-10-02": TokenCounts(input: 7)])
        XCTAssertEqual(merged["2026-10-01"]?.total, 500)
        XCTAssertEqual(merged["2026-10-02"]?.total, 7)
        XCTAssertEqual(HistoryStore(url: url).days["2026-10-01"]?.total, 500)
    }

    func testAgentStateTimeline() {
        let now = Date()
        XCTAssertEqual(Engine.state(lastActivity: now.addingTimeInterval(-5), lastStop: "end_turn", now: now), .running)
        XCTAssertEqual(Engine.state(lastActivity: now.addingTimeInterval(-60), lastStop: "tool_use", now: now), .waiting)
        XCTAssertEqual(Engine.state(lastActivity: now.addingTimeInterval(-60), lastStop: "tool_result", now: now), .running)
        XCTAssertEqual(Engine.state(lastActivity: now.addingTimeInterval(-60), lastStop: "end_turn", now: now), .idle)
        XCTAssertEqual(Engine.state(lastActivity: nil, lastStop: nil, now: now), .idle)
    }
}
