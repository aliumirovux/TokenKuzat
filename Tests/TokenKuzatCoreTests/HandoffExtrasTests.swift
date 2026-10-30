import XCTest
@testable import TokenKuzatCore

final class HandoffExtrasTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func session(replies: [String], prompts: [String] = ["Dizaynni tekshir"], input: String? = nil) -> SessionSnap {
        var steps: [StepSnap] = []
        if let input {
            var st = StepSnap(id: "f", date: t0, symbol: "doc", text: "Figma", category: .other, targetName: "get_design_context",
                              targetKey: "other|figma", targetDetail: "", access: .read, duration: 1, status: .done, turn: 1)
            st.input = input
            steps.append(st)
        }
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: 3, topTools: [("Bash", 5), ("mcp__figma__get_screenshot", 2)], lastAction: "",
                             state: .idle, lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: [], bigResults: [])
        let turns = prompts.enumerated().map { i, p in
            TurnSnap(id: i + 1, prompt: p, start: t0, end: t0, tokens: TokenCounts(), steps: 0, errors: 0, active: false)
        }
        var s = SessionSnap(id: "s", project: "Demo", title: "t", model: "Opus", contextTokens: 300_000,
                            tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                            lastActivity: t0, state: .idle, turns: turns)
        s.notes = replies.enumerated().map { NoteSnap(id: "r\($0.offset)", date: t0, kind: .reply, text: $0.element, duration: nil, turn: nil, agent: nil) }
        return s
    }

    func testLastListIsTakenVerbatimFromRecentReplies() {
        let list = "1. Hook qo'shish\n   faqat katta fayllar\n2. max_tokens chegarasi\n3. Xulosani to'ldirish"
        let s = session(replies: ["Reja:\n\n" + list + "\n\nQaysi biridan boshlay?", "Yaxshi, kutaman."])
        XCTAssertEqual(SavingsAdvisor.lastList(s), list)
        let table = "| # | Ish |\n|---|---|\n| 1 | Karta |"
        XCTAssertEqual(SavingsAdvisor.lastList(session(replies: ["Natija:\n" + table])), table)
        XCTAssertNil(SavingsAdvisor.lastList(session(replies: ["Ro'yxatsiz javob.\n1. bitta band"])))
    }

    func testResourcesCollectLinksAndFigmaKeys() {
        let s = session(replies: ["Fayl: https://www.figma.com/design/AbC123xyz456/iWon?node-id=1-2.", "Reliz: [v1](https://github.com/a/b/releases/tag/v1)"],
                        prompts: ["Mana link https://www.figma.com/design/AbC123xyz456/iWon?node-id=1-2 va http://localhost:3000"],
                        input: #"{"fileKey":"ZZtop987654321","nodeId":"1:2"} {"fileKey":"ZZtop98765"} {"fileKey":"AbC123xyz456"} http://[::1]:8080 https://api.x.org/bot{tok}/get"#)
        XCTAssertEqual(SavingsAdvisor.resources(s), [
            "https://www.figma.com/design/AbC123xyz456/iWon?node-id=1-2",
            "https://github.com/a/b/releases/tag/v1",
            "Figma fileKey: ZZtop987654321",
        ])
    }
}
