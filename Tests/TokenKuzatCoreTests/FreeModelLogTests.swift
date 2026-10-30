import XCTest
@testable import TokenKuzatCore

final class FreeModelLogTests: XCTestCase {
    private func tempDir() -> URL {
        let d = FileManager.default.temporaryDirectory.appendingPathComponent("fml-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    func testReadsFilesWithHeaders() throws {
        let d = tempDir()
        defer { try? FileManager.default.removeItem(at: d) }
        let f = d.appendingPathComponent("build.log")
        try "error: boom\n".write(to: f, atomically: true, encoding: .utf8)
        XCTAssertEqual(try FreeModelLog.readFiles([f.path]).get(), "--- file: \(f.path) ---\nerror: boom\n")
    }

    func testRefusesSecretsRelativeBinaryAndLarge() throws {
        let d = tempDir()
        defer { try? FileManager.default.removeItem(at: d) }
        let env = d.appendingPathComponent(".env.local")
        try "KEY=1".write(to: env, atomically: true, encoding: .utf8)
        XCTAssertEqual(FreeModelLog.readFiles([env.path]), .failure(.secret(env.path)))
        XCTAssertTrue(FreeModelLog.isSecret("/Users/a/.ssh/config"))
        XCTAssertTrue(FreeModelLog.isSecret("/tmp/server.pem"))
        XCTAssertFalse(FreeModelLog.isSecret("/tmp/app.log"))
        XCTAssertEqual(FreeModelLog.readFiles(["app.log"]), .failure(.notAbsolute("app.log")))
        let bin = d.appendingPathComponent("a.bin")
        try Data([0x00, 0xFF, 0xFE]).write(to: bin)
        XCTAssertEqual(FreeModelLog.readFiles([bin.path]), .failure(.binary(bin.path)))
        let big = d.appendingPathComponent("big.txt")
        try String(repeating: "a", count: 50).write(to: big, atomically: true, encoding: .utf8)
        XCTAssertEqual(FreeModelLog.readFiles([big.path], limit: 10), .failure(.tooLarge(50)))
        XCTAssertEqual(FreeModelLog.readFiles([d.path]), .failure(.unreadable(d.path)))
    }

    func testLogAppendsAndSummarizes() {
        let d = tempDir()
        defer { try? FileManager.default.removeItem(at: d) }
        let url = d.appendingPathComponent("calls.jsonl")
        let now = Date()
        FreeModelLog.append(.init(date: now.addingTimeInterval(-10 * 86400), model: "x", promptTokens: 5, fileTokens: 900, replyTokens: 100), to: url)
        FreeModelLog.append(.init(date: now, model: "groq/llama", promptTokens: 20, fileTokens: 4000, replyTokens: 300), to: url)
        FreeModelLog.append(.init(date: now, model: "auto", promptTokens: 50, fileTokens: 0, replyTokens: 200), to: url)
        let calls = FreeModelLog.load(from: url)
        XCTAssertEqual(calls.count, 3)
        let s = FreeModelLog.summary(calls, since: now.addingTimeInterval(-86400))
        XCTAssertEqual(s, .init(calls: 2, withFiles: 1, fileTokens: 4000, savedTokens: 4500))
    }
}
