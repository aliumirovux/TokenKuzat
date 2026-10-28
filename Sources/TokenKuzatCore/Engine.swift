import Foundation

// Claude Code har bir sessiyani ~/.claude/projects/<loyiha>/<sessiya>.jsonl ga yozadi.
// Yordamchi agentlar: <sessiya>/subagents/agent-<id>.jsonl (+ agent-<id>.meta.json).
// Engine fayllarning faqat yangi qo'shilgan baytlarini o'qiydi (tail) — har soniyada ishlasa ham yengil.
// Engine thread-safe emas: uni bitta navbatdan (Store'dagi queue) chaqiring.

public final class Engine {
    public struct Config {
        public var roots: [URL]
        /// Shuncha kun ichida o'zgargan fayllar o'qiladi (tarix grafigi uchun)
        public var historyDays = 30
        /// Sessiyalar ro'yxatida shuncha kunlik sessiyalar ko'rinadi
        public var sessionDays = 7
        public var calendar = Calendar.current

        public init(roots: [URL] = Engine.defaultRoots()) {
            self.roots = roots
        }
    }

    /// Har bir yangi qator bilan oshadi — UI faqat o'zgarish bo'lganda yangilanadi
    public private(set) var revision = 0

    private let config: Config
    private let history: HistoryStore?
    private let fm = FileManager.default
    private var files: [String: FileState] = [:]
    private var sessions: [String: SessionAcc] = [:]
    private var seenUsage = Set<String>()
    private var seenTools = Set<String>()
    /// Natijasi hali kelmagan asbob chaqiruvlari: tool_use id → qadam
    private var pendingSteps: [String: StepAcc] = [:]
    private var dayTotals: [String: TokenCounts] = [:]
    private var minutes: [Int: MinuteBucket] = [:]
    private var feed: [FeedEvent] = []
    private var feedIds = Set<String>()
    private var sources: [SourceInfo] = []
    private var sourceLines: [Int: Int] = [:]
    private var sourceUsage: [Int: Int] = [:]
    private var lastDiscovery = Date.distantPast
    private var lastHistorySave = Date.distantPast
    private var initialDone = false
    private var now = Date()

    private var calendar: Calendar { config.calendar }
    private var dayStart: Date { calendar.startOfDay(for: now) }
    private var historyStart: Date {
        calendar.date(byAdding: .day, value: -(config.historyDays - 1), to: dayStart) ?? dayStart
    }
    private var sessionStart: Date {
        calendar.date(byAdding: .day, value: -(config.sessionDays - 1), to: dayStart) ?? dayStart
    }

    public init(config: Config = Config(), history: HistoryStore? = nil) {
        self.config = config
        self.history = history
    }

    public static func defaultRoots() -> [URL] {
        var r: [URL] = []
        if let env = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            for p in env.split(separator: ",") {
                r.append(URL(fileURLWithPath: String(p)).appendingPathComponent("projects"))
            }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        r.append(home.appendingPathComponent(".claude/projects"))
        r.append(home.appendingPathComponent(".config/claude/projects"))
        // Claude desktop: Cowork va Chat sessiyalari
        r.append(home.appendingPathComponent("Library/Application Support/Claude/local-agent-mode-sessions"))
        r.append(home.appendingPathComponent("Library/Application Support/Claude-3p/local-agent-mode-sessions"))
        return r
    }

