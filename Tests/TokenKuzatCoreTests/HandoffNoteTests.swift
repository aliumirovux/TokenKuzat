import XCTest
@testable import TokenKuzatCore

final class HandoffNoteTests: XCTestCase {
    func testAskStartsBeforeTheThreshold() {
        XCTAssertEqual(HandoffNote.askFrom(thresholdK: 200), 170_000)
        XCTAssertEqual(HandoffNote.askFrom(thresholdK: 100), 80_000)     // kamida 20K oldin
        XCTAssertEqual(HandoffNote.askFrom(thresholdK: 500), 425_000)
    }

    func testExtractsTheLastNoteAndTheReplyWithoutIt() throws {
        let reply = "Tayyor, commit qilindi.\n\n<!-- tk-handoff\nIsh: Ko'chirish eslatmasi\nQolgan: testlar\n-->"
        let x = try XCTUnwrap(HandoffNote.extract(from: reply))
        XCTAssertEqual(x.note, "Ish: Ko'chirish eslatmasi\nQolgan: testlar")
        XCTAssertEqual(x.rest, "Tayyor, commit qilindi.")
        XCTAssertEqual(HandoffNote.field(x.note, ["Ish", "Task"]), "Ko'chirish eslatmasi")
        XCTAssertNil(HandoffNote.field(x.note, ["Muhim"]))
        XCTAssertNil(HandoffNote.extract(from: "Oddiy javob"))
        XCTAssertNil(HandoffNote.extract(from: "Bo'sh <!-- tk-handoff\n-->"))
        // Yopilmagan izoh (javob kesilgan) — oxirigacha olinadi
        XCTAssertEqual(HandoffNote.extract(from: "A\n<!-- tk-handoff\nIsh: X")?.note, "Ish: X")
    }

    func testHookAsksOnlyListedSessionsInTheirLanguage() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("note-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        func input(_ sid: String) -> Data { try! JSONSerialization.data(withJSONObject: ["session_id": sid, "prompt": "davom et"]) }
        XCTAssertNil(NoteRequestStore.handlePrompt(input: input("a"), at: url))
        NoteRequestStore.save(["a": .init(context: 180_000, english: false)], at: url)
        let out = try XCTUnwrap(NoteRequestStore.handlePrompt(input: input("a"), at: url))
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(out.utf8)) as? [String: Any])
        let h = try XCTUnwrap(o["hookSpecificOutput"] as? [String: Any])
        XCTAssertEqual(h["hookEventName"] as? String, "UserPromptSubmit")
        let ctx = try XCTUnwrap(h["additionalContext"] as? String)
        XCTAssertTrue(ctx.contains("180K") && ctx.contains("<!-- tk-handoff") && ctx.contains("Kutilayotgan qaror"))
        XCTAssertNil(NoteRequestStore.handlePrompt(input: input("b"), at: url))
        // Bo'sh ro'yxat — fayl o'chadi (hook skripti ilovani umuman ishga tushirmaydi)
        NoteRequestStore.save([:], at: url)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }
}
