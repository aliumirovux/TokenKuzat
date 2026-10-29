import XCTest
@testable import TokenKuzatCore

final class UpdatesTests: XCTestCase {
    func testVersionCompare() {
        XCTAssertTrue(AppVersion.isNewer("6.27.0", than: "6.26.1"))
        XCTAssertTrue(AppVersion.isNewer("7.0", than: "6.99.9"))
        XCTAssertTrue(AppVersion.isNewer("6.26.10", than: "6.26.9"))
        XCTAssertFalse(AppVersion.isNewer("6.26.1", than: "6.26.1"))
        XCTAssertFalse(AppVersion.isNewer("6.26.0", than: "6.26.1"))
        XCTAssertTrue(AppVersion.isNewer("6.26.1", than: "dev"))
    }

    func testParseRelease() {
        let json = """
        {"tag_name":"v6.27.0","html_url":"https://github.com/aliumirovux/TokenKuzat/releases/tag/v6.27.0","draft":false,"prerelease":false,
         "body":"notes","assets":[{"name":"TokenKuzatuv-6.27.0.dmg.sha256","browser_download_url":"https://x/a.sha256"},
                                  {"name":"TokenKuzatuv-6.27.0.dmg","browser_download_url":"https://x/a.dmg"}]}
        """
        let r = ReleaseInfo.parse(Data(json.utf8))
        XCTAssertEqual(r?.version, "6.27.0")
        XCTAssertEqual(r?.downloadURL.absoluteString, "https://x/a.dmg")
        XCTAssertNil(ReleaseInfo.parse(Data(#"{"tag_name":"v7","html_url":"https://x","prerelease":true}"#.utf8)))
        XCTAssertNil(ReleaseInfo.parse(Data("{}".utf8)))
    }
}
