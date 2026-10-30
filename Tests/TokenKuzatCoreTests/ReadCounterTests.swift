import XCTest
@testable import TokenKuzatCore

final class ReadCounterTests: XCTestCase {
    private func bash(_ c: String) -> Bool { ReadCounter.isRead(tool: "Bash", input: ["command": c]) }

    func testNativeTools() {
        XCTAssertTrue(ReadCounter.isRead(tool: "Read", input: ["file_path": "/a"]))
        XCTAssertTrue(ReadCounter.isRead(tool: "Grep", input: nil))
        XCTAssertTrue(ReadCounter.isRead(tool: "Glob", input: nil))
        XCTAssertTrue(ReadCounter.isRead(tool: "NotebookRead", input: nil))
        XCTAssertFalse(ReadCounter.isRead(tool: "Edit", input: ["file_path": "/a"]))
        XCTAssertFalse(ReadCounter.isRead(tool: "Bash", input: nil))
    }

    func testBashReads() {
        XCTAssertTrue(bash("cat a && grep x b"))
        XCTAssertTrue(bash("cd /x && sed -n 1,5p f"))
        XCTAssertTrue(bash("git log --oneline"))
        XCTAssertTrue(bash("git -C /x diff HEAD"))
        XCTAssertTrue(bash("ls -la | wc -l"))
        XCTAssertTrue(bash("grep -rn 'a && b' Sources 2>/dev/null"))
        XCTAssertTrue(bash("find . -name '*.swift'"))
        XCTAssertTrue(bash("grep -rn foo . | sort | head"))
        XCTAssertTrue(bash("grep x file || true"))
        XCTAssertTrue(bash("cat a; echo ---; cat b"))
        XCTAssertTrue(bash("git status --short && git diff"))
        XCTAssertTrue(bash("grep -q x f > /dev/null"))
        XCTAssertTrue(bash("grep x f 2>&1"))
        XCTAssertTrue(bash("grep x f &>/dev/null"))
        XCTAssertTrue(bash("grep x f >&2"))
        XCTAssertTrue(bash("(cd x && cat f)"))
        XCTAssertTrue(bash("{ cat a; cat b; }"))
        XCTAssertTrue(bash("find . -exec grep -l x {} +"))
        XCTAssertTrue(bash("find . -name '*.swift' -exec cat {} \\;"))
        XCTAssertTrue(bash("find . -name x | xargs grep y"))
        XCTAssertTrue(bash("git branch -a"))
        XCTAssertTrue(bash("echo \"a > b\" && cat f"))
    }

    func testBashNotReads() {
        XCTAssertFalse(bash("sed -i '' s/a/b/ f"))
        XCTAssertFalse(bash("swift test"))
        XCTAssertFalse(bash("git commit -m x"))
        XCTAssertFalse(bash("echo hi > file"))
        XCTAssertFalse(bash("cat a > b"))
        XCTAssertFalse(bash("python3 script.py"))
        XCTAssertFalse(bash("swift build && cat log"))
        XCTAssertFalse(bash("find . -name x -delete"))
        XCTAssertFalse(bash("cd /x"))
        XCTAssertFalse(bash("echo hi"))
        XCTAssertFalse(bash("sed --in-place=.bak s/a/b/ f"))
        XCTAssertFalse(bash("sed -i.bak s/a/b/ f"))
        XCTAssertFalse(bash("sed -Ei s/a/b/ f"))
        XCTAssertFalse(bash("cat file>out"))
        XCTAssertFalse(bash("cat file>>out"))
        XCTAssertFalse(bash("awk '{print > \"x\"}' f"))
        XCTAssertFalse(bash("awk 'BEGIN{system(\"rm x\")}'"))
        XCTAssertFalse(bash("sed 's/a/b/w out' f"))
        XCTAssertFalse(bash("sed -n '/a/w out' f"))
        XCTAssertFalse(bash("find . -fprint out"))
        XCTAssertFalse(bash("find . -exec rm {} \\;"))
        XCTAssertFalse(bash("grep x f | xargs rm"))
        XCTAssertFalse(bash("git branch newbranch"))
        XCTAssertFalse(bash("cat f && rm g"))
    }
}
