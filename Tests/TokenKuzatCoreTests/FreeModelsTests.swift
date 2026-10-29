import XCTest
@testable import TokenKuzatCore

final class FreeModelsTests: XCTestCase {
    func testClaudeModelsAreRecognized() {
        XCTAssertTrue(FreeModels.isClaude("claude-opus-5-5"))
        XCTAssertTrue(FreeModels.isClaude("us.anthropic.claude-sonnet-5-5-v1:0"))
        XCTAssertTrue(FreeModels.isClaude(""))
        XCTAssertFalse(FreeModels.isClaude("auto"))
        XCTAssertFalse(FreeModels.isClaude("gemini-3.6-flash"))
        XCTAssertFalse(FreeModels.isClaude("deepseek-v4"))
    }

    func testRootURLDropsSlashAndV1() {
        XCTAssertEqual(FreeModels.rootURL(" http://localhost:3001/v1/ "), "http://localhost:3001")
        XCTAssertEqual(FreeModels.rootURL("http://127.0.0.1:31415"), "http://127.0.0.1:31415")
        XCTAssertEqual(FreeModels.rootURL(""), FreeModels.defaultURL)
        XCTAssertTrue(FreeModels.isLocal(FreeModels.defaultURL))
        XCTAssertTrue(FreeModels.isLocal("http://localhost:3001/v1"))
        XCTAssertTrue(FreeModels.isLocal("http://[::1]:31415"))
        XCTAssertFalse(FreeModels.isLocal("https://gateway.example.com"))
        XCTAssertFalse(FreeModels.isLocal("http://192.168.1.20:31415"))
    }

    func testConfigIsSavedPrivately() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fm-\(UUID().uuidString)/free-models.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try FreeModels.save(.init(url: "http://localhost:3001/v1", key: " freellmapi-abc \n"), to: url)
        XCTAssertEqual(FreeModels.load(from: url), .init(url: "http://localhost:3001", key: "freellmapi-abc"))
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o600)
        FreeModels.remove(at: url)
        XCTAssertNil(FreeModels.load(from: url))
    }

    /// Skript kalitni fayldan o'qiydi (skriptning o'zida kalit yo'q) va modellarni «auto» ga yo'naltiradi
    func testShellPreludeReadsKeyFromConfig() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fm-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let config = dir.appendingPathComponent("free models.json")
        try FreeModels.save(.init(url: "http://localhost:3001", key: "freellmapi-x'y"), to: config)
        let prelude = FreeModels.shellPrelude(url: "http://localhost:3001/", configPath: config.path)
        XCTAssertFalse(prelude.contains("freellmapi-x"))
        XCTAssertTrue(prelude.contains("export ANTHROPIC_MODEL=auto"))
        XCTAssertTrue(prelude.contains("export CLAUDE_CODE_AUTO_COMPACT_WINDOW=100000"))

        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/zsh")
        p.arguments = ["-f", "-c", prelude + "\nprint -r -- \"$ANTHROPIC_BASE_URL|$ANTHROPIC_AUTH_TOKEN\""]
        let pipe = Pipe()
        p.standardOutput = pipe
        try p.run()
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        XCTAssertEqual(out?.trimmingCharacters(in: .newlines), "http://localhost:3001|freellmapi-x'y")
    }

    func testChatRequestAndReply() throws {
        let req = FreeModels.chatRequest(prompt: "Salom", system: "Qisqa javob ber", model: nil, maxTokens: 200)
        XCTAssertEqual(req["model"] as? String, "auto")
        XCTAssertEqual(req["max_tokens"] as? Int, 200)
        XCTAssertEqual((req["messages"] as? [[String: Any]])?.map { $0["role"] as? String }, ["system", "user"])

        let body = #"{"model":"llama-4-scout","choices":[{"message":{"role":"assistant","content":"Hello"}}],"usage":{"total_tokens":42}}"#
        XCTAssertEqual(FreeModels.chatReply(Data(body.utf8)), .init(text: "Hello", model: "llama-4-scout", tokens: 42))
        XCTAssertNil(FreeModels.chatReply(Data(#"{"error":{"message":"all providers rate-limited"}}"#.utf8)))
        XCTAssertEqual(FreeModels.errorText(Data(#"{"error":{"message":"all providers rate-limited"}}"#.utf8)), "all providers rate-limited")
        XCTAssertEqual(FreeModels.modelCount(Data(#"{"object":"list","data":[{"id":"a"},{"id":"b"}]}"#.utf8)), 2)
    }

    /// gpt-oss kabi o'ylaydigan modellar: javob va o'ylash alohida; chegaraga yetsa shlyuz content ga o'ylashni qo'yadi
    func testReasoningReplies() {
        let ok = #"{"model":"openai/gpt-oss-20b","choices":[{"finish_reason":"stop","message":{"role":"assistant","content":"Yig'ish tugadi.","reasoning":"We need to translate…"}}]}"#
        XCTAssertEqual(FreeModels.chatReply(Data(ok.utf8)), .init(text: "Yig'ish tugadi.", model: "openai/gpt-oss-20b", tokens: nil))

        let thinking = #"{"model":"openai/gpt-oss-20b","choices":[{"finish_reason":"length","message":{"role":"assistant","content":"We need to translate","reasoning":"We need to translate"}}]}"#
        let r = FreeModels.chatReply(Data(thinking.utf8))
        XCTAssertEqual(r?.thinkingOnly, true)
        XCTAssertEqual(r?.truncated, true)
        XCTAssertEqual(r?.text, "")

        let nullContent = #"{"choices":[{"finish_reason":"length","message":{"role":"assistant","content":null,"reasoning":"Hmm"}}]}"#
        XCTAssertEqual(FreeModels.chatReply(Data(nullContent.utf8))?.thinkingOnly, true)

        let cut = #"{"choices":[{"finish_reason":"length","message":{"role":"assistant","content":"Birinchi qism","reasoning":"plan"}}]}"#
        let c = FreeModels.chatReply(Data(cut.utf8))
        XCTAssertEqual(c?.text, "Birinchi qism")
        XCTAssertEqual(c?.truncated, true)
        XCTAssertEqual(c?.thinkingOnly, false)
    }

    func testFallbackMessageKeepsHeadlineFirst() {
        let summary = "↪ TokenKuzat — Bepul modellar\nIsh: zaxira rejimi\nQolgan: testlar"
        let m = FreeModels.fallbackMessage(summary: summary, resetsAt: nil, english: false)
        XCTAssertTrue(m.hasPrefix("↪ TokenKuzat — Bepul modellar\n\nToken Kuzatuv: Claude limiti tugadi"))
        XCTAssertTrue(m.hasSuffix("Qolgan: testlar"))
        XCTAssertTrue(AutoHandoffRule.isHandoffPrompt(m))
        XCTAssertEqual(AutoHandoffRule.continuationTitle(from: m), "Bepul modellar")

        let back = FreeModels.returnMessage(summary: summary, english: true)
        XCTAssertTrue(back.contains("the Claude limit has reset"))
        XCTAssertTrue(back.contains("git diff"))
    }
}
