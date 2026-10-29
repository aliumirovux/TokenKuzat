import XCTest
@testable import TokenKuzatCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageFollowsMac() {
        XCTAssertTrue(Lang.resolve(.system, preferred: ["en-US", "uz-UZ"]))
        XCTAssertFalse(Lang.resolve(.system, preferred: ["ru-UZ", "en-US"]))
        XCTAssertFalse(Lang.resolve(.system, preferred: []))
        XCTAssertTrue(Lang.resolve(.en, preferred: ["uz-UZ"]))
        XCTAssertFalse(Lang.resolve(.uz, preferred: ["en-GB"]))
    }

    func testDefaultIsUzbek() {
        XCTAssertEqual(tr("Bugun", "Today"), "Bugun")
        XCTAssertEqual(Fmt.tokens(1234), "1,2K")
    }

    func testDetectEnglishFromPrompts() {
        XCTAssertEqual(Lang.detectEnglish(["yana nima qilishimiz mumkin takomlashtrish bo'yicha", "ha maqul"]), false)
        XCTAssertEqual(Lang.detectEnglish(["can you fix the build and add a test for this"]), true)
        XCTAssertNil(Lang.detectEnglish(["ok"]))
    }

    func testWithRestoresLanguage() {
        let before = Lang.isEnglish
        XCTAssertEqual(Lang.with(english: !before) { tr("uz", "en") }, before ? "uz" : "en")
        XCTAssertEqual(Lang.isEnglish, before)
    }

    /// Fondagi `Lang.with` boshqa oqimdagi (UI) tilni o'zgartirmasligi kerak
    func testWithOverrideStaysOnItsThread() {
        let base = Lang.isEnglish
        let inside = expectation(description: "override")
        let release = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            Lang.with(english: !base) {
                inside.fulfill()
                release.wait()
            }
        }
        wait(for: [inside], timeout: 2)
        XCTAssertEqual(Lang.isEnglish, base)
        release.signal()
        XCTAssertEqual(Lang.with(english: !base) { Lang.isEnglish }, !base)
        XCTAssertEqual(Lang.isEnglish, base)
    }
}
