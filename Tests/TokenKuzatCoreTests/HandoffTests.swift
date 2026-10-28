import XCTest
@testable import TokenKuzatCore

final class HandoffTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var url: URL!

    override func setUp() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("handoff-\(UUID().uuidString).json")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: url) }

    private func input(_ sid: String, cwd: String, source: String = "startup") -> Data {
        try! JSONSerialization.data(withJSONObject: ["session_id": sid, "cwd": cwd, "source": source])
    }

    func testDeliveredOnceToNewSession() throws {
        try HandoffStore.arm(PendingHandoff(text: "XULOSA", sourceSession: "old", cwd: "/p/app", created: t0), at: url)
        let out = try XCTUnwrap(HandoffStore.handleSessionStart(input: input("new", cwd: "/p/app"), at: url, now: t0 + 60))
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any])
        let spec = try XCTUnwrap(o["hookSpecificOutput"] as? [String: Any])
        XCTAssertEqual(spec["hookEventName"] as? String, "SessionStart")
        XCTAssertTrue((spec["additionalContext"] as? String)?.contains("XULOSA") == true)
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("third", cwd: "/p/app"), at: url, now: t0 + 90))
    }

    func testNotDeliveredOnResumeSameSessionOtherProjectOrExpired() throws {
        let h = PendingHandoff(text: "X", sourceSession: "old", cwd: "/p/app", created: t0)
        try HandoffStore.arm(h, at: url)
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("new", cwd: "/p/app", source: "resume"), at: url, now: t0 + 60))
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("new", cwd: "/p/app", source: "compact"), at: url, now: t0 + 60))
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("old", cwd: "/p/app"), at: url, now: t0 + 60))
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("new", cwd: "/p/other"), at: url, now: t0 + 60))
        // hali kutilmoqda — rad etilganlar uni o'chirmaydi
        XCTAssertNotNil(HandoffStore.pending(at: url, now: t0 + 60))
        XCTAssertNil(HandoffStore.handleSessionStart(input: input("new", cwd: "/p/app"), at: url, now: t0 + 3 * 3600))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testScratchFoldersMatchAnything() {
        let h = PendingHandoff(text: "X", sourceSession: "old",
                               cwd: "/Users/a/Library/Application Support/Claude/scratch-workspaces/1/2/s-a", created: t0)
        XCTAssertTrue(HandoffStore.shouldDeliver(h, sessionId: "new",
                                                 cwd: "/Users/a/Library/Application Support/Claude/scratch-workspaces/1/2/s-b",
                                                 source: "startup", now: t0 + 10))
    }
}
