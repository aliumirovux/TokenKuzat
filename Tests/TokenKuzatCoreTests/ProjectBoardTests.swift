import XCTest
@testable import TokenKuzatCore

final class ProjectBoardTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("resume-\(UUID().uuidString)")
    }

    override func tearDown() { try? FileManager.default.removeItem(at: dir) }

    private func session(_ id: String, cwd: String, ago: TimeInterval, prompt: String = "Kirish sahifasini tuzat",
                         reply: String = "Tayyor.", origin: String? = "cli", state: AgentState = .idle) -> SessionSnap {
        let t = now.addingTimeInterval(-ago)
        let turn = TurnSnap(id: 1, prompt: prompt, start: t.addingTimeInterval(-30), end: t,
                            tokens: TokenCounts(), steps: 0, errors: 0, active: false)
        var s = SessionSnap(id: id, project: URL(fileURLWithPath: cwd).lastPathComponent, title: prompt, model: "Opus",
                            contextTokens: 50_000, tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(),
                            agents: [], lastActivity: t, state: state, turns: [turn],
                            notes: [NoteSnap(id: "\(id)-r", date: t, kind: .reply, text: reply, duration: nil, turn: 1, agent: nil)],
                            cwd: cwd)
        s.origin = origin
        return s
    }

    private func cards(_ list: [SessionSnap]) -> [ProjectCard] {
        ProjectBoard.cards(list, folder: { $0.cwd })
    }

    func testOneCardPerFolderNewestFirst() {
        let c = cards([session("a1", cwd: "/p/app", ago: 7200), session("a2", cwd: "/p/app", ago: 600),
                       session("b1", cwd: "/p/web", ago: 60)])
        XCTAssertEqual(c.map(\.name), ["web", "app"])
        XCTAssertEqual(c[1].sessionId, "a2")
        XCTAssertEqual(c[1].sessions, 2)
        XCTAssertTrue(c[1].isTerminal)
    }

    func testSdkAndTemporarySessionsAreSkipped() {
        XCTAssertTrue(cards([session("x", cwd: "/p/app", ago: 60, origin: "sdk-cli")]).isEmpty)
        XCTAssertTrue(cards([session("t", cwd: "/tmp/claude-501", ago: 60), session("u", cwd: "/private/tmp/x", ago: 60)]).isEmpty)
    }

    func testStatusFromQuestionGitAndRunning() {
        var c = cards([session("a", cwd: "/p/app", ago: 60, reply: "Qildim.\n\nPush qilaymi?")])[0]
        XCTAssertEqual(c.status, .waiting)
        XCTAssertEqual(c.question, "Push qilaymi?")

        c = cards([session("a", cwd: "/p/app", ago: 60)])[0]
        XCTAssertEqual(c.status, .calm)
        c.git = ProjectGit(dirty: 0, ahead: 2)
        XCTAssertEqual(c.status, .unsaved)

        XCTAssertEqual(cards([session("a", cwd: "/p/app", ago: 5, state: .running)])[0].status, .running)
    }

    func testRemainingFromHandoffNote() {
        let reply = "Bajardim.\n\n[tk-handoff]: <Ish: Kirish sahifasi>\n[tk-handoff]: <Qolgan: mobil versiya>"
        let c = cards([session("a", cwd: "/p/app", ago: 60, reply: reply)])[0]
        XCTAssertEqual(c.task, "Kirish sahifasi")
        XCTAssertEqual(c.remaining, "mobil versiya")
        let none = "Bajardim.\n\n[tk-handoff]: <Ish: X ishi>\n[tk-handoff]: <Qolgan: yo'q>"
        XCTAssertNil(cards([session("a", cwd: "/p/app", ago: 60, reply: none)])[0].remaining)
    }

    // MARK: - Avtomatik davom

    private func input(_ sid: String, cwd: String, source: String = "startup") -> Data {
        try! JSONSerialization.data(withJSONObject: ["session_id": sid, "cwd": cwd, "source": source])
    }

    func testResumeDeliveredForSameFolderOnly() throws {
        try ResumeStore.save(PendingHandoff(text: "XULOSA", sourceSession: "old", cwd: "/p/app", created: now), in: dir)
        let out = try XCTUnwrap(ResumeStore.handleSessionStart(input: input("new", cwd: "/p/app"), in: dir, now: now + 600))
        XCTAssertTrue(out.contains("XULOSA"))
        // O'chirilmaydi — yangi sessiya hech narsa yozmay yopilsa, keyingisi ham oladi
        XCTAssertNotNil(ResumeStore.handleSessionStart(input: input("third", cwd: "/p/app/"), in: dir, now: now + 700))
        XCTAssertNil(ResumeStore.handleSessionStart(input: input("new", cwd: "/p/web"), in: dir, now: now + 600))
    }

    func testResumeNotDeliveredOnResumeClearSameSessionOrExpired() throws {
        try ResumeStore.save(PendingHandoff(text: "X", sourceSession: "old", cwd: "/p/app", created: now), in: dir)
        XCTAssertNil(ResumeStore.handleSessionStart(input: input("new", cwd: "/p/app", source: "resume"), in: dir, now: now + 60))
        XCTAssertNil(ResumeStore.handleSessionStart(input: input("new", cwd: "/p/app", source: "clear"), in: dir, now: now + 60))
        XCTAssertNil(ResumeStore.handleSessionStart(input: input("old", cwd: "/p/app"), in: dir, now: now + 60))
        XCTAssertNil(ResumeStore.handleSessionStart(input: input("new", cwd: "/p/app"), in: dir, now: now + ResumeStore.lifetime + 1))
    }

    func testResumeFoundFromSubfolderInsideSameGitProject() throws {
        let repo = dir.appendingPathComponent("repo").standardizedFileURL
        let sub = repo.appendingPathComponent("src/ui")
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        _ = GitState.git(repo.path, ["init", "-q"])
        try ResumeStore.save(PendingHandoff(text: "XULOSA", sourceSession: "old", cwd: repo.path, created: now), in: dir)
        XCTAssertEqual(ResumeStore.find(from: sub.path, in: dir)?.text, "XULOSA")
        // Git loyihasidan tashqaridagi papka — ota papka xulosasi berilmaydi
        let outside = dir.appendingPathComponent("plain/child")
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try ResumeStore.save(PendingHandoff(text: "B", sourceSession: "b", cwd: dir.appendingPathComponent("plain").path, created: now), in: dir)
        XCTAssertNil(ResumeStore.find(from: outside.path, in: dir))
    }

    func testTemporaryFolders() {
        XCTAssertTrue(ProjectBoard.isTemporaryFolder("/private/tmp/claude-501"))
        XCTAssertTrue(ProjectBoard.isTemporaryFolder("/Users/a/Library/Application Support/Claude/scratch-workspaces/x/y"))
        XCTAssertFalse(ProjectBoard.isTemporaryFolder("/Users/a/Developer/ytbot"))
    }

    func testPruneRemovesExpiredAndUnknownFolders() throws {
        try ResumeStore.save(PendingHandoff(text: "A", sourceSession: "a", cwd: "/p/app", created: now), in: dir)
        try ResumeStore.save(PendingHandoff(text: "B", sourceSession: "b", cwd: "/p/web", created: now), in: dir)
        try ResumeStore.save(PendingHandoff(text: "C", sourceSession: "c", cwd: "/p/old", created: now - ResumeStore.lifetime - 1), in: dir)
        ResumeStore.prune(keep: ["/p/app", "/p/old"], in: dir, now: now)
        XCTAssertNotNil(ResumeStore.load(folder: "/p/app", in: dir))
        XCTAssertNil(ResumeStore.load(folder: "/p/web", in: dir))
        XCTAssertNil(ResumeStore.load(folder: "/p/old", in: dir))
    }

    func testKeysDifferPerFolder() {
        XCTAssertNotEqual(ResumeStore.key("/p/app"), ResumeStore.key("/p/app2"))
        XCTAssertEqual(ResumeStore.key("/p/app/"), ResumeStore.key("/p/app"))
    }
}
