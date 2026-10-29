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
        if case .tool(_, let name, let d, let target, _) = a.items[1] {
            XCTAssertEqual(target.category, .files)
            XCTAssertEqual(target.name, "Engine.swift")
            XCTAssertEqual(target.access, .read)
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

    func testPromptAfterLeadingSystemReminder() {
        // Boshqa sessiyadan ochilgan sessiya: topshiriq «<system-reminder>» bloklari ortidan keladi
        XCTAssertEqual(TranscriptParser.prompt("<system-reminder>\nholat\n</system-reminder>\n<system-reminder>b</system-reminder>\nTask: tarjima qil"),
                       "Task: tarjima qil")
        XCTAssertNil(TranscriptParser.prompt("<system-reminder>faqat tizim</system-reminder>"))
        XCTAssertNil(TranscriptParser.prompt("<task-notification>x</task-notification>"))
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

final class ProcessTrackingTests: XCTestCase {
    func testStepsAndResources() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-steps-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        func ts(_ s: Double) -> String { f.string(from: now.addingTimeInterval(s)) }
        func use(_ id: String, _ t: Double, _ name: String, _ input: String) -> String {
            #"{"type":"assistant","timestamp":"\#(ts(t))","message":{"id":"m\#(id)","content":[{"type":"tool_use","id":"\#(id)","name":"\#(name)","input":\#(input)}]}}"#
        }
        func result(_ id: String, _ t: Double, error: Bool = false) -> String {
            #"{"type":"user","timestamp":"\#(ts(t))","message":{"content":[{"type":"tool_result","tool_use_id":"\#(id)","is_error":\#(error)}]}}"#
        }
        let lines = [
            use("t1", -60, "Read", #"{"file_path":"/x/App.swift"}"#), result("t1", -58),
            use("t2", -50, "Edit", #"{"file_path":"/x/App.swift"}"#), result("t2", -49),
            use("t3", -40, "Bash", #"{"command":"cd /x && swift build","description":"Build"}"#), result("t3", -30, error: true),
            use("t4", -5, "WebFetch", #"{"url":"https://example.com/a"}"#),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)

        let snap = Engine(config: Engine.Config(roots: [root])).tick(now: now)
        let main = try XCTUnwrap(snap.sessions.first?.main)
        XCTAssertEqual(main.steps.map(\.id), ["t1", "t2", "t3", "t4"])
        XCTAssertEqual(main.steps[0].status, .done)
        XCTAssertEqual(main.steps[0].duration ?? 0, 2, accuracy: 0.01)
        XCTAssertEqual(main.steps[2].status, .failed)
        XCTAssertEqual(main.steps[3].status, .running)

        let files = try XCTUnwrap(main.resources.first { $0.category == .files })
        XCTAssertEqual(files.items.count, 1)
        XCTAssertEqual(files.items[0].reads, 1)
        XCTAssertEqual(files.items[0].writes, 1)
        let shell = try XCTUnwrap(main.resources.first { $0.category == .shell })
        XCTAssertEqual(shell.items.first?.name, "swift")
        XCTAssertEqual(shell.errors, 1)
        let web = try XCTUnwrap(main.resources.first { $0.category == .web })
        XCTAssertTrue(web.busy)
        XCTAssertEqual(main.resources.first?.category, .web)
    }
}

final class ActivityMonitorTests: XCTestCase {
    private var root: URL!
    private let f: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-mon-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func use(_ id: String, _ t: Date, _ cmd: String = "swift build") -> String {
        #"{"type":"assistant","timestamp":"\#(f.string(from: t))","message":{"id":"m\#(id)","stop_reason":"tool_use","content":[{"type":"tool_use","id":"\#(id)","name":"Bash","input":{"command":"\#(cmd)"}}],"usage":{"input_tokens":0,"output_tokens":10}}}"#
    }
    private func result(_ id: String, _ t: Date, error: Bool = false) -> String {
        #"{"type":"user","timestamp":"\#(f.string(from: t))","message":{"content":[{"type":"tool_result","tool_use_id":"\#(id)","is_error":\#(error)}]}}"#
    }
    private func end(_ t: Date) -> String {
        #"{"type":"assistant","timestamp":"\#(f.string(from: t))","message":{"id":"end\#(t.timeIntervalSince1970)","stop_reason":"end_turn","content":[{"type":"text","text":"Tayyor"}],"usage":{"input_tokens":0,"output_tokens":5}}}"#
    }
    private func append(_ lines: [String]) throws {
        let url = root.appendingPathComponent("p/s.jsonl")
        if !FileManager.default.fileExists(atPath: url.path) { FileManager.default.createFile(atPath: url.path, contents: nil) }
        let h = try FileHandle(forWritingTo: url)
        h.seekToEndOfFile()
        h.write(Data((lines.joined(separator: "\n") + "\n").utf8))
        try h.close()
    }

    func testFinishedStuckAndErrorStreak() throws {
        let t0 = Date()
        let engine = Engine(config: Engine.Config(roots: [root]))
        let mon = ActivityMonitor()
        let cfg = ActivityMonitor.Config(finishMin: 60, stuckAfter: 90, errorStreak: 3)

        // Ish boshlandi
        try append([#"{"type":"user","timestamp":"\#(f.string(from: t0))","message":{"content":"Build qil"}}"#, use("a", t0)])
        XCTAssertTrue(mon.process(engine.tick(now: t0.addingTimeInterval(1)), config: cfg).isEmpty)

        // Qadam 100 s dan beri tugamadi → «osildi» (bir marta)
        let stuck = mon.process(engine.tick(now: t0.addingTimeInterval(100)), config: cfg)
        XCTAssertEqual(stuck.count, 1)
        if case .stuck(_, let d) = stuck.first?.kind { XCTAssertEqual(d, 100, accuracy: 1) } else { XCTFail() }
        XCTAssertTrue(mon.process(engine.tick(now: t0.addingTimeInterval(101)), config: cfg).isEmpty)

        // Uch marta ketma-ket xato
        try append([result("a", t0.addingTimeInterval(102), error: true),
                    use("b", t0.addingTimeInterval(103)), result("b", t0.addingTimeInterval(104), error: true),
                    use("c", t0.addingTimeInterval(105)), result("c", t0.addingTimeInterval(106), error: true)])
        let errs = mon.process(engine.tick(now: t0.addingTimeInterval(107)), config: cfg)
        XCTAssertEqual(errs.map(\.kind), [.errorStreak(count: 3, lastStep: "Terminal · swift build")])

        // Javob yozib tugatdi → 15 s dan keyin tinch → «tugadi»
        try append([end(t0.addingTimeInterval(110))])
        XCTAssertTrue(mon.process(engine.tick(now: t0.addingTimeInterval(111)), config: cfg).isEmpty)
        let done = mon.process(engine.tick(now: t0.addingTimeInterval(130)), config: cfg)
        guard case .finished(let d, let tokens, let steps)? = done.first?.kind else { return XCTFail("tugadi kutilgan edi") }
        XCTAssertEqual(d, 109, accuracy: 1)
        XCTAssertEqual(tokens, 25)
        XCTAssertEqual(steps, 2)
    }

    func testNoAlertsForStateFoundAtLaunch() throws {
        let t0 = Date()
        try append([use("x", t0.addingTimeInterval(-500))])
        let engine = Engine(config: Engine.Config(roots: [root]))
        let mon = ActivityMonitor()
        XCTAssertTrue(mon.process(engine.tick(now: t0)).isEmpty)
    }
}

final class TurnTests: XCTestCase {
    func testStepsAndTokensGroupedByPrompt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-turn-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let t0 = Date().addingTimeInterval(-600)
        func ts(_ s: Double) -> String { f.string(from: t0.addingTimeInterval(s)) }
        func prompt(_ t: Double, _ text: String) -> String {
            #"{"type":"user","uuid":"u\#(t)","timestamp":"\#(ts(t))","message":{"content":"\#(text)"}}"#
        }
        func tool(_ id: String, _ t: Double, out: Int) -> String {
            #"{"type":"assistant","timestamp":"\#(ts(t))","message":{"id":"m\#(id)","content":[{"type":"tool_use","id":"\#(id)","name":"Read","input":{"file_path":"/a/\#(id).swift"}}],"usage":{"input_tokens":0,"output_tokens":\#(out)}}}"#
        }
        func result(_ id: String, _ t: Double, error: Bool = false) -> String {
            #"{"type":"user","timestamp":"\#(ts(t))","message":{"content":[{"type":"tool_result","tool_use_id":"\#(id)","is_error":\#(error)}]}}"#
        }
        let lines = [
            prompt(0, "Loyihani o'rgan"), tool("a", 5, out: 100), result("a", 6), tool("b", 10, out: 50), result("b", 12),
            prompt(100, "Xatoni tuzat"), tool("c", 110, out: 7), result("c", 130, error: true),
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)

        let s = try XCTUnwrap(Engine(config: Engine.Config(roots: [root])).tick().sessions.first)
        XCTAssertEqual(s.turns.map(\.prompt), ["Loyihani o'rgan", "Xatoni tuzat"])
        XCTAssertEqual(s.turns.map(\.tokens.total), [150, 7])
        XCTAssertEqual(s.turns.map(\.steps), [2, 1])
        XCTAssertEqual(s.turns.map(\.errors), [0, 1])
        XCTAssertEqual(s.turns[0].duration, 12, accuracy: 0.01)
        XCTAssertEqual(s.turns[1].duration, 30, accuracy: 0.01)
        XCTAssertEqual(s.main?.steps.map(\.turn), [1, 1, 2])
    }

    func testTurnIndexLookup() {
        let d = Date()
        let starts = [d, d.addingTimeInterval(10), d.addingTimeInterval(20)]
        XCTAssertNil(Engine.turnIndex(starts, d.addingTimeInterval(-1)))
        XCTAssertEqual(Engine.turnIndex(starts, d), 0)
        XCTAssertEqual(Engine.turnIndex(starts, d.addingTimeInterval(15)), 1)
        XCTAssertEqual(Engine.turnIndex(starts, d.addingTimeInterval(99)), 2)
    }
}

final class RateLimitsTests: XCTestCase {
    func testParseStatusLinePayload() throws {
        let json = """
        {"session_id":"abc","cost":{"total_cost_usd":1.5},
         "rate_limits":{"five_hour":{"used_percentage":23.5,"resets_at":1738425600},
                        "seven_day":{"used_percentage":41.2,"resets_at":1738857600}}}
        """
        let p = try XCTUnwrap(StatusLinePayload.parse(Data(json.utf8)))
        XCTAssertEqual(p.sessionId, "abc")
        XCTAssertEqual(p.costUSD, 1.5)
        XCTAssertEqual(p.fiveHour, LimitWindow(usedPercentage: 23.5, resetsAt: Date(timeIntervalSince1970: 1738425600)))
        XCTAssertEqual(p.sevenDay?.usedPercentage, 41.2)
        // Limitsiz (API kaliti bilan ishlash) — oynalar yo'q, lekin xato emas
        let q = try XCTUnwrap(StatusLinePayload.parse(Data(#"{"session_id":"x"}"#.utf8)))
        XCTAssertNil(q.fiveHour)
    }

    func testReaderKeepsLimitsAndCollectsCost() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("tk-rl-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("sessions"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let reset = Int(Date().timeIntervalSince1970) + 3600
        let full = #"{"session_id":"s1","cost":{"total_cost_usd":2},"rate_limits":{"five_hour":{"used_percentage":30,"resets_at":\#(reset)}}}"#
        try full.write(to: dir.appendingPathComponent("latest.json"), atomically: true, encoding: .utf8)
        try full.write(to: dir.appendingPathComponent("sessions/s1.json"), atomically: true, encoding: .utf8)
        let reader = RateLimitsReader(directory: dir)
        let r = try XCTUnwrap(reader.read())
        XCTAssertEqual(r.fiveHour?.usedPercentage, 30)
        XCTAssertEqual(r.costBySession["s1"], 2)

        // Yangi sessiyaning birinchi yangilanishida limit yo'q — eski qiymat saqlanadi
        Thread.sleep(forTimeInterval: 1.1)
        try #"{"session_id":"s2"}"#.write(to: dir.appendingPathComponent("latest.json"), atomically: true, encoding: .utf8)
        XCTAssertEqual(reader.read()?.fiveHour?.usedPercentage, 30)
    }

    func testForecast() {
        let now = Date()
        let w = LimitWindow(usedPercentage: 60, resetsAt: now.addingTimeInterval(3 * 3600))
        // 10 daqiqada 10% → qolgan 40% ~40 daqiqada tugaydi
        let h = [(now.addingTimeInterval(-600), 50.0), (now, 60.0)]
        guard case .runsOut(let at) = LimitForecast.forecast(w, history: h, now: now) else { return XCTFail() }
        XCTAssertEqual(at.timeIntervalSince(now), 2400, accuracy: 1)

        let slow = [(now.addingTimeInterval(-600), 59.9), (now, 60.0)]
        XCTAssertEqual(LimitForecast.forecast(w, history: slow, now: now), .lasts)
        XCTAssertEqual(LimitForecast.forecast(w, history: [(now, 60)], now: now), .unknown)
    }

    func testExpiredWindowDropped() {
        let now = Date()
        let r = RateLimits(fiveHour: LimitWindow(usedPercentage: 90, resetsAt: now.addingTimeInterval(-1)),
                           sevenDay: LimitWindow(usedPercentage: 10, resetsAt: now.addingTimeInterval(100)), updatedAt: now)
        XCTAssertNil(r.active(at: now).fiveHour)
        XCTAssertNotNil(r.active(at: now).sevenDay)
    }
}

final class ReplayTests: XCTestCase {
    func testReplayAtMoments() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-replay-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p/s/subagents"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let t0 = Date().addingTimeInterval(-1000)
        func ts(_ s: Double) -> String { f.string(from: t0.addingTimeInterval(s)) }
        let main = [
            #"{"type":"user","timestamp":"\#(ts(0))","message":{"content":"Boshla"}}"#,
            #"{"type":"assistant","timestamp":"\#(ts(10))","message":{"id":"a","content":[{"type":"tool_use","id":"t1","name":"Edit","input":{"file_path":"/x/A.swift"}}],"usage":{"input_tokens":0,"output_tokens":100}}}"#,
            #"{"type":"user","timestamp":"\#(ts(40))","message":{"content":[{"type":"tool_result","tool_use_id":"t1"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(ts(60))","message":{"id":"b","content":[{"type":"text","text":"tayyor"}],"usage":{"input_tokens":0,"output_tokens":50}}}"#,
        ]
        try (main.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)
        let helper = [
            #"{"type":"user","isSidechain":true,"agentId":"h","timestamp":"\#(ts(20))","message":{"content":"Qidir"}}"#,
            #"{"type":"assistant","isSidechain":true,"agentId":"h","timestamp":"\#(ts(25))","message":{"id":"c","content":[{"type":"text","text":"ok"}],"usage":{"input_tokens":0,"output_tokens":7}}}"#,
        ]
        try (helper.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s/subagents/agent-h.jsonl"), atomically: true, encoding: .utf8)

        let s = try XCTUnwrap(Engine(config: Engine.Config(roots: [root])).tick().sessions.first)
        XCTAssertEqual(s.tokens.total, 157)

        // 15-soniya: tahrir boshlangan, tugamagan; yordamchi hali yo'q
        let a = s.replay(at: t0.addingTimeInterval(15))
        XCTAssertEqual(a.agents.count, 1)
        XCTAssertEqual(a.main?.steps.last?.status, .running)
        XCTAssertEqual(a.main?.steps.last?.duration ?? 0, 5, accuracy: 0.01)
        XCTAssertEqual(a.tokens.total, 100)
        XCTAssertEqual(a.state, .running)
        XCTAssertEqual(a.main?.resources.first?.busy, true)

        // 30-soniya: yordamchi ishga tushgan
        let b = s.replay(at: t0.addingTimeInterval(30))
        XCTAssertEqual(b.agents.count, 2)
        XCTAssertEqual(b.tokens.total, 107)

        // Oxirida — hammasi tugagan, tokenlar to'liq
        let c = s.replay(at: t0.addingTimeInterval(500))
        XCTAssertEqual(c.tokens.total, 157)
        XCTAssertEqual(c.main?.steps.last?.status, .done)
        XCTAssertEqual(c.turns.first?.tokens.total, 157)
        XCTAssertEqual(c.state, .idle)
        XCTAssertNotNil(s.timeRange)
    }
}

final class TodayHoursTests: XCTestCase {
    func testHourlyBucketsAndActiveMinutes() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-hours-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let lines = [-120.0, -60, -59].enumerated().map { i, t in
            #"{"type":"assistant","timestamp":"\#(f.string(from: now.addingTimeInterval(t)))","message":{"id":"h\#(i)","content":[],"usage":{"input_tokens":0,"output_tokens":10}}}"#
        }
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)
        let snap = Engine(config: Engine.Config(roots: [root])).tick(now: now)
        XCTAssertEqual(snap.todayHours.reduce(0) { $0 + $1.total }, snap.today.total)
        XCTAssertEqual(snap.todayHours.count, 24)
        XCTAssertGreaterThanOrEqual(snap.activeMinutesToday, 2)
        XCTAssertNotNil(snap.firstActivityToday)
    }
}
