import XCTest
@testable import TokenKuzatCore

final class HookEventsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testParsesPermissionPrompt() throws {
        let json = #"{"session_id":"abc","hook_event_name":"Notification","message":"Claude needs your permission to use Bash","notification_type":"permission_prompt"}"#
        let n = try XCTUnwrap(HookNotice.parse(Data(json.utf8), date: t0))
        XCTAssertEqual(n.sessionId, "abc")
        XCTAssertEqual(n.kind, .permission)
    }

    func testParsesIdleByMessageWithoutType() throws {
        let json = #"{"session_id":"abc","message":"Claude is waiting for your input"}"#
        XCTAssertEqual(try XCTUnwrap(HookNotice.parse(Data(json.utf8), date: t0)).kind, .idle)
    }

    func testRejectsMissingSession() {
        XCTAssertNil(HookNotice.parse(Data(#"{"message":"x"}"#.utf8), date: t0))
    }

    func testPendingUntilNewActivity() {
        let n = HookNotice(sessionId: "s", kind: .permission, message: "", date: t0)
        // Tool chaqiruvi ruxsatdan oldin yozilgan — hali kutilyapti
        XCTAssertTrue(n.isPending(lastActivity: t0.addingTimeInterval(-1), now: t0.addingTimeInterval(30)))
        // Ruxsatdan keyin asbob ishladi — kutish tugagan
        XCTAssertFalse(n.isPending(lastActivity: t0.addingTimeInterval(10), now: t0.addingTimeInterval(30)))
        // Juda eski xabar hisobga olinmaydi
        XCTAssertFalse(n.isPending(lastActivity: nil, now: t0.addingTimeInterval(7 * 3600)))
        // Ruxsat emas — kutish holati yo'q
        let idle = HookNotice(sessionId: "s", kind: .idle, message: "", date: t0)
        XCTAssertFalse(idle.isPending(lastActivity: nil, now: t0))
    }
}
