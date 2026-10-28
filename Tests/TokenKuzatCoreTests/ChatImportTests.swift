import XCTest
@testable import TokenKuzatCore

final class ChatImportTests: XCTestCase {
    private let big = String(repeating: "x", count: 10_000)

    private func transcript() -> Data {
        let lines = [
            #"{"type":"queue-operation","operation":"enqueue"}"#,
            #"{"type":"user","timestamp":"2026-10-28T17:00:00.000Z","cwd":"/home/claude","message":{"content":"Salom"}}"#,
            #"{"type":"assistant","timestamp":"2026-10-28T17:00:05.000Z","cwd":"/home/claude","requestId":"r1","message":{"id":"m1","model":"claude-opus-5-5","content":[{"type":"thinking","thinking":"o'ylayman","signature":"SIG"},{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"\#(big)"}}],"usage":{"input_tokens":10,"output_tokens":20,"cache_creation_input_tokens":0,"cache_read_input_tokens":100}}}"#,
            #"{"type":"user","timestamp":"2026-10-28T17:00:09.000Z","cwd":"/home/claude","toolUseResult":{"stdout":"\#(big)"},"message":{"content":[{"type":"tool_result","tool_use_id":"t1","content":[{"type":"text","text":"\#(big)"},{"type":"image","source":{"type":"base64","data":"AAAA"}}]}]}}"#,
            "buzuq qator",
        ]
        return Data((lines.joined(separator: "\n") + "\n").utf8)
    }

    func testPrepareSlimsAndRenames() throws {
        let src = transcript()
        let out = try XCTUnwrap(ChatImport.prepare(src))
        XCTAssertLessThan(out.count, src.count / 3)
        let rows = out.split(separator: 0x0A).compactMap { try? JSONSerialization.jsonObject(with: Data($0)) as? [String: Any] }
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows.allSatisfy { $0["cwd"] as? String == "/Claude chat" })
        XCTAssertNil(rows[2]["toolUseResult"])
        let s = String(decoding: out, as: UTF8.self)
        XCTAssertFalse(s.contains("SIG"))
        XCTAssertFalse(s.contains("AAAA"))
    }

    func testImportedFileIsReadByEngine() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("tk-chat-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tmp) }
        let srcDir = tmp.appendingPathComponent("src")
        try FileManager.default.createDirectory(at: srcDir, withIntermediateDirectories: true)
        let src = srcDir.appendingPathComponent("abc-123.jsonl")
        try transcript().write(to: src)
        let chats = tmp.appendingPathComponent("chats")
        let dest = try ChatImport.importFile(src, into: chats)
        XCTAssertEqual(dest.lastPathComponent, "abc-123.jsonl")

        let now = ISO8601DateFormatter().date(from: "2026-10-28T17:01:00Z")!
        // Fayl vaqti — oxirgi 30 kun ichida bo'lsin
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: dest.path)
        let snap = Engine(config: Engine.Config(roots: [chats])).tick(now: now)
        let s = try XCTUnwrap(snap.sessions.first)
        XCTAssertEqual(s.project, ChatImport.projectName)
        XCTAssertEqual(s.tokens.total, 130)
        XCTAssertEqual(s.main?.steps.count, 1)
        XCTAssertEqual(s.main?.steps.first?.status, .done)
    }

    func testRejectsNonTranscript() {
        XCTAssertNil(ChatImport.prepare(Data("salom\n{\"a\":1}\n".utf8)))
    }
}
