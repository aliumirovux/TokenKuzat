import XCTest
@testable import TokenKuzatCore

/// Xaritadagi tafsilot uchun: qadam kirishi (asbob parametrlari) va chiqishi (natija matni)
final class StepIOTests: XCTestCase {
    func testParserKeepsInputAndResultText() throws {
        let use = #"{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"description":"Build","command":"swift build"}}]}}"#
        guard case .assistant(let a) = try XCTUnwrap(TranscriptParser.parse(Data(use.utf8))).kind,
              case .tool(_, _, _, _, let input) = a.items[0] else { return XCTFail() }
        // Kalitlar tartiblangan, o'qiladigan JSON
        XCTAssertEqual(input, "{\n  \"command\" : \"swift build\",\n  \"description\" : \"Build\"\n}")

        let res = #"{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"Build complete!"},{"type":"image","source":{}}]}]}}"#
        guard case .user(let u) = try XCTUnwrap(TranscriptParser.parse(Data(res.utf8))).kind else { return XCTFail() }
        XCTAssertEqual(u.results.first?.text, "Build complete!\n[rasm]")
    }

    func testLongTextsAreClipped() {
        let long = String(repeating: "a", count: TranscriptEvent.outputLimit + 50)
        let t = TranscriptParser.resultText(long)
        XCTAssertEqual(t.count, TranscriptEvent.outputLimit + 1)
        XCTAssertTrue(t.hasSuffix("…"))
        XCTAssertEqual(TranscriptParser.resultText("  qisqa \n"), "qisqa")
        XCTAssertEqual(TranscriptParser.inputText([:]), "")
    }

    func testEngineStepCarriesIO() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-io-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        func ts(_ s: Double) -> String { f.string(from: now.addingTimeInterval(s)) }
        let lines = [
            #"{"type":"assistant","timestamp":"\#(ts(-20))","message":{"id":"m1","content":[{"type":"tool_use","id":"t1","name":"Read","input":{"file_path":"/x/App.swift"}}]}}"#,
            #"{"type":"user","timestamp":"\#(ts(-19))","message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":"1\timport SwiftUI"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(ts(-10))","message":{"id":"m2","content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"false"}}]}}"#,
            #"{"type":"user","timestamp":"\#(ts(-9))","message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":true,"content":"Exit code 1"}]}}"#,
            #"{"type":"assistant","timestamp":"\#(ts(-2))","message":{"id":"m3","content":[{"type":"tool_use","id":"t3","name":"WebFetch","input":{"url":"https://example.com"}}]}}"#,
        ]
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)

        let main = try XCTUnwrap(Engine(config: Engine.Config(roots: [root])).tick(now: now).sessions.first?.main)
        XCTAssertEqual(main.steps.count, 3)
        XCTAssertEqual(main.steps[0].input, "{\n  \"file_path\" : \"/x/App.swift\"\n}")
        XCTAssertEqual(main.steps[0].output, "1\timport SwiftUI")
        XCTAssertEqual(main.steps[0].resultTokens, "1\timport SwiftUI".utf8.count / 4)
        XCTAssertEqual(main.steps[1].status, .failed)
        XCTAssertEqual(main.steps[1].output, "Exit code 1")
        // Hali natija kelmagan qadam: kirish bor, chiqish yo'q
        XCTAssertEqual(main.steps[2].status, .running)
        XCTAssertNotNil(main.steps[2].input)
        XCTAssertNil(main.steps[2].output)
    }

    func testOnlyRecentStepsKeepIO() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("tk-io2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let now = Date()
        let n = Engine.keepStepIO + 5
        var lines: [String] = []
        for i in 0..<n {
            let t = f.string(from: now.addingTimeInterval(Double(i - n) * 2))
            let r = f.string(from: now.addingTimeInterval(Double(i - n) * 2 + 1))
            lines.append(#"{"type":"assistant","timestamp":"\#(t)","message":{"id":"m\#(i)","content":[{"type":"tool_use","id":"t\#(i)","name":"Bash","input":{"command":"echo \#(i)"}}]}}"#)
            lines.append(#"{"type":"user","timestamp":"\#(r)","message":{"content":[{"type":"tool_result","tool_use_id":"t\#(i)","content":"\#(i)"}]}}"#)
        }
        try (lines.joined(separator: "\n") + "\n").write(to: root.appendingPathComponent("p/s.jsonl"), atomically: true, encoding: .utf8)
        let main = try XCTUnwrap(Engine(config: Engine.Config(roots: [root])).tick(now: now).sessions.first?.main)
        // Snapshot'dagi qadamlar (oxirgilari) — hammasida kirish va chiqish bor
        XCTAssertLessThanOrEqual(main.steps.count, Engine.keepStepIO)
        XCTAssertTrue(main.steps.allSatisfy { $0.input != nil && $0.output != nil })
        XCTAssertEqual(main.steps.last?.output, "\(n - 1)")
    }
}
