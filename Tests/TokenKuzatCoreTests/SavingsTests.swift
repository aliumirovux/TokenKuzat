import XCTest
@testable import TokenKuzatCore

final class SavingsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    private func step(_ i: Int, _ key: String, access: ToolAccess, failed: Bool = false) -> StepSnap {
        StepSnap(id: "s\(i)", date: t0.addingTimeInterval(Double(i)), symbol: "doc", text: "O'qiyapti · \(key)",
                 category: .files, targetName: key, targetKey: "files|/p/\(key)", targetDetail: "/p", access: access,
                 duration: 1, status: failed ? .failed : .done, turn: 1)
    }

    private func point(_ i: Int, context: Int, longCache: Bool? = nil) -> UsagePoint {
        UsagePoint(date: t0.addingTimeInterval(Double(i)), tokens: TokenCounts(cacheRead: context), longCache: longCache)
    }

    private func session(context: Int, steps: [StepSnap], calls: Int = 60, usage: [UsagePoint] = [],
                         bigResults: [BigResult] = []) -> SessionSnap {
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: calls, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: usage,
                             bigResults: bigResults)
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

    func testHandoffAddsGitStateAndFollowsConversationLanguage() {
        let s = session(context: 400_000, steps: [step(1, "Map.swift", access: .write)])
        let text = Lang.with(english: true) {
            SavingsAdvisor.handoff(for: s, gitLines: { paths in ["- /p: last commit abc fix (\(paths.count))"] })
        }
        // Bitta qisqa prompt («Xaritani yangila») — tilni aniqlab bo'lmaydi, ilova tili qoladi
        XCTAssertTrue(text.contains("Git state"))
        XCTAssertTrue(text.contains("- /p: last commit abc fix (1)"))
        XCTAssertTrue(text.contains("check first"))
    }

    private func handoffSession(title: String, prompts: [String], cwd: String?, files: [String] = [],
                                texts: [String?] = [], reply: String? = nil, toolInput: String? = nil) -> SessionSnap {
        var steps = files.enumerated().map { i, f in
            StepSnap(id: "w\(i)", date: t0, symbol: "doc", text: "Yozyapti", category: .files, targetName: f,
                     targetKey: "files|\(f)", targetDetail: "", access: .write, duration: 1, status: .done, turn: 1)
        }
        if let toolInput {
            var st = StepSnap(id: "ask", date: t0, symbol: "checkmark", text: "wrap_up", category: .other, targetName: "wrap_up",
                              targetKey: "other|wrap_up", targetDetail: "", access: .run, duration: 1, status: .done, turn: 1)
            st.input = toolInput
            steps.append(st)
        }
        let main = AgentSnap(id: "s/main", title: "Asosiy agent", subtitle: "Opus", kind: "", isMain: true,
                             tokens: TokenCounts(), calls: 10, topTools: [], lastAction: "", state: .idle,
                             lastActivity: t0, firstActivity: t0, steps: steps, resources: [], usage: [], bigResults: [])
        let turns = prompts.enumerated().map { i, p in
            TurnSnap(id: i + 1, prompt: p, text: i < texts.count ? texts[i] : nil, start: t0, end: t0,
                     tokens: TokenCounts(), steps: 0, errors: 0, active: false)
        }
        var s = SessionSnap(id: "s", project: "Demo", title: title, model: "Opus", contextTokens: 300_000,
                            tokens: TokenCounts(), mainTokens: TokenCounts(), agentTokens: TokenCounts(), agents: [main],
                            lastActivity: t0, state: .idle, turns: turns)
        s.cwd = cwd
        if let reply {
            s.notes = [NoteSnap(id: "r", date: t0, kind: .reply, text: reply, duration: nil, turn: nil, agent: nil)]
        }
        return s
    }

    func testHandoffStartsWithProjectAndTaskAndDropsNoise() {
        let s = handoffSession(title: "↪ Ofis modini plaginga qo'shish",
                               prompts: ["Token Kuzatuv: oldingi sessiya konteksti 204K ga yetgani uchun",
                                         "https://www.instagram.com/reel/abc", "Ha, yasa",
                                         "Ofis panelini Claude Code ichida ko'rsat", "Ha, push qil"],
                               cwd: "/nonexistent/TokenKuzat")
        let text = Lang.with(english: false) { SavingsAdvisor.handoff(for: s, gitLines: { _ in [] }) }
        XCTAssertTrue(text.hasPrefix("↪ Demo — Ofis modini plaginga qo'shish\n"))
        XCTAssertFalse(text.contains("Token Kuzatuv:"))
        XCTAssertFalse(text.contains("instagram"))
        XCTAssertFalse(text.contains("Ha, yasa"))
        XCTAssertTrue(text.contains("#4: Ofis panelini Claude Code ichida ko'rsat"))
        XCTAssertTrue(text.contains("#5: Ha, push qil"))       // oxirgi javob — qaror shunda bo'lishi mumkin
    }

    func testHandoffTaskFallsBackToLastMeaningfulPrompt() {
        let s = handoffSession(title: "Nomsiz sessiya", prompts: ["kartalar joylashuvini tuzat", "Ha, chiqar"], cwd: nil)
        XCTAssertEqual(SavingsAdvisor.handoffTask(s), "kartalar joylashuvini tuzat")
        let long = handoffSession(title: String(repeating: "uzun so'z ", count: 20), prompts: [], cwd: nil)
        XCTAssertLessThanOrEqual(SavingsAdvisor.handoffTask(long)!.count, 61)
    }

    func testProjectFolderComesFromWrittenFilesWhenSessionRanInScratch() throws {
        let fm = FileManager.default
        let repo = fm.temporaryDirectory.appendingPathComponent("tk-\(UUID().uuidString)/MyApp")
        try fm.createDirectory(at: repo.appendingPathComponent(".git"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: repo.deletingLastPathComponent()) }
        let scratch = "/Users/x/Library/Application Support/Claude/scratch-workspaces/abc"
        let s = handoffSession(title: "Ofis paneli", prompts: [], cwd: scratch,
                               files: [repo.appendingPathComponent("a.swift").path, "/private/tmp/scratchpad/notes.md"])
        XCTAssertEqual(SavingsAdvisor.projectFolder(for: s), repo.path)
        let text = Lang.with(english: false) { SavingsAdvisor.handoff(for: s, gitLines: { _ in [] }) }
        XCTAssertTrue(text.hasPrefix("↪ MyApp — Ofis paneli\n"))
        XCTAssertTrue(text.contains("Loyiha papkasi: \(repo.path)"))
        // Loyiha topilmasa — vaqtinchalik papka nomi sarlavhaga chiqmaydi
        let bare = handoffSession(title: "Ofis paneli", prompts: [], cwd: scratch)
        XCTAssertNil(SavingsAdvisor.projectFolder(for: bare))
        XCTAssertTrue(SavingsAdvisor.handoff(for: bare, gitLines: { _ in [] }).hasPrefix("↪ Ofis paneli\n"))
    }

    func testHandoffKeepsTheEndOfALongReplyAndThePendingQuestion() {
        let reply = "Boshlanish qismi. " + String(repeating: "Tahlil davom etadi. ", count: 150)
            + "\n**Taklifim:** 3. Sessiya loyiha papkasida ochiladi.\nQaysidan boshlaymiz?"
        let s = handoffSession(title: "Ofis paneli", prompts: ["Ofis panelini plaginga qo'sh"], cwd: nil, reply: reply)
        let text = Lang.with(english: false) { SavingsAdvisor.handoff(for: s, gitLines: { _ in [] }) }
        XCTAssertTrue(text.contains("3. Sessiya loyiha papkasida ochiladi."))
        XCTAssertFalse(text.contains("Boshlanish qismi"))
        XCTAssertTrue(text.contains("Kutilayotgan qaror (foydalanuvchi hali javob bermagan): Qaysidan boshlaymiz?"))
        // Transkriptdan o'qilganda ham uzun javobning oxiri yo'qolmaydi
        let clipped = TranscriptParser.clipMiddle(reply, TranscriptEvent.noteLimit)
        XCTAssertTrue(clipped.hasPrefix("Boshlanish qismi.") && clipped.hasSuffix("Qaysidan boshlaymiz?"))
        XCTAssertLessThan(clipped.count, TranscriptEvent.noteLimit + 5)
    }

    func testPendingQuestionComesFromTheClosingAsk() {
        // Kiritma kesilgan bo'lsa ham (JSON yopilmagan) — «ask» maydoni topiladi
        let input = "{\n  \"actions\" : [],\n  \"ask\" : \"Release this as \\\"6.44.0\\\"?\",\n  \"recap\" : \"All three…"
        let s = handoffSession(title: "Ofis paneli", prompts: ["Ofis panelini plaginga qo'sh"], cwd: nil,
                               reply: "Uchala tuzatish kiritildi.", toolInput: input)
        XCTAssertEqual(SavingsAdvisor.pendingQuestion(s), "Release this as \"6.44.0\"?")
        let none = handoffSession(title: "t", prompts: ["Ofis panelini plaginga qo'sh"], cwd: nil, reply: "Tayyor.")
        XCTAssertNil(SavingsAdvisor.pendingQuestion(none))
    }

    func testHandoffLeadsWithClaudesNote() {
        let reply = "Commit qilindi. Keyingisi nima bo'lsin?\n\n<!-- tk-handoff\nIsh: Claude yozadigan ko'chirish eslatmasi\n"
            + "Qolgan: Settings'da yoqish\nKutilayotgan qaror: 6.44.0 relizi\n-->"
        let s = handoffSession(title: "TokenKuzat uchun qilish kerak", prompts: ["2-bandni boshla, eslatma kerak"], cwd: nil, reply: reply)
        let text = Lang.with(english: false) { SavingsAdvisor.handoff(for: s, gitLines: { _ in [] }) }
        XCTAssertTrue(text.hasPrefix("↪ Demo — Claude yozadigan ko'chirish eslatmasi\n"))
        XCTAssertTrue(text.contains("asosan shunga tayan):\nIsh: Claude yozadigan ko'chirish eslatmasi\nQolgan: Settings'da yoqish"))
        XCTAssertFalse(text.contains("<!--"))
        XCTAssertTrue(text.contains("Oxirgi holat (oldingi javobdan):\nCommit qilindi."))
        XCTAssertEqual(SavingsAdvisor.pendingQuestion(s), "Commit qilindi. Keyingisi nima bo'lsin?")
    }

    func testLastPromptsAreKeptInFullAndTempFilesDropped() {
        let long = "bir muammo bor ishlab turgan sessionda token ko'p ketishni boshlaganda yangi sessionga o'tishi yaxshi"
        let s = handoffSession(title: "t", prompts: ["Birinchi uzun vazifa matni", String(long.prefix(40))], cwd: nil,
                               files: ["/p/App.swift", "/private/tmp/claude-501/x/scratchpad/notes.md"],
                               texts: [nil, long + "\nfaqat yangi session boshlanganda qaysi loyiha davomi ekanligi"])
        let text = Lang.with(english: false) { SavingsAdvisor.handoff(for: s, gitLines: { _ in [] }) }
        XCTAssertTrue(text.contains("#2: " + long + "\n  faqat yangi session boshlanganda qaysi loyiha davomi ekanligi"))
        XCTAssertTrue(text.contains("/p/App.swift"))
        XCTAssertFalse(text.contains("scratchpad"))
    }

    func testCacheTTLFollowsLastWrite() {
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: session(context: 60_000, steps: [])), 300)
        let long = session(context: 60_000, steps: [], usage: [point(0, context: 50_000, longCache: true), point(1, context: 51_000)])
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: long), 3600)
        let short = session(context: 60_000, steps: [], usage: [point(0, context: 50_000, longCache: false)])
        XCTAssertEqual(SavingsAdvisor.cacheTTL(for: short), 300)
    }

    func testBigContextSavingUsesRealStart() throws {
        let s = session(context: 500_000, steps: [], usage: [point(0, context: 100_000), point(1, context: 500_000)])
        let tip = try XCTUnwrap(SavingsAdvisor.tips(for: s, now: t0).first { $0.kind == .bigContext })
        XCTAssertEqual(tip.tokens, 400_000)
    }

    func testCarriedStopsAtCompact() {
        // natija 5-soniyada; keyin 3 chaqiruv, so'ng /compact (kontekst 300K → 50K) — undan keyingilari sanalmaydi
        let usage = [point(4, context: 280_000), point(6, context: 290_000), point(7, context: 295_000),
                     point(8, context: 300_000), point(9, context: 50_000), point(10, context: 55_000)]
        let r = BigResult(date: t0.addingTimeInterval(5), tokens: 10_000, label: "Bash")
        XCTAssertEqual(SavingsAdvisor.carried(r, usage: usage), 30_000)
        XCTAssertTrue(SavingsAdvisor.liveResults([r], usage: usage).isEmpty)
    }

    func testBigResultsTip() throws {
        let usage = (0..<200).map { point($0, context: 200_000) }
        let r = BigResult(date: t0, tokens: 13_000, label: "c0f5615a-4595-4276-aa56-75e4262a0883: search_screens")
        let s = session(context: 200_000, steps: [], usage: usage, bigResults: [r, r])
        let tip = try XCTUnwrap(SavingsAdvisor.tips(for: s, now: t0).first { $0.kind == .bigResults })
        XCTAssertEqual(tip.tokens, 2 * 13_000 * 199)
        XCTAssertTrue(tip.detail.contains("search_screens ×2 — 26,0K"), tip.detail)
        XCTAssertFalse(tip.detail.contains("c0f5615a"))
    }

    func testHeavyStartTip() {
        let heavy = session(context: 120_000, steps: [], calls: 40, usage: [point(0, context: 103_000)])
        XCTAssertNotNil(SavingsAdvisor.tips(for: heavy, now: t0).first { $0.kind == .heavyStart })
        let light = session(context: 120_000, steps: [], calls: 40, usage: [point(0, context: 45_000)])
        XCTAssertNil(SavingsAdvisor.tips(for: light, now: t0).first { $0.kind == .heavyStart })
    }

    func testResultTokens() {
        XCTAssertEqual(TranscriptParser.resultTokens(String(repeating: "a", count: 4000)), 1000)
        let blocks: [[String: Any]] = [["type": "text", "text": String(repeating: "b", count: 400)], ["type": "image"]]
        XCTAssertEqual(TranscriptParser.resultTokens(blocks), 100 + 1_600)
    }
}