    public static var primaryRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }

    public static func displayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home) ? "~" + url.path.dropFirst(home.count) : url.path
    }

    /// Ichiga kirilmaydigan katta yoki keraksiz papkalar
    private static let skipDirs: Set<String> = [
        "tool-results", "uploads", "outputs", "node_modules", "memory", ".git",
        "vm_bundles", "Cache", "Code Cache", "GPUCache", "IndexedDB", "blob_storage",
    ]

    // MARK: - Asosiy sikl

    /// Yangi fayllarni topadi (5 soniyada bir) va yangi qatorlarni o'qiydi.
    public func update(now: Date = Date()) {
        let previousDay = dayStart
        self.now = now
        if dayStart != previousDay { rollDay() }
        if now.timeIntervalSince(lastDiscovery) >= 5 {
            discover()
            lastDiscovery = now
        }
        for fs in files.values { readNew(fs) }
        initialDone = true
        if let history, now.timeIntervalSince(lastHistorySave) >= 60 {
            history.save(scanned: dayTotals, now: now, calendar: calendar)
            lastHistorySave = now
        }
    }

    public func tick(now: Date = Date()) -> Snapshot {
        update(now: now)
        return snapshot()
    }

    /// Ilova yopilayotganda — tarixni darhol saqlash
    public func flushHistory() {
        history?.save(scanned: dayTotals, now: now, calendar: calendar)
    }

    public func clearHistory() {
        history?.clear()
        revision += 1
    }

    /// Kun almashdi: hech narsa qayta o'qilmaydi, faqat eski yozuvlar tozalanadi.
    private func rollDay() {
        let minKey = HistoryStore.key(historyStart, calendar: calendar)
        dayTotals = dayTotals.filter { $0.key >= minKey }
        feed.removeAll { $0.date < dayStart }
        feedIds = Set(feed.map(\.id))
        flushHistory()
        lastDiscovery = .distantPast
        revision += 1
    }

    // MARK: - Fayllarni topish

    private func discover() {
        var infos: [SourceInfo] = []
        var seen = Set<String>()
        for (idx, root) in config.roots.enumerated() {
            var info = SourceInfo(path: Engine.displayPath(root), exists: fm.fileExists(atPath: root.path))
            info.lines = sourceLines[idx] ?? 0
            info.usage = sourceUsage[idx] ?? 0
            defer { infos.append(info) }
            guard info.exists,
                  let en = fm.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                         options: [], errorHandler: { _, _ in true }) else { continue }
            for case let url as URL in en {
                let name = url.lastPathComponent
                if Engine.skipDirs.contains(name) { en.skipDescendants(); continue }
                guard url.pathExtension == "jsonl", name != "journal.jsonl", name != "audit.jsonl" else { continue }
                let m = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                info.total += 1
                if let m, info.latest.map({ m > $0 }) ?? true { info.latest = m }
                guard let m, m >= historyStart else { continue }
                if m >= dayStart { info.today += 1 }
                info.recent += 1
                seen.insert(url.path)
                if let fs = files[url.path] {
                    fs.mtime = m
                } else {
                    let fs = FileState(url: url, rootIndex: idx)
                    fs.mtime = m
                    files[url.path] = fs
                }
            }
        }
        // O'chirilgan yoki oynadan chiqib ketgan fayllar kuzatilmaydi
        if files.count != seen.count { files = files.filter { seen.contains($0.key) } }
        sources = infos
    }

    // MARK: - O'qish

    private func readNew(_ fs: FileState) {
        guard let attrs = try? fm.attributesOfItem(atPath: fs.path),
              let size = (attrs[.size] as? NSNumber)?.uint64Value else { return }
        // Fayl qisqargan (qayta yozilgan) — boshidan; takroriy tokenlarni seenUsage to'xtatadi
        if size < fs.offset { fs.offset = 0; fs.partial = Data() }
        guard size > fs.offset, let h = FileHandle(forReadingAtPath: fs.path) else { return }
        defer { try? h.close() }
        do { try h.seek(toOffset: fs.offset) } catch { return }
        let want = Int(min(size - fs.offset, 64 * 1024 * 1024))
        guard let data = try? h.read(upToCount: want), !data.isEmpty else { return }
        fs.offset += UInt64(data.count)

        var buf = fs.partial
        buf.append(data)
        var start = buf.startIndex
        while let nl = buf[start...].firstIndex(of: 0x0A) {
            if nl > start { handleLine(buf.subdata(in: start..<nl), fs) }
            start = buf.index(after: nl)
        }
        fs.partial = buf.subdata(in: start..<buf.endIndex)
    }

    private func handleLine(_ line: Data, _ fs: FileState) {
        guard let ev = TranscriptParser.parse(line) else { return }
        revision += 1
        sourceLines[fs.rootIndex, default: 0] += 1

        let session = sessionAcc(fs.sessionId)
        // Sessiya boshqa papkaga ko'chsa — oxirgi papka nomi olinadi
        if let cwd = ev.cwd { session.project = URL(fileURLWithPath: cwd).lastPathComponent }
        if case .title(let t) = ev.kind {
            session.customTitle = t
            return
        }

        let agent = session.agent(fs.agentKey ?? ev.sidechainAgentId ?? "main")
        if !agent.isMain && !agent.metaFound && agent.metaAttempts < 30 { loadMeta(agent, fs) }

        if let ts = ev.timestamp ?? fs.mtime {
            if agent.firstActivity.map({ ts < $0 }) ?? true { agent.firstActivity = ts }
            if agent.lastActivity.map({ ts > $0 }) ?? true { agent.lastActivity = ts }
            if session.lastActivity.map({ ts > $0 }) ?? true { session.lastActivity = ts }
        }

        switch ev.kind {
        case .assistant(let a): apply(a, ev, fs, session, agent)
        case .user(let u): apply(u, ev, session, agent)
        case .title: break
        }
    }

    private func loadMeta(_ agent: AgentAcc, _ fs: FileState) {
        agent.metaAttempts += 1
        let metaPath = String(fs.path.dropLast(".jsonl".count)) + ".meta.json"
        guard let d = fm.contents(atPath: metaPath),
              let m = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { return }
        agent.metaFound = true
        if let desc = m["description"] as? String, !desc.isEmpty { agent.title = desc; agent.titled = true }
        if let t = m["agentType"] as? String, !t.isEmpty { agent.kind = t }
    }

    private func apply(_ a: TranscriptEvent.Assistant, _ ev: TranscriptEvent, _ fs: FileState,
                       _ session: SessionAcc, _ agent: AgentAcc) {
        if let m = a.model {
            agent.model = m
            if agent.isMain { session.model = m }
        }
        if let s = a.stopReason { agent.lastStop = s }

        for item in a.items {
            switch item {
            case .tool(let id, let name, let d, let target):
                guard seenTools.insert(id).inserted else { continue }
                agent.tools[ToolDescriber.shortName(name), default: 0] += 1
                let ts = ev.timestamp ?? fs.mtime ?? now
                let res = agent.resource(target)
                res.calls += 1
                if target.access == .write { res.writes += 1 } else if target.access == .read { res.reads += 1 }
                if res.lastActivity.map({ ts > $0 }) ?? true { res.lastActivity = ts }
                let step = StepAcc(id: id, start: ts, symbol: d.symbol, text: d.text, target: target, resource: res)
                agent.addStep(step)
                pendingSteps[id] = step
                agent.lastAction = d.text
                agent.lastStop = "tool_use"
                if let ts = ev.timestamp, ts >= dayStart { addFeed(id, ts, session, agent, d.symbol, d.text) }
            case .text:
                agent.lastAction = "Javob yozdi"
            case .thinking:
                agent.lastAction = "O'ylayapti"
            }
        }

        guard let c = a.usage else { return }
        if let key = a.usageKey {
            guard seenUsage.insert(key).inserted else { return }
        }
        agent.calls += 1
        agent.tokens.add(c)
        if let ts = ev.timestamp { session.usageLog.append((ts, c)) }
        sourceUsage[fs.rootIndex, default: 0] += 1
        if agent.isMain { session.context = c.input + c.cacheRead + c.cacheWrite }

        guard let ts = ev.timestamp else { return }
        if ts >= historyStart {
            dayTotals[HistoryStore.key(ts, calendar: calendar), default: TokenCounts()].add(c)
        }
        if ts >= now.addingTimeInterval(-MinuteBucket.keep) {
            let minute = Int(ts.timeIntervalSince1970 / 60)
            var b = minutes[minute] ?? MinuteBucket()
            if agent.isMain { b.main.add(c) } else { b.agents.add(c) }
            minutes[minute] = b
        }
    }

    private func apply(_ u: TranscriptEvent.User, _ ev: TranscriptEvent, _ session: SessionAcc, _ agent: AgentAcc) {
        if u.hasToolResult { agent.lastStop = "tool_result" }
        for r in u.results {
            guard let step = pendingSteps.removeValue(forKey: r.id) else { continue }
            step.end = ev.timestamp ?? now
            if r.isError {
                step.failed = true
                step.resource.errors += 1
            }
        }
        guard let first = u.prompts.first else { return }
        let firstLine = String(first.split(separator: "\n").first ?? Substring(first))
        agent.lastStop = "prompt"
        if agent.isMain {
            if session.firstPrompt.isEmpty { session.firstPrompt = String(firstLine.prefix(90)) }
            if let ts = ev.timestamp { session.addTurn(start: ts, prompt: String(firstLine.prefix(160))) }
            agent.lastAction = "Yangi so'rov oldi"
            if let ts = ev.timestamp, ts >= dayStart {
                addFeed(ev.uuid ?? UUID().uuidString, ts, session, agent, "person.fill",
                        "Siz: " + String(firstLine.prefix(120)))
            }
        } else if !agent.titled {
            agent.title = String(firstLine.prefix(70))
            agent.titled = true
        }
    }

    private func addFeed(_ id: String, _ ts: Date, _ s: SessionAcc, _ a: AgentAcc, _ sym: String, _ text: String) {
        guard feedIds.insert(id).inserted else { return }
        feed.append(FeedEvent(id: id, date: ts, sessionId: s.id, project: s.displayProject,
                              agentTitle: a.isMain ? "Asosiy" : a.title, isMain: a.isMain, symbol: sym, text: text))
        if feed.count > 800 {
            feed.sort { $0.date < $1.date }
            let drop = feed.prefix(feed.count - 500)
            for e in drop { feedIds.remove(e.id) }
            feed.removeFirst(drop.count)
        }
    }

    // MARK: - Holat

    /// Agent oxirgi 15 soniyada yozgan bo'lsa — ishlayapti. Aks holda oxirgi qadamga qarab:
    /// asbob natijasi yoki so'rov kelgan — model o'ylayapti; asbob chaqirilgan — natija kutyapti.
    static func state(lastActivity: Date?, lastStop: String?, now: Date) -> AgentState {
        guard let la = lastActivity else { return .idle }
        let d = now.timeIntervalSince(la)
        if d < 15 { return .running }
        switch lastStop {
        case "tool_result", "prompt": return d < 300 ? .running : .idle
        case "tool_use": return d < 600 ? .waiting : .idle
        default: return .idle
        }
    }

    // MARK: - Snapshot

    public func snapshot() -> Snapshot {
        var snap = Snapshot()
        snap.updatedAt = now
        snap.initialScanDone = initialDone
        snap.filesWatched = files.count
        snap.sources = sources

        var sessSnaps: [SessionSnap] = []
        for s in sessions.values {
            guard let la = s.lastActivity else { continue }
            let starts = s.turns.map(\.start)
            var main = TokenCounts(), sub = TokenCounts()
            var agentSnaps: [AgentSnap] = []
            var best = AgentState.idle
            for a in s.agents.values {
                if a.isMain { main.add(a.tokens) } else { sub.add(a.tokens) }
                let st = Engine.state(lastActivity: a.lastActivity, lastStop: a.lastStop, now: now)
                best = max(best, st)
                if st == .running { snap.runningAgents += 1 }
                agentSnaps.append(AgentSnap(
                    id: s.id + "/" + a.key, title: a.title,
                    subtitle: a.isMain ? Fmt.model(a.model) : a.kind, kind: a.kind,
                    isMain: a.isMain, tokens: a.tokens, calls: a.calls,
                    topTools: a.tools.sorted { $0.value > $1.value }.map { (name: $0.key, count: $0.value) },
                    lastAction: a.lastAction.isEmpty ? "—" : a.lastAction,
                    state: st, lastActivity: a.lastActivity, firstActivity: a.firstActivity,
                    steps: a.steps.suffix(150).map { $0.snap(now: now, turn: Engine.turnIndex(starts, $0.start)) },
                    resources: a.resourceGroups(now: now)))
            }
            if best != .idle { snap.activeSessions += 1 }
            // Ishlayotgan sessiya eski bo'lsa ham ko'rinadi
            guard la >= sessionStart || best != .idle else { continue }
            // Barqaror tartib: asosiy agent tepada, keyin eng oxirgi ishga tushgan yordamchi
            agentSnaps.sort {
                if $0.isMain != $1.isMain { return $0.isMain }
                return ($0.firstActivity ?? .distantPast) > ($1.firstActivity ?? .distantPast)
            }
            sessSnaps.append(SessionSnap(
                id: s.id, project: s.displayProject, title: s.displayTitle,
                model: Fmt.model(s.model), contextTokens: s.context,
                tokens: main + sub, mainTokens: main, agentTokens: sub,
                agents: agentSnaps, lastActivity: la, state: best,
                turns: turnSnaps(s, starts: starts, active: best != .idle)))
        }
        sessSnaps.sort { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
        snap.sessions = sessSnaps

        // Minutlar: grafik uchun 60 ta nuqta, tezlik — oxirgi 5 daqiqa, limit — oxirgi 5 soat
        let nowMin = Int(now.timeIntervalSince1970 / 60)
        snap.minutes = ((nowMin - 59)...nowMin).map { m in
            let b = minutes[m] ?? MinuteBucket()
            return MinutePoint(id: m, date: Date(timeIntervalSince1970: TimeInterval(m * 60)), main: b.main, agents: b.agents)
        }
        let last5 = snap.minutes.suffix(5)
        snap.rateRaw = last5.reduce(0) { $0 + Double($1.main.total + $1.agents.total) } / 5
        snap.rateWeighted = last5.reduce(0) { $0 + $1.main.weighted + $1.agents.weighted } / 5
        let fiveHoursAgo = nowMin - 5 * 60
        for (m, b) in minutes where m > fiveHoursAgo {
            snap.lastFiveHours.add(b.main)
            snap.lastFiveHours.add(b.agents)
        }
        if minutes.count > Int(MinuteBucket.keep / 60) + 60 {
            let cutoff = nowMin - Int(MinuteBucket.keep / 60)
            minutes = minutes.filter { $0.key >= cutoff }
        }

        // Kunlar: transcript + saqlangan tarix
        let allDays = history?.merged(with: dayTotals) ?? dayTotals
        snap.days = (0..<config.historyDays).reversed().compactMap { back -> DayPoint? in
            guard let d = calendar.date(byAdding: .day, value: -back, to: dayStart) else { return nil }
            return DayPoint(date: d, tokens: allDays[HistoryStore.key(d, calendar: calendar)] ?? TokenCounts())
        }
        snap.today = dayTotals[HistoryStore.key(now, calendar: calendar)] ?? TokenCounts()

        snap.feed = Array(feed.sorted { $0.date > $1.date }.prefix(200))
        return snap
    }

    /// Butun saqlangan tarix (CSV eksport uchun), eskidan yangiga
    public func allHistory() -> [DayPoint] {
        let all = history?.merged(with: dayTotals) ?? dayTotals
        return all.compactMap { k, v in
            HistoryStore.date(fromKey: k, calendar: calendar).map { DayPoint(date: $0, tokens: v) }
        }
        .sorted { $0.date < $1.date }
    }

    /// So'rovlar oralig'i bo'yicha tokenlar, qadamlar va xatolar
    private func turnSnaps(_ s: SessionAcc, starts: [Date], active: Bool) -> [TurnSnap] {
        guard !s.turns.isEmpty else { return [] }
        var tokens = Array(repeating: TokenCounts(), count: s.turns.count)
        var steps = Array(repeating: 0, count: s.turns.count)
        var errors = Array(repeating: 0, count: s.turns.count)
        var ends = s.turns.map(\.start)
        for (ts, c) in s.usageLog {
            guard let i = Engine.turnIndex(starts, ts) else { continue }
            tokens[i].add(c)
            ends[i] = max(ends[i], ts)
        }
        for a in s.agents.values {
            for st in a.steps {
                guard let i = Engine.turnIndex(starts, st.start) else { continue }
                steps[i] += 1
                if st.failed { errors[i] += 1 }
                ends[i] = max(ends[i], st.end ?? st.start)
            }
        }
        return s.turns.indices.map { i in
            TurnSnap(id: i + 1, prompt: s.turns[i].prompt, start: s.turns[i].start, end: ends[i],
                     tokens: tokens[i], steps: steps[i], errors: errors[i],
                     active: active && i == s.turns.count - 1)
        }
    }

    /// `ts` qaysi so'rovga tegishli: boshlanishi `ts` dan oldin bo'lgan oxirgi so'rov
    static func turnIndex(_ starts: [Date], _ ts: Date) -> Int? {
        var lo = 0, hi = starts.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if starts[mid] <= ts { lo = mid + 1 } else { hi = mid }
        }
        return lo == 0 ? nil : lo - 1
    }

    private func sessionAcc(_ id: String) -> SessionAcc {
        if let s = sessions[id] { return s }
        let s = SessionAcc(id: id)
        sessions[id] = s
        return s
    }
}

