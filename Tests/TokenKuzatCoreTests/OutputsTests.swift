import XCTest
@testable import TokenKuzatCore

final class OutputsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func item(_ path: String, reads: Int, writes: Int, at: TimeInterval) -> ResourceItem {
        ResourceItem(id: "files|" + path, name: (path as NSString).lastPathComponent, detail: "", calls: reads + writes,
                     reads: reads, writes: writes, errors: 0, lastActivity: t0.addingTimeInterval(at))
    }

    func testCollectsImagesHtmlFromFilesAndShell() {
        let files = ResourceGroup(category: .files, calls: 4, errors: 0, lastActivity: t0, items: [
            item("/p/index.html", reads: 0, writes: 1, at: 10),
            item("/p/shot.png", reads: 2, writes: 0, at: 20),
            item("/p/App.swift", reads: 1, writes: 1, at: 30),
        ], busy: false)
        let main = AgentSnap(id: "s/main", title: "Asosiy", subtitle: "", kind: "", isMain: true, tokens: TokenCounts(),
                             calls: 1, topTools: [], lastAction: "", state: .idle, lastActivity: t0, firstActivity: t0,
                             steps: [], resources: [files], usage: [],
                             outputs: ["/tmp/x/map.png": t0.addingTimeInterval(40), "/p/index.html": t0.addingTimeInterval(50)])
        let s = SessionSnap(id: "s", project: "p", title: "t", model: "Opus", contextTokens: 0, tokens: TokenCounts(),
                            mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main], lastActivity: t0,
                            state: .idle, turns: [])
        let out = SessionOutputs.collect(s, exists: { $0 != "/p/gone.png" })
        XCTAssertEqual(out.map(\.path), ["/p/index.html", "/tmp/x/map.png", "/p/shot.png"])
        XCTAssertEqual(out.first?.kind, .web)
        XCTAssertTrue(out[0].written)
        XCTAssertFalse(out[2].written)
    }

    func testBashCommandPathsInDescription() {
        let d = ToolDescriber.describe("Bash", ["command": "app --snapshot-map /tmp/x/map.png --zoom 0.8", "description": "Rasm"])
        XCTAssertEqual(d.paths, ["/tmp/x/map.png"])
        XCTAssertEqual(d.text, "Terminal · Rasm")
    }

    func testVariablesExpanded() {
        let cmd = "SP=/private/tmp/sp; \"$EXE\" --snapshot-map $SP/focus.png; sips -Z 1000 ${SP}/f.png --out \"$SP/f s.png\""
        XCTAssertEqual(SessionOutputs.paths(in: cmd), ["/private/tmp/sp/focus.png", "/private/tmp/sp/f.png", "/private/tmp/sp/f s.png"])
    }

    func testPathsInText() {
        XCTAssertEqual(SessionOutputs.paths(in: "cp a.png '/Users/a/My dir/x.png'; open \"/tmp/r.HTML\""), ["/Users/a/My dir/x.png", "/tmp/r.HTML"])
        XCTAssertEqual(SessionOutputs.paths(in: "sips -Z 1000 /tmp/f.png --out /tmp/f2.png"), ["/tmp/f.png", "/tmp/f2.png"])
    }
}
