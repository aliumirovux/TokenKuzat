import XCTest
@testable import TokenKuzatCore

/// Xulosadagi git holati: haqiqiy repodan o'qiladi, sekin git esa chaqiruvchini ushlab turmaydi
final class GitStateTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("gitstate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        XCTAssertNotNil(GitState.git(dir.path, ["init", "-q"]))
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testLinesShowLastCommitAndUncommittedFiles() throws {
        try "a".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        XCTAssertNotNil(GitState.git(dir.path, ["add", "a.txt"]))
        XCTAssertNotNil(GitState.git(dir.path, ["-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false",
                                                "commit", "-q", "--no-verify", "-m", "birinchi"]))
        try "b".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let lines = GitState.lines(for: [dir.appendingPathComponent("a.txt").path])
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("birinchi"), lines[0])
        XCTAssertTrue(lines[0].contains("commit qilinmagan: 1 ta fayl (b.txt)"), lines[0])
    }

    func testSlowGitTimesOut() {
        let started = Date()
        XCTAssertNil(GitState.git(dir.path, ["-c", "alias.hang=!sleep 5", "hang"], timeout: 0.3))
        XCTAssertLessThan(Date().timeIntervalSince(started), 2)
    }
}