// MARK: - Ichki holat

private struct MinuteBucket {
    /// Minut yozuvlari 24 soat saqlanadi
    static let keep: TimeInterval = 24 * 3600
    var main = TokenCounts()
    var agents = TokenCounts()
}

private final class FileState {
    let path: String
    let sessionId: String
    /// nil — asosiy sessiya fayli
    let agentKey: String?
    let rootIndex: Int
    var offset: UInt64 = 0
    var partial = Data()
    var mtime: Date?

    init(url: URL, rootIndex: Int) {
        path = url.path
        self.rootIndex = rootIndex
        let comps = url.pathComponents
        if let i = comps.lastIndex(of: "subagents"), i >= 1 {
            var key = url.deletingPathExtension().lastPathComponent
            if key.hasPrefix("agent-") { key.removeFirst(6) }
            sessionId = comps[i - 1]
            agentKey = key
        } else {
            sessionId = url.deletingPathExtension().lastPathComponent
            agentKey = nil
        }
    }
}

private final class AgentAcc {
    let key: String
    let isMain: Bool
    var title: String
    var kind = ""
    var titled = false
    var tokens = TokenCounts()
    var calls = 0
    var tools: [String: Int] = [:]
    var lastActivity: Date?
    var firstActivity: Date?
    var lastAction = ""
    var lastStop: String?
    var model = ""
    var metaFound = false
    var metaAttempts = 0
    var steps: [StepAcc] = []
    var resources: [String: ResourceAcc] = [:]

