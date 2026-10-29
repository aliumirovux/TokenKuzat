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

final class AccountUsageTests: XCTestCase {
    func testParsesUsageResponse() throws {
        let json = #"{"five_hour":{"utilization":44.0,"resets_at":"2026-10-28T13:30:00.512+00:00"},"seven_day":{"utilization":34,"resets_at":"2026-11-03T16:00:00+00:00"},"seven_day_opus":null}"#
        let r = try XCTUnwrap(AccountUsageAPI.parse(Data(json.utf8), at: Date()))
        XCTAssertEqual(r.fiveHour?.usedPercentage, 44)
        XCTAssertEqual(r.sevenDay?.usedPercentage, 34)
        XCTAssertTrue(r.fromAccount)
        XCTAssertEqual(r.fiveHour?.resetsAt.timeIntervalSince1970 ?? 0, 1_793_194_200.512, accuracy: 0.01)
    }

    func testPlanName() {
        XCTAssertEqual(AccountUsageAPI.planName(subscriptionType: "max", rateLimitTier: "default_claude_max_5x"), "Max (5x)")
        XCTAssertEqual(AccountUsageAPI.planName(subscriptionType: "max", rateLimitTier: "default_claude_max_20x"), "Max (20x)")
        XCTAssertEqual(AccountUsageAPI.planName(subscriptionType: "pro", rateLimitTier: nil), "Pro")
    }

    func testWeeklyForecast() {
        let now = Date()
        // 3 kun o'tdi, 60% ishlatildi → ~5 kunda tugaydi, tiklanishgacha 4 kun bor → tugaydi
        let w = LimitWindow(usedPercentage: 60, resetsAt: now.addingTimeInterval(4 * 86400))
        guard case .runsOut = WeeklyForecast.forecast(w, now: now) else { return XCTFail() }
        let calm = LimitWindow(usedPercentage: 20, resetsAt: now.addingTimeInterval(4 * 86400))
        XCTAssertEqual(WeeklyForecast.forecast(calm, now: now), .lasts)
    }

    func testStopFailureParsesAsFailure() throws {
        let json = #"{"session_id":"abc","hook_event_name":"StopFailure","error":"rate_limit","error_details":"429 Too Many Requests","last_assistant_message":"API Error: Rate limit reached"}"#
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let n = try XCTUnwrap(HookNotice.parse(Data(json.utf8), date: t))
        XCTAssertEqual(n.kind, .failure)
        XCTAssertEqual(n.error, "rate_limit")
        XCTAssertEqual(n.message, "API Error: Rate limit reached")
        XCTAssertTrue(n.isFreshFailure(lastActivity: t.addingTimeInterval(-5), now: t.addingTimeInterval(60)))
        // Xatodan keyin sessiyada yozilgan — endi dolzarb emas; ruxsat kutish ham emas
        XCTAssertFalse(n.isFreshFailure(lastActivity: t.addingTimeInterval(30), now: t.addingTimeInterval(60)))
        XCTAssertFalse(n.isPending(lastActivity: nil, now: t))
    }
}
