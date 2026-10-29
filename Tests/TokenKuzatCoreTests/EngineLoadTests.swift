import XCTest
@testable import TokenKuzatCore

/// Mac'ni zo'riqtirmaslik: kuzatuv bilan faqat o'zgargan fayllar o'qiladi, tinch sessiyalar qaytadan qurilmaydi
final class EngineLoadTests: XCTestCase {
    private var root: URL!
    private var watcher: ChangeWatcher?

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-load-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("proj"), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: d)
    }

    private func assistant(_ id: String, _ ts: Date, output: Int) -> String {
        """
        {"type":"assistant","timestamp":"\(iso(ts))","cwd":"/tmp/MyApp","requestId":"r-\(id)",\
        "message":{"id":"\(id)","model":"claude-opus-5-5","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}],\
        "usage":{"input_tokens":0,"output_tokens":\(output),"cache_creation_input_tokens":0,"cache_read_input_tokens":0}}}
        """
    }

    private func url(_ rel: String) -> URL { root.appendingPathComponent(rel) }

    private func write(_ rel: String, _ lines: [String]) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: url(rel), atomically: true, encoding: .utf8)
    }

    private func append(_ rel: String, _ line: String) throws {
        let h = try FileHandle(forWritingTo: url(rel))
        h.seekToEndOfFile()
        h.write(Data((line + "\n").utf8))
        try h.close()
    }

    /// Kuzatuvchi oqimsiz: voqealarni test o'zi beradi
    private func watchedEngine() -> Engine {
        Engine(config: Engine.Config(roots: [root]), history: nil, watcher: { [weak self] roots in
            let w = ChangeWatcher(roots: roots, start: false)
            self?.watcher = w
            return w
        })
    }

    func testWatchedEngineReadsOnlyChangedFiles() throws {
        let now = Date()
        try write("proj/s1.jsonl", [assistant("a1", now.addingTimeInterval(-5), output: 10)])
        let engine = watchedEngine()
        XCTAssertEqual(engine.tick(now: now).today.total, 10)
        XCTAssertNotNil(watcher)

        // Fayl 2 daqiqadan beri o'smagan va voqea yo'q — har soniyada tekshirilmaydi
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(100)).today.total, 10)
        try append("proj/s1.jsonl", assistant("a2", now.addingTimeInterval(110), output: 20))
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(130)).today.total, 10)

        // Tizim o'zgarishni aytdi — o'qiladi
        watcher?.record([url("proj/s1.jsonl").path])
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(131)).today.total, 30)

        // Faol fayl voqeasiz ham o'qiladi (voqea kechiksa ham jonli ko'rinish to'xtamaydi)
        try append("proj/s1.jsonl", assistant("a3", now.addingTimeInterval(132), output: 5))
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(133)).today.total, 35)
    }

    func testWatchedEngineFindsNewFileFromEventAndRescan() throws {
        let now = Date()
        try write("proj/s1.jsonl", [assistant("a1", now.addingTimeInterval(-5), output: 10)])
        let engine = watchedEngine()
        XCTAssertEqual(engine.tick(now: now).today.total, 10)

        // Yangi transkript voqeasi — papkalar darhol aylaniladi
        try write("proj/s2.jsonl", [assistant("b1", now.addingTimeInterval(1), output: 7)])
        watcher?.record([url("proj/s2.jsonl").path])
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(2)).today.total, 17)

        // Keraksiz fayllar voqeasi aylanishni boshlamaydi; voqea yo'qolsa ham daqiqalik aylanish topadi
        try write("proj/s3.jsonl", [assistant("c1", now.addingTimeInterval(3), output: 3)])
        watcher?.record([url("proj/s1/tool-results/x.jsonl").path, url("proj/journal.jsonl").path])
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(4)).today.total, 17)
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(63)).today.total, 20)
    }

    func testTranscriptPathFilter() {
        XCTAssertTrue(Engine.isTranscript("/u/.claude/projects/p/s.jsonl"))
        XCTAssertTrue(Engine.isTranscript("/u/.claude/projects/p/s/subagents/agent-1.jsonl"))
        XCTAssertFalse(Engine.isTranscript("/u/.claude/projects/p/s/tool-results/r.jsonl"))
        XCTAssertFalse(Engine.isTranscript("/u/Claude/local-agent-mode-sessions/x/audit.jsonl"))
        XCTAssertFalse(Engine.isTranscript("/u/.claude/projects/p/s.json"))
    }

    /// Tinch sessiyaning snapshot'i keshdan olinadi, lekin yangi qator yoki boshqa fayldagi natija uni yangilaydi
    func testSettledSessionSnapshotIsReusedUntilItChanges() throws {
        let now = Date()
        let t = now.addingTimeInterval(-3000)
        try write("proj/a.jsonl", [
            #"{"type":"assistant","timestamp":"\#(iso(t))","message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"make"}}]}}"#,
        ])
        let engine = Engine(config: Engine.Config(roots: [root]))
        let first = try XCTUnwrap(engine.tick(now: now).sessions.first { $0.id == "a" })
        XCTAssertEqual(first.state, .idle)
        XCTAssertNil(first.main?.steps.first?.duration)
        XCTAssertEqual(engine.cachedSessions, ["a"])
        XCTAssertEqual(engine.tick(now: now.addingTimeInterval(1)).sessions.first { $0.id == "a" }?.main?.steps.count, 1)

        // Davom ettirilgan sessiya faylida eski qadamning natijasi keldi
        try write("proj/b.jsonl", [
            #"{"type":"user","timestamp":"\#(iso(t.addingTimeInterval(100)))","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]}}"#,
        ])
        let after = try XCTUnwrap(engine.tick(now: now.addingTimeInterval(10)).sessions.first { $0.id == "a" })
        XCTAssertEqual(after.main?.steps.first?.duration, 100)

        // Tinch sessiyaga yangi qator — u yana jonli
        try append("proj/a.jsonl", assistant("m2", now.addingTimeInterval(11), output: 9))
        let live = try XCTUnwrap(engine.tick(now: now.addingTimeInterval(12)).sessions.first { $0.id == "a" })
        XCTAssertEqual(live.state, .running)
        XCTAssertFalse(engine.cachedSessions.contains("a"))
        XCTAssertEqual(live.tokens.total, 9)
    }

    func testOldSettledSessionsStayOutOfList() throws {
        let now = Date()
        let old = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        try write("proj/old.jsonl", [assistant("o1", old, output: 4)])
        try write("proj/new.jsonl", [assistant("n1", now.addingTimeInterval(-5), output: 6)])
        let snap = Engine(config: Engine.Config(roots: [root])).tick(now: now)
        XCTAssertEqual(snap.sessions.map(\.id), ["new"])
    }

    func testWatcherMapsResolvedPathsBack() throws {
        let link = FileManager.default.temporaryDirectory.appendingPathComponent("tk-link-\(UUID().uuidString)")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        defer { try? FileManager.default.removeItem(at: link) }
        let w = ChangeWatcher(roots: [link], start: false)
        let real = root.resolvingSymlinksInPath().path
        w.record([real + "/proj/s.jsonl"], rescan: true)
        let c = w.drain()
        XCTAssertEqual(c.paths, [link.path + "/proj/s.jsonl"])
        XCTAssertTrue(c.rescan)
        XCTAssertTrue(w.drain().paths.isEmpty)
    }
}

