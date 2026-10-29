import XCTest
@testable import TokenKuzatCore

final class AutoCompactWindowTests: XCTestCase {
    func testSmallestExplicitWindowWins() {
        let settings: [String: Any] = [
            "autoCompactWindow": 400_000,
            "modelSettings": ["claude-opus-5-5": ["autoCompactWindow": 150_000], "claude-haiku-5-5": ["autoCompactWindow": "auto"]],
        ]
        XCTAssertEqual(AutoCompactWindow.smallest(settings: settings, env: [:]),
                       .init(tokens: 150_000, source: "modelSettings.claude-opus-5-5"))
        XCTAssertEqual(AutoCompactWindow.smallest(settings: settings, env: ["CLAUDE_CODE_AUTO_COMPACT_WINDOW": "120000"])?.tokens, 120_000)
        XCTAssertEqual(AutoCompactWindow.smallest(settings: ["env": ["CLAUDE_CODE_AUTO_COMPACT_WINDOW": "130000"]], env: [:])?.tokens, 130_000)
    }

    func testAutoAndOutOfRangeAreIgnored() {
        XCTAssertNil(AutoCompactWindow.smallest(settings: ["autoCompactWindow": "auto"], env: [:]))
        XCTAssertNil(AutoCompactWindow.smallest(settings: ["autoCompactWindow": 50_000], env: ["CLAUDE_CODE_AUTO_COMPACT_WINDOW": "x"]))
        XCTAssertNil(AutoCompactWindow.smallest(settings: [:], env: [:]))
    }
}