    func resource(_ t: ToolTarget) -> ResourceAcc {
        if let r = resources[t.key] { return r }
        let r = ResourceAcc(target: t)
        resources[t.key] = r
        return r
    }

    func addStep(_ s: StepAcc) {
        steps.append(s)
        if steps.count > 300 { steps.removeFirst(steps.count - 200) }
    }

    func resourceGroups(now: Date) -> [ResourceGroup] {
        let busyKeys = Set(steps.suffix(20).filter { $0.end == nil && now.timeIntervalSince($0.start) < 600 }
            .map { $0.resource.target.key })
        let byCat = Dictionary(grouping: resources.values, by: { $0.target.category })
        return byCat.map { cat, list -> ResourceGroup in
            let items = list.sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
            return ResourceGroup(
                category: cat,
                calls: list.reduce(0) { $0 + $1.calls },
                errors: list.reduce(0) { $0 + $1.errors },
                lastActivity: items.first?.lastActivity,
                items: items.map {
                    ResourceItem(id: $0.target.key, name: $0.target.name, detail: $0.target.detail,
                                 calls: $0.calls, reads: $0.reads, writes: $0.writes, errors: $0.errors,
                                 lastActivity: $0.lastActivity)
                },
                busy: list.contains { busyKeys.contains($0.target.key) })
        }
        .sorted { ($0.lastActivity ?? .distantPast) > ($1.lastActivity ?? .distantPast) }
    }

