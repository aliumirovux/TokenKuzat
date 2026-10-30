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
        try "start\nerror: boom\n".write(to: f, atomically: true, encoding: .utf8)
        // Har qator raqamlanadi — bepul model javobda qatorni ko'rsatadi
        XCTAssertEqual(try FreeModelLog.readFiles([f.path]).get(), "--- file: \(f.path) ---\n1| start\n2| error: boom\n")
    }

    func testQuoteCheckFlagsAlteredQuotes() {
        let files = "--- file: /p/CHANGELOG.md ---\n1| ## 6.65.0\n2| - `ask_free_model` endi faylni o'zi o'qiydi: Claude uzun log beradi.\n3| 6 files changed, 338 insertions(+)\n"
        // Haqiqiy iqtiboslar: qator raqami, Markdown belgisi, oxirgi nuqta va boshqa apostrof farq qilmaydi
        let good = "L2: \"ask_free_model endi faylni o’zi o'qiydi: Claude uzun log beradi.\"\n> \"6 files changed, 338 insertions(+)\"\nVersiya «## 6.65.0»"
        let ok = FreeModelLog.missingQuotes(in: good, files: files)
        XCTAssertEqual(ok.checked, 2)
        XCTAssertTrue(ok.missing.isEmpty)
        // Sinovdagi holat: model iqtibosni o'zgartirib, noto'g'ri xulosa bergan
        let bad = FreeModelLog.missingQuotes(in: "Versiya 6.52.0: \"`ask_free_model` endi faylni o'qiydi: Claude uzun log\"", files: files)
        XCTAssertEqual(bad.missing, ["ask_free_model` endi faylni o'qiydi: Claude uzun log"])
        XCTAssertEqual(FreeModelLog.missingQuotes(in: "Iqtibossiz javob", files: files).checked, 0)
        // Faqat chiziq yoki bo'shliq farq qilsa — to'g'ri; raqam farq qilsa — belgilanadi
        let stat = "--- file: /p/git.log ---\n1|  Sources/MCPServer.swift                 |  55 ++++++-\n"
        XCTAssertTrue(FreeModelLog.missingQuotes(in: "L1: \"Sources/MCPServer.swift | 55 ++++++--\"", files: stat).missing.isEmpty)
        XCTAssertEqual(FreeModelLog.missingQuotes(in: "L1: \"Sources/MCPServer.swift | 56 ++++++-\"", files: stat).missing.count, 1)
        // Iqtibos ichidagi qochirilgan qo'shtirnoq («\"five\"») iqtibosni kesmaydi
        let code = "--- file: /p/a.swift ---\n5| let x: Int = \"five\"\n"
        let esc = FreeModelLog.missingQuotes(in: #"L5: "let x: Int = \"five\"""#, files: code)
        XCTAssertEqual(esc.checked, 1)
        XCTAssertTrue(esc.missing.isEmpty)
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
