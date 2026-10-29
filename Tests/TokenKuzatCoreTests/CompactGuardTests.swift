import XCTest
@testable import TokenKuzatCore

final class CompactGuardTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testParsesCompactBoundary() throws {
        let json = #"{"type":"system","subtype":"compact_boundary","timestamp":"2026-10-28T10:00:00.000Z","compactMetadata":{"trigger":"auto","preTokens":968207,"postTokens":35792}}"#
        let ev = try XCTUnwrap(TranscriptParser.parse(Data(json.utf8)))
        guard case .compact(let auto, let before, let after) = ev.kind else { return XCTFail("compact kutilgan edi") }
        XCTAssertTrue(auto)
        XCTAssertEqual(before, 968_207)
        XCTAssertEqual(after, 35_792)
        XCTAssertNotNil(ev.timestamp)
    }

    func testManualCompactAndOtherSystemLines() throws {
        let manual = #"{"type":"system","subtype":"compact_boundary","compactMetadata":{"trigger":"manual","preTokens":1,"postTokens":1}}"#
        guard case .compact(let auto, _, _) = try XCTUnwrap(TranscriptParser.parse(Data(manual.utf8))).kind else { return XCTFail() }
        XCTAssertFalse(auto)
        XCTAssertNil(TranscriptParser.parse(Data(#"{"type":"system","subtype":"api_error"}"#.utf8)))
    }

    func testCompactionMatchesContinuationTurn() {
        let old = Compaction(date: t0.addingTimeInterval(-3600), auto: true, before: 1, after: 1)
        let c = Compaction(date: t0.addingTimeInterval(-70), auto: true, before: 968_000, after: 36_000)
        XCTAssertEqual(Engine.compaction(before: t0, in: [old, c]), c)
        // 10 daqiqadan eski qisqartirish — boshqa joyniki
        XCTAssertNil(Engine.compaction(before: t0, in: [old]))
        XCTAssertEqual(c.change, Fmt.tokens(968_000) + " → " + Fmt.tokens(36_000))
    }

    func testBlocksOnlyActiveGuardedAutoCompactOnce() {
        let g: Set<String> = ["s"]
        XCTAssertTrue(CompactGuard.shouldBlock(trigger: "auto", sessionId: "s", guarded: g, blockedBefore: false, transcriptAge: 3))
        // /compact — foydalanuvchining o'zi so'radi
        XCTAssertFalse(CompactGuard.shouldBlock(trigger: "manual", sessionId: "s", guarded: g, blockedBefore: false, transcriptAge: 3))
        XCTAssertFalse(CompactGuard.shouldBlock(trigger: "auto", sessionId: "x", guarded: g, blockedBefore: false, transcriptAge: 3))
        // Ikkinchi urinish — kontekst haqiqatan to'lgan bo'lishi mumkin, ruxsat beriladi
        XCTAssertFalse(CompactGuard.shouldBlock(trigger: "auto", sessionId: "s", guarded: g, blockedBefore: true, transcriptAge: 3))
        // Jim turgan sessiyani qisqartirish — tegilmaydi
        XCTAssertFalse(CompactGuard.shouldBlock(trigger: "auto", sessionId: "s", guarded: g, blockedBefore: false, transcriptAge: 900))
        XCTAssertFalse(CompactGuard.shouldBlock(trigger: "auto", sessionId: "s", guarded: g, blockedBefore: false, transcriptAge: nil))
    }

    func testHandlePreCompactWritesMarkerOnce() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let guardURL = dir.appendingPathComponent("guard.json"), blockedURL = dir.appendingPathComponent("blocked.json")
        let transcript = dir.appendingPathComponent("t.jsonl")
        try Data("{}".utf8).write(to: transcript)
        CompactGuard.saveGuarded(["s"], at: guardURL)
        let input = Data(#"{"session_id":"s","hook_event_name":"PreCompact","trigger":"auto","transcript_path":"\#(transcript.path)"}"#.utf8)

        let out = try XCTUnwrap(CompactGuard.handlePreCompact(input: input, guardURL: guardURL, blockedURL: blockedURL))
        let o = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any])
        XCTAssertEqual(o["decision"] as? String, "block")
        XCTAssertNotNil(CompactGuard.loadBlocked(at: blockedURL)["s"])
        XCTAssertNil(CompactGuard.handlePreCompact(input: input, guardURL: guardURL, blockedURL: blockedURL))

        // Ro'yxat bo'sh — fayl o'chadi
        CompactGuard.saveGuarded([], at: guardURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: guardURL.path))
    }

    func testBlockedCompactTriggersHandoffBelowThreshold() {
        XCTAssertFalse(AutoHandoffRule.shouldTrigger(previous: .running, state: .idle, context: 150_000, thresholdK: 200,
                                                     waitingPermission: false, alreadyDone: false))
        XCTAssertTrue(AutoHandoffRule.shouldTrigger(previous: .running, state: .idle, context: 150_000, thresholdK: 200,
                                                    waitingPermission: false, alreadyDone: false, compactBlocked: true))
        XCTAssertFalse(AutoHandoffRule.shouldTrigger(previous: .running, state: .idle, context: 150_000, thresholdK: 200,
                                                     waitingPermission: false, alreadyDone: true, compactBlocked: true))
    }
}
