import XCTest
@testable import TokenKuzatCore

final class SavingsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func step(_ i: Int, _ key: String, access: ToolAccess, failed: Bool = false) -> StepSnap {
        StepSnap(id: "s\(i)", date: t0.addingTimeInterval(Double(i)), symbol: "doc", text: "O'qiyapti · \(key)",
                 category: .files, targetName: key, targetKey: "files|/p/\(key)", targetDetail: "/p", access: access,
                 duration: 1, status: failed ? .failed : .done, turn: 1)
    }

    private func session(context: Int, steps: [StepSnap], calls: Int = 60) -> SessionSnap {
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: calls, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: [])
        let turn = TurnSnap(id: 1, prompt: "Xaritani yangila", start: t0, end: t0.addingTimeInterval(60),
                            tokens: TokenCounts(), steps: steps.count, errors: 0, active: false)
        return SessionSnap(id: "s", project: "Demo", title: "t", model: "Opus", contextTokens: context,
                           tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                           lastActivity: t0, state: .idle, turns: [turn], contextWindow: 1_000_000)
    }

    func testBigContextTip() throws {
        let tips = SavingsAdvisor.tips(for: session(context: 500_000, steps: []), now: t0)
        let tip = try XCTUnwrap(tips.first { $0.kind == .bigContext })
        XCTAssertEqual(tip.level, .high)
        XCTAssertEqual(tip.tokens, 500_000 - SavingsAdvisor.baseline)
        XCTAssertTrue(tip.perCall)
    }

    func testSmallContextHasNoTip() {
        XCTAssertTrue(SavingsAdvisor.tips(for: session(context: 60_000, steps: []), now: t0).isEmpty)
    }

    func testRepeatedReadsResetAfterWrite() {
        // a.swift 4 marta o'qildi (3 takror), keyin yozildi, yana 1 marta — takror emas; b.swift 2 marta (1 takror)
        var st: [StepSnap] = (0..<4).map { step($0, "a.swift", access: .read) }
        st.append(step(10, "a.swift", access: .write))
        st.append(step(11, "a.swift", access: .read))
        st += [step(20, "b.swift", access: .read), step(21, "b.swift", access: .read)]
        let tip = SavingsAdvisor.tips(for: session(context: 60_000, steps: st), now: t0).first { $0.kind == .repeatedReads }
        XCTAssertEqual(tip?.title, "4 ta takroriy fayl o'qish")
    }

    func testHandoffListsChangedFiles() {
        let s = session(context: 400_000, steps: [step(1, "Map.swift", access: .write)])
        let text = SavingsAdvisor.handoff(for: s)
        XCTAssertTrue(text.contains("/p/Map.swift"))
        XCTAssertTrue(text.contains("#1: Xaritani yangila"))
    }
}
