import XCTest
@testable import TokenKuzatCore

final class DelegateNudgeTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("nudge-" + UUID().uuidString)
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func call(_ tool: String, sid: String = "s1", extra: [String: Any] = [:]) -> String? {
        var o: [String: Any] = ["session_id": sid, "tool_name": tool, "tool_input": ["command": "cat a"]]
        o.merge(extra) { $1 }
        return DelegateNudge.handle(input: try! JSONSerialization.data(withJSONObject: o), dir: dir)
    }

    func testNudgeAtFifteenAndThirty() {
        for _ in 0..<14 { XCTAssertNil(call("Bash")) }
        let out = call("Bash")
        XCTAssertNotNil(out)
        XCTAssertTrue(out?.contains("PostToolUse") == true)
        XCTAssertTrue(out?.contains("additionalContext") == true)
        for _ in 0..<14 { XCTAssertNil(call("Read")) }
        XCTAssertNotNil(call("Grep"))
    }

    func testNoNudgeAfterHelper() {
        for _ in 0..<5 { XCTAssertNil(call("Read")) }
        XCTAssertNil(call("Agent"))
        for _ in 0..<30 { XCTAssertNil(call("Read")) }
    }

    func testSubagentCallsNotCounted() {
        for _ in 0..<30 { XCTAssertNil(call("Read", extra: ["agent_id": "a1"])) }
        for _ in 0..<14 { XCTAssertNil(call("Read")) }
        XCTAssertNotNil(call("Read"))
    }

    func testAgentTypeOnlyIsCounted() {
        for _ in 0..<14 { XCTAssertNil(call("Read", extra: ["agent_type": "main"])) }
        XCTAssertNotNil(call("Read", extra: ["agent_type": "main"]))
    }

    func testHelpersNeverDecrease() {
        _ = call("Agent")
        _ = call("Agent")
        let url = dir.appendingPathComponent("s1.json")
        let st = try! JSONDecoder().decode(DelegateNudge.State.self, from: Data(contentsOf: url))
        XCTAssertEqual(st.helpers, 2)
        _ = call("Read")
        let st2 = try! JSONDecoder().decode(DelegateNudge.State.self, from: Data(contentsOf: url))
        XCTAssertEqual(st2.helpers, 2)
        XCTAssertEqual(st2.reads, 1)
    }

    func testCleanupRemovesOldFiles() {
        _ = call("Read")
        DelegateNudge.cleanup(dir: dir, now: Date().addingTimeInterval(8 * 86_400))
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.appendingPathComponent("s1.json").path))
    }

    func testNonReadIgnoredAndBadInput() {
        for _ in 0..<40 { XCTAssertNil(call("Edit")) }
        XCTAssertNil(DelegateNudge.handle(input: Data("nope".utf8), dir: dir))
        XCTAssertNil(call("Read", sid: "a/b"))
    }
}