final class FastDateTests: XCTestCase {
    func testFastISOMatchesFormatter() {
        let frac = ISO8601DateFormatter()
        frac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        var seed: UInt64 = 42
        for _ in 0..<2000 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            // 1990–2060 oralig'i, millisekundgacha
            let t = 631_152_000 + Double(seed >> 33) .truncatingRemainder(dividingBy: 2_208_988_800) + Double(seed % 1000) / 1000
            let d = Date(timeIntervalSince1970: t)
            for (f, s) in [(frac, frac.string(from: d)), (plain, plain.string(from: d))] {
                let expected = f.date(from: s)!
                let fast = TranscriptParser.fastISO(s)
                XCTAssertNotNil(fast, s)
                XCTAssertEqual(fast?.timeIntervalSince1970 ?? 0, expected.timeIntervalSince1970, accuracy: 0.0005, s)
            }
        }
    }

    func testFastISOOffsetsAndRejects() {
        let utc = TranscriptParser.fastISO("2026-10-29T22:01:15.031Z")
        XCTAssertEqual(utc?.timeIntervalSince1970 ?? 0, 1_793_311_275.031, accuracy: 0.0005)
        XCTAssertEqual(TranscriptParser.fastISO("2026-10-30T03:01:15.031+05:00"), utc)
        XCTAssertEqual(TranscriptParser.fastISO("2026-10-29T17:01:15.031-0500"), utc)
        XCTAssertEqual(TranscriptParser.fastISO("2024-02-29T00:00:00Z")?.timeIntervalSince1970, 1_709_164_800)
        for bad in ["", "2026-10-29", "2026-10-29 22:01:15Z", "2026-13-01T00:00:00Z", "2026-10-29T22:01:15.Z",
                    "2026-10-29T22:01:15.031", "2026-10-29T22:01:15.031Zx", "20x6-10-29T22:01:15Z"] {
            XCTAssertNil(TranscriptParser.fastISO(bad), bad)
        }
        // Formatter zaxira sifatida qoladi
        XCTAssertNotNil(TranscriptParser.date("2026-10-29T22:01:15Z"))
    }
}