    init(key: String) {
        self.key = key
        isMain = key == "main"
        title = isMain ? "Asosiy agent" : "Yordamchi agent"
    }
}

private final class ResourceAcc {
    let target: ToolTarget
    var calls = 0
    var reads = 0
    var writes = 0
    var errors = 0
    var lastActivity: Date?

    init(target: ToolTarget) { self.target = target }
}

private final class StepAcc {
    let id: String
    let start: Date
    let symbol: String
    let text: String
    let target: ToolTarget
    let resource: ResourceAcc
    var end: Date?
    var failed = false

    init(id: String, start: Date, symbol: String, text: String, target: ToolTarget, resource: ResourceAcc) {
        self.id = id
        self.start = start
        self.symbol = symbol
        self.text = text
        self.target = target
        self.resource = resource
    }

    /// Natija 10 daqiqada kelmasa — tugagan deb hisoblanadi (sessiya uzilgan bo'lishi mumkin)
    func snap(now: Date, turn: Int?) -> StepSnap {
        let status: StepStatus = failed ? .failed : (end == nil && now.timeIntervalSince(start) < 600 ? .running : .done)
        let duration = end.map { $0.timeIntervalSince(start) } ?? (status == .running ? now.timeIntervalSince(start) : nil)
        return StepSnap(id: id, date: start, symbol: symbol, text: text, category: target.category,
                        targetName: target.name, targetKey: target.key, targetDetail: target.detail, access: target.access, duration: duration, status: status, turn: turn.map { $0 + 1 })
    }
}

