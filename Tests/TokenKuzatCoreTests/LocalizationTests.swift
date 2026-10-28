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
}
