import XCTest
@testable import TokenKuzatCore

final class RedirectTests: XCTestCase {
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("redirects-\(UUID().uuidString).json")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: url) }

    private func input(_ sid: String, _ prompt: String) -> Data {
        try! JSONSerialization.data(withJSONObject: ["session_id": sid, "prompt": prompt, "cwd": "/tmp/p"])
    }

    func testFirstPromptIsRedirectedOnlyOnce() {
        let now = Date()
        RedirectStore.add(session: "old", summary: "XULOSA", previousContext: 334_000, at: url, now: now)
        let d = RedirectStore.handlePrompt(input: input("old", "keyingi ishni qil"), at: url, now: now)
        XCTAssertNotNil(d)
        XCTAssertTrue(d!.output.contains("\"decision\":\"block\""))
        XCTAssertTrue(d!.message.contains("XULOSA") && d!.message.hasSuffix("keyingi ishni qil"))
        XCTAssertEqual(d!.cwd, "/tmp/p")
        // Qayta yuborilsa — shu sessiyada qoladi
        XCTAssertNil(RedirectStore.handlePrompt(input: input("old", "keyingi ishni qil"), at: url, now: now))
    }

    func testOtherSessionsSlashCommandsAndStaleAreUntouched() {
        let now = Date()
        RedirectStore.add(session: "old", summary: "S", previousContext: 1, at: url, now: now)
        XCTAssertNil(RedirectStore.handlePrompt(input: input("new", "salom"), at: url, now: now))
        XCTAssertNil(RedirectStore.handlePrompt(input: input("old", "/compact"), at: url, now: now))
        XCTAssertNil(RedirectStore.handlePrompt(input: input("old", "salom"), at: url, now: now.addingTimeInterval(25 * 3600)))
    }
}