private final class SessionAcc {
    let id: String
    var project = ""
    var customTitle = ""
    var firstPrompt = ""
    var model = ""
    var context = 0
    var agents: [String: AgentAcc] = [:]
    var lastActivity: Date?
    /// So'rovlar, boshlanish vaqti bo'yicha tartiblangan
    var turns: [(start: Date, prompt: String)] = []
    /// Har bir sanalgan javob: vaqti va tokenlari (so'rovlar bo'yicha taqsimlash uchun)
    var usageLog: [(Date, TokenCounts)] = []

    init(id: String) { self.id = id }

    func addTurn(start: Date, prompt: String) {
        // Bir xil so'rov qayta o'qilsa (fayl qayta yozilgan) — takrorlanmaydi
        guard !turns.contains(where: { $0.start == start }) else { return }
        let i = turns.firstIndex { $0.start > start } ?? turns.count
        turns.insert((start: start, prompt: prompt), at: i)
    }

    var displayProject: String { project.isEmpty ? String(id.prefix(8)) : project }
    var displayTitle: String {
        if !customTitle.isEmpty { return customTitle }
        return firstPrompt.isEmpty ? "Nomsiz sessiya" : firstPrompt
    }

    func agent(_ key: String) -> AgentAcc {
        if let a = agents[key] { return a }
        let a = AgentAcc(key: key)
        agents[key] = a
        return a
    }
}
