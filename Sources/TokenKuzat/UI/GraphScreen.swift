import SwiftUI
import AppKit
import Combine
import TokenKuzatCore

// Agentlar sxemasi: chapda n8n uslubidagi jarayon oqimi (FlowCanvas), o'ngda tanlangan tugun tafsiloti —
// so'rovlar bo'yicha jarayon lentasi (har bir qadam, davomiyligi, natijasi) va resurslar ro'yxati.

extension ToolCategory {
    var color: Color {
        switch self {
        case .files: return Color(light: 0x0E9F8E, dark: 0x16B3A0)
        case .shell: return Color(light: 0x18181B, dark: 0x4A4A52)
        case .web: return Color(light: 0x2F7BE5, dark: 0x4A8FF0)
        case .mcp: return Color(light: 0xE0731C, dark: 0xEC8432)
        case .agent: return Brand.accent
        case .other: return Color(light: 0x8A8A93, dark: 0x6E6E76)
        }
    }
}

/// Inspektorda nima ko'rsatiladi
private enum Selection: Equatable {
    case agent(String)
    case resource(agentId: String, category: ToolCategory)
    /// O'ylash yoki javob matni
    case note(agentId: String, noteId: String)
    /// Bitta qadam: kirish, chiqish va tafsilot (n8n'dagi node bajarilishi kabi)
    case step(agentId: String, stepId: String)

    var agentId: String {
        switch self {
        case .agent(let id), .resource(let id, _), .note(let id, _), .step(let id, _): return id
        }
    }
}

// MARK: - Ekran

struct GraphScreen: View {
    static let selectedSessionKey = "graphSession"
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""
    @AppStorage("graphInspector") private var showInspector = true
    /// Tor oynada tafsilotlar paneli xarita ustida ochiladi (sukut bo'yicha yopiq) — xarita siqilmaydi
    @State private var narrowInspector = false
    @AppStorage(Pref.mapOnly) private var mapOnly = false
    /// «Faqat xarita» (Xulosa tabida — «Faqat sxema»): sarlavha, vaqt chizig'i, tablar va panel yashiriladi
    private var mapFocus: Bool { mapOnly && ["map", "summary"].contains(currentTab) }
    @State private var contentWidth: CGFloat = 1200
    private var isNarrow: Bool { contentWidth < 1000 }
    private var inspectorVisible: Bool { isNarrow ? narrowInspector : showInspector }
    /// Tafsilotlar paneli Xarita va Xulosa tablarida bor («Faqat xarita»da yo'q)
    private var panelAvailable: Bool { !mapFocus && ["map", "summary"].contains(currentTab) }
    /// «flow» — n8n oqimi, «timeline» — vaqt chizig'i
    @AppStorage("graphMode") private var graphMode = "flow"
    @State private var selection: Selection?
    /// nil — eng so'nggi so'rov (yangisi kelsa o'zi o'tadi), 0 — butun sessiya
    @State private var turnId: Int?
    /// Replay: nil — jonli holat
    @State private var replayTime: Date?
    @State private var replayOn = false
    @State private var playing = false
    @State private var speed = 20.0
    /// Oqim tabida: «process» — ketma-ket jarayon, «summary» — asboblar xulosasi
    @AppStorage("flowStyle") private var flowStyle = "map"
    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = store.snap
        let live = s.sessions.first(where: { $0.id == sessionId }) ?? s.sessions.first
        let range = live.flatMap { replayRange($0) }
        // Replay paytida hamma ko'rinish sessiyaning o'sha paytdagi holatini oladi
        let session = live.map { l in replayOn ? l.replay(at: replayTime ?? range?.upperBound ?? s.updatedAt) : l }
        let now = replayOn ? (replayTime ?? range?.upperBound ?? s.updatedAt) : s.updatedAt
        // Sahifa aylantirilmaydi: kanvas oynaning qolgan balandligini to'liq egallaydi.
        // O'ngda — to'liq balandlikdagi tafsilotlar paneli (yon menyu bilan bir uslubda)
        HStack(spacing: 0) {
        VStack(spacing: 0) {
            if let session, let live {
                let turnNo = effectiveTurn(session)
                let turn = turnNo.flatMap { n in session.turns.first { $0.id == n } }
                let flow = FlowModel(session: session, turnId: turnNo, now: now)
                let tl = TimelineModel(flow: flow, session: session, turnId: turnNo, now: now)
                if !mapFocus {
                    SessionHeader(session: session, turn: turn, mode: mode, costUSD: s.limits?.costBySession[session.id],
                                  waiting: replayOn ? nil : s.permissionWaits[session.id])
                    LanesCard(timeline: tl, replayOn: replayOn) { toggleReplay(live) }
                        .padding(.top, 14)
                }
                if replayOn, let range {
                    ReplayBar(range: range,
                              steps: live.agents.flatMap(\.steps).filter { range.contains($0.date) },
                              time: Binding(get: { replayTime }, set: { t in
                                  if t == nil { replayOn = false }
                                  replayTime = t
                              }),
                              playing: $playing, speed: $speed)
                        .padding(.horizontal, 14)
                }
                if !mapFocus { tabs.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10) }
                // «Qadamlar» tabi olib tashlandi — eski saqlangan qiymat ham Oqim'ni ochadi
                switch ["files", "outputs"].contains(graphMode) ? graphMode : "flow" {
                // «Jarayon» ko'rinishi olib tashlandi — eski saqlangan qiymat xaritani ochadi
                case "flow" where flowStyle != "summary":
                    let chain = SessionChain.chain(for: session, in: replayOn ? [session] : s.sessions)
                    HStack(spacing: 0) {
                        SessionMapView(chain: replayOn ? [session] : chain.map { $0.id == session.id ? session : $0 },
                                       mode: mode,
                                       selectedTurn: turnNo.map { "\(session.id)#\($0)" },
                                       steps: mapSteps(session, turn: turnNo ?? session.turns.last?.id),
                                       waiting: replayOn ? nil : chain.last.flatMap { s.permissionWaits[$0.id] },
                                       onSelectTurn: { sid, tid in
                                           if sid != sessionId { sessionId = sid }
                                           DispatchQueue.main.async { turnId = tid }
                                       },
                                       onSelectTool: { sid, tid, cat in
                                           if sid != sessionId { sessionId = sid }
                                           DispatchQueue.main.async {
                                               turnId = tid
                                               if let m = s.sessions.first(where: { $0.id == sid })?.main {
                                                   select(.resource(agentId: m.id, category: cat))
                                               }
                                           }
                                       },
                                       onSelectStep: { sid, step in
                                           if sid != sessionId { sessionId = sid }
                                           DispatchQueue.main.async {
                                               if let tid = step.turn { turnId = tid }
                                               if let a = s.sessions.first(where: { $0.id == sid })?.agents
                                                   .first(where: { $0.steps.contains { $0.id == step.id } }) {
                                                   selection = .step(agentId: a.id, stepId: step.id)
                                                   revealInspector()
                                               }
                                           }
                                       },
                                       onSelectNote: { sid, note in
                                           if sid != sessionId { sessionId = sid }
                                           DispatchQueue.main.async {
                                               if let tid = note.turn { turnId = tid }
                                               if let m = s.sessions.first(where: { $0.id == sid })?.main {
                                                   selection = .note(agentId: m.id, noteId: note.id)
                                                   revealInspector()
                                               }
                                           }
                                       },
                                       interactive: !replayOn)
                    }
                    .frame(minHeight: 320, maxHeight: .infinity)
                    .card(padding: 0)
                    // Faqat xaritada — oyna chetlarigacha, tepada ham (oyna tugmalari xarita ustida turadi)
                    .padding(.horizontal, mapFocus ? 6 : 24).padding(.bottom, mapFocus ? 6 : 20)
                    .padding(.top, mapFocus ? 6 : 0)
                    .ignoresSafeArea(.container, edges: mapFocus ? .top : [])
                case "flow":
                    HStack(spacing: 0) {
                        FlowCanvas(session: session, model: flow, mode: mode,
                                   selectedAgent: currentSelection(session)?.agentId,
                                   selectedBubble: selectedBubbleId(session),
                                   onSelectAgent: { select(.agent($0)) },
                                   onSelectBubble: { b in
                                       if let c = b.category { select(.resource(agentId: b.ownerId, category: c)) }
                                       else { select(.agent(b.ownerId)) }
                                   })
                    }
                    .frame(minHeight: 320, maxHeight: .infinity)
                    .card(padding: 0)
                    .padding(.horizontal, 24).padding(.bottom, 20)
                case "files":
                    FileHeatmapScreen(model: HeatmapModel(timeline: tl)) { f in
                        if let owner = f.ownerId { select(.resource(agentId: owner, category: .files)) }
                    }
                    .frame(minHeight: 320, maxHeight: .infinity)
                    .card(padding: 0)
                    .padding(.horizontal, 24).padding(.bottom, 20)
                case "outputs":
                    OutputsScreen(session: session)
                        .frame(minHeight: 320, maxHeight: .infinity)
                        .card(padding: 0)
                        .padding(.horizontal, 24).padding(.bottom, 20)
                default:
                    EmptyView()
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(symbol: "rectangle.stack",
                                       title: tr("Sessiya yo'q", "No sessions"),
                                       text: tr("Mac'da Claude Code yoki Cowork'da ish boshlansa, jarayon shu yerda qadamma-qadam chiqadi.", "When work starts in Claude Code or Cowork on this Mac, the process shows up here step by step."))
                        SourcesList(sources: s.sources).card()
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            if let session, panelAvailable && !isNarrow && showInspector {
                DetailsPanel(onClose: { withAnimation(Motion.spring) { showInspector = false } }) {
                    inspector(session, now: now)
                }
                .frame(width: min(360, max(300, contentWidth * 0.26)))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) { if let session { narrowPanel(session, now: now) } }
        .overlay(alignment: .topTrailing) {
            // Panel yopiq — oynaning yuqori o'ng burchagida ochish tugmasi (chap menyudagidek)
            if panelAvailable && !inspectorVisible {
                PaneToggle(symbol: "sidebar.right", help: tr("Tafsilotlarni ko'rsatish", "Show details")) {
                    withAnimation(Motion.spring) { if isNarrow { narrowInspector = true } else { showInspector = true } }
                }
                .padding(.top, 2).padding(.trailing, 8)
                .ignoresSafeArea(.container, edges: .top)
                .transition(.opacity)
            }
        }
        .animation(Motion.spring, value: showInspector)
        .background(GeometryReader { g in
            Color.clear
                .onAppear { contentWidth = g.size.width }
                .onChange(of: g.size.width) { contentWidth = $0 }
        })
        .animation(Motion.spring, value: replayOn)
        .animation(Motion.spring, value: narrowInspector)
        .animation(Motion.spring, value: mapFocus)
        .animation(Motion.spring, value: graphMode)
        .onAppear { if !["map", "summary"].contains(flowStyle) { flowStyle = "map" } }
        .onChange(of: sessionId) { _ in selection = nil; turnId = nil; stopReplay() }
        .onChange(of: turnId) { _ in if replayOn { replayTime = live.flatMap { replayRange($0) }?.lowerBound } }
        .onReceive(ticker) { _ in
            guard replayOn, playing, let range else { return }
            let next = (replayTime ?? range.lowerBound).addingTimeInterval(0.1 * speed)
            if next >= range.upperBound {
                replayTime = range.upperBound
                playing = false
            } else {
                replayTime = next
            }
        }
    }

    // MARK: Tablar

    /// Teng tablar: Xarita, Xulosa (ikkalasi Oqim'ning ko'rinishlari), Fayllar va Natijalar
    private var tabs: some View {
        HStack(spacing: 4) {
            tab("map", tr("Xarita", "Map"), "point.3.connected.trianglepath.dotted",
                help: tr("Butun sessiya: so'rovlar, asboblar va qadamlar zanjiri", "The whole session: chain of prompts, tools and steps"))
            tab("summary", tr("Xulosa", "Summary"), "circle.hexagongrid",
                help: tr("Tanlangan so'rovda qaysi agent va asboblar ishlatilgani", "Which agents and tools the selected prompt used"))
            tab("files", tr("Fayllar", "Files"), "square.grid.3x3", help: tr("Qaysi fayllar o'qildi va o'zgartirildi", "Which files were read and changed"))
            tab("outputs", tr("Natijalar", "Outputs"), "photo.on.rectangle.angled",
                help: tr("Jarayonda yaratilgan yoki ko'rilgan rasm, HTML, PDF va videolar", "Images, HTML, PDFs and videos created or viewed during the process"))
            Spacer()
        }
    }

    private var currentTab: String {
        ["files", "outputs"].contains(graphMode) ? graphMode : (flowStyle == "summary" ? "summary" : "map")
    }

    private func tab(_ id: String, _ title: String, _ symbol: String, help: String) -> some View {
        let on = currentTab == id
        return Button {
            withAnimation(Motion.spring) {
                if ["files", "outputs"].contains(id) { graphMode = id } else { graphMode = "flow"; flowStyle = id }
            }
        } label: {
            Label(title, systemImage: symbol)
                .font(.callout.weight(on ? .semibold : .regular))
                .foregroundStyle(on ? .primary : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? Brand.surface : .clear))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(on ? Brand.line : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toggleReplay(_ session: SessionSnap) {
        if replayOn { stopReplay() } else {
            replayOn = true
            replayTime = replayRange(session)?.lowerBound
            playing = true
        }
    }

    /// Replay oralig'i: tanlangan so'rov (keyingisigacha) yoki butun sessiya
    private func replayRange(_ session: SessionSnap) -> ClosedRange<Date>? {
        guard let id = effectiveTurn(session), let t = session.turns.first(where: { $0.id == id }) else {
            return session.timeRange
        }
        let next = session.turns.first { $0.id == id + 1 }?.start
        let end = max(t.end, t.start.addingTimeInterval(5))
        return t.start...min(end, next ?? end)
    }

    private func stopReplay() {
        replayOn = false
        playing = false
        replayTime = nil
    }

    /// Xaritada ochiladigan so'rov zanjiri: barcha agentlardagi qadamlar, o'ylash va javoblar — vaqt bo'yicha.
    /// Model hozir o'ylayotgan bo'lsa (asbob ishlamayapti) — oxirida «O'ylayapti…»
    private func mapSteps(_ session: SessionSnap, turn: Int?) -> [MapStep] {
        guard let turn else { return [] }
        var out: [MapStep] = session.agents.flatMap { a in
            a.steps.filter { $0.turn == turn }.map { MapStep(step: $0, agent: a.isMain ? nil : a.title) }
        }
        // Matnsiz (shifrlangan) o'ylashlar ko'rsatilmaydi — ular faqat «matn yashirin» deb turadi
        let notes = session.notes.filter { n in n.turn == turn && !(n.kind == .thinking && n.text.isEmpty) }
        // Yakuniy javob — faqat so'rov tugagach; ish davom etayotganda hammasi oraliq «Xabar»
        let active = session.turns.first { $0.id == turn }?.active == true
        let lastReply = active ? nil : notes.last { $0.kind == .reply && $0.agent == nil }?.id
        out += notes.map { MapStep(note: $0, final: $0.id == lastReply) }
        out.sort { (a: MapStep, b: MapStep) in a.date < b.date }
        out = Self.grouped(out)
        if let t = session.turns.first(where: { $0.id == turn }), t.active, session.state == .running,
           !out.contains(where: \.isLive) {
            out.append(MapStep(liveSince: out.last?.date ?? t.start))
        }
        return out
    }

    /// Ikki o'ylash/xabar orasidagi (bir agentdagi) barcha asbob qadamlari bitta «5 ta qadam» bo'g'iniga yig'iladi
    private static func grouped(_ items: [MapStep]) -> [MapStep] {
        var out: [MapStep] = []
        var run: [StepSnap] = []
        var runAgent: String?
        func flush() {
            if run.count == 1 { out.append(MapStep(step: run[0], agent: runAgent)) }
            else if run.count > 1 { out.append(MapStep(group: run, agent: runAgent)) }
            run = []
        }
        for it in items {
            if case .step(let s) = it.item {
                if !run.isEmpty, runAgent != it.agent { flush() }
                runAgent = it.agent
                run.append(s)
            } else {
                flush()
                out.append(it)
            }
        }
        flush()
        return out
    }

    /// Tanlangan so'rov raqami; nil — butun sessiya
    private func effectiveTurn(_ session: SessionSnap) -> Int? {
        switch turnId {
        case 0?: return nil
        case let id? where session.turns.contains(where: { $0.id == id }): return id
        default: return session.turns.last?.id
        }
    }

    private func revealInspector() {
        if isNarrow { narrowInspector = true } else if !showInspector { showInspector = true }
    }

    /// Tor oynada: tafsilotlar xarita ustida, o'ng tomonda suzib turadi
    @ViewBuilder
    private func narrowPanel(_ session: SessionSnap, now: Date) -> some View {
        if panelAvailable && isNarrow && narrowInspector {
            DetailsPanel(onClose: { withAnimation(Motion.spring) { narrowInspector = false } }) {
                inspector(session, now: now)
            }
            .frame(width: min(340, contentWidth * 0.8))
            .shadow(color: .black.opacity(0.35), radius: 18, x: -6)
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }

    private func select(_ s: Selection) {
        selection = selection == s ? nil : s
        revealInspector()
    }

    /// Hech narsa tanlanmagan bo'lsa — asosiy agent
    private func currentSelection(_ session: SessionSnap) -> Selection? {
        if let selection, session.agents.contains(where: { $0.id == selection.agentId }) { return selection }
        return session.main.map { .agent($0.id) }
    }

    private func selectedBubbleId(_ session: SessionSnap) -> String? {
        if case .resource(let id, let c)? = currentSelection(session) { return id + "#" + c.rawValue }
        return nil
    }

    // MARK: Inspektor

    @ViewBuilder
    private func inspector(_ session: SessionSnap, now: Date) -> some View {
        switch currentSelection(session) {
        case .agent(let id)?:
            if let a = session.agents.first(where: { $0.id == id }) {
                AgentInspector(agent: a, turns: session.turns, sessionTotal: session.tokens.value(mode), mode: mode,
                               openStep: { selection = .step(agentId: a.id, stepId: $0.id) }) { cat in
                    select(.resource(agentId: a.id, category: cat))
                }
            }
        case .resource(let id, let cat)?:
            if let a = session.agents.first(where: { $0.id == id }), let g = a.resources.first(where: { $0.category == cat }) {
                ResourceInspector(owner: a, group: g, now: now,
                                  openStep: { selection = .step(agentId: a.id, stepId: $0.id) }) { select(.agent(a.id)) }
            } else {
                EmptyStateView(symbol: "questionmark", title: tr("Topilmadi", "Not found"), text: "")
            }
        case .note(let aid, let nid)?:
            if let n = session.notes.first(where: { $0.id == nid }) {
                NoteInspector(note: n, final: session.turns.first { $0.id == n.turn }?.active != true
                              && session.notes.last { $0.kind == .reply && $0.turn == n.turn && $0.agent == nil }?.id == n.id) {
                    select(.agent(aid))
                }
            } else {
                EmptyStateView(symbol: "questionmark", title: tr("Topilmadi", "Not found"), text: "")
            }
        case .step(let aid, let sid)?:
            if let a = session.agents.first(where: { $0.id == aid }), let st = a.steps.first(where: { $0.id == sid }) {
                StepInspector(step: st, agent: a) { select(.agent(aid)) }
                    .id(sid)
            } else {
                EmptyStateView(symbol: "questionmark", title: tr("Qadam topilmadi", "Step not found"),
                               text: tr("Juda eski qadamlar xotirada saqlanmaydi.", "Very old steps aren't kept in memory."))
            }
        case nil:
            EmptyStateView(symbol: "cursorarrow.click", title: tr("Tugunni tanlang", "Select a node"),
                           text: tr("Agent yoki asbob tugunini bosing — jarayon shu yerda chiqadi.", "Click an agent or tool node — its process shows up here."))
        }
    }
}

/// O'qish, yozish, ishga tushirish va xatolar soni
private struct AccessBadges: View {
    let item: ResourceItem

    var body: some View {
        let runs = item.calls - item.reads - item.writes
        HStack(spacing: 6) {
            if item.reads > 0 { badge("eye", item.reads, .secondary, tr("o'qildi", "read")) }
            if item.writes > 0 { badge("pencil", item.writes, .orange, tr("o'zgartirildi", "changed")) }
            if runs > 0 { badge("play.fill", runs, .secondary, tr("chaqirildi", "run")) }
            if item.errors > 0 { badge("exclamationmark.triangle.fill", item.errors, .red, tr("xato", "error")) }
        }
    }

    private func badge(_ symbol: String, _ n: Int, _ color: Color, _ help: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 8, weight: .semibold))
            Text("\(n)").font(.caption2).monospacedDigit()
        }
        .foregroundStyle(color)
        .help(tr("\(n) marta \(help)", "\(help) \(n)×"))
    }
}

// MARK: - Inspektorlar

private enum Dur {
    static func text(_ s: TimeInterval?) -> String {
        guard let s else { return "" }
        if s < 1 { return "<1 s" }
        if s < 60 { return "\(Int(s)) s" }
        return tr("\(Int(s) / 60) daq \(Int(s) % 60) s", "\(Int(s) / 60) min \(Int(s) % 60) s")
    }
}

/// Bo'lim: sarlavha (oddiy yozuv, kattaroq) va ichidagi karta
private struct InspectorBlock<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var card = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                if let trailing { Text(trailing).font(.caption).foregroundStyle(.secondary).monospacedDigit() }
            }
            .padding(.horizontal, 2)
            if card {
                content
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .surface(radius: 14)
            } else {
                content
            }
        }
    }
}

/// Holat yorlig'i: nuqta va matn kapsulada
private struct StatePill: View {
    let state: AgentState

    var body: some View {
        let color: Color = state == .idle ? .secondary : (state == .running ? Brand.ok : Brand.warn)
        HStack(spacing: 6) {
            StateDot(state: state, size: 7)
            Text(state == .idle ? tr("Tugagan", "Done") : state.title)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

private struct AgentInspector: View {
    let agent: AgentSnap
    let turns: [TurnSnap]
    let sessionTotal: Double
    let mode: CountMode
    var openStep: (StepSnap) -> Void = { _ in }
    let openResource: (ToolCategory) -> Void

    private var trailing: String? {
        let n = agent.isMain ? turns.count : Set(agent.steps.compactMap(\.turn)).count
        guard n > 0 || !agent.steps.isEmpty else { return nil }
        return tr("\(n) so'rov · \(agent.steps.count) qadam", "\(n) \(n == 1 ? "prompt" : "prompts") · \(agent.steps.count) \(agent.steps.count == 1 ? "step" : "steps")")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                InspectorBlock(title: tr("Hozir", "Now")) { now }
                InspectorBlock(title: tr("Tokenlar", "Tokens"), trailing: tr("\(agent.calls) API chaqiruv", "\(agent.calls) API \(agent.calls == 1 ? "call" : "calls")")) {
                    TokenBreakdown(tokens: agent.tokens, mode: mode, sessionTotal: sessionTotal)
                }
                if !agent.resources.isEmpty {
                    InspectorBlock(title: tr("Nimalarga kirdi", "What it accessed"), trailing: tr("\(agent.resources.reduce(0) { $0 + $1.calls }) chaqiruv", "\(agent.resources.reduce(0) { $0 + $1.calls }) calls")) {
                        ResourceList(groups: agent.resources, open: openResource)
                    }
                }
                InspectorBlock(title: tr("Jarayon", "Process"), trailing: trailing, card: false) {
                    if agent.steps.isEmpty && (!agent.isMain || turns.isEmpty) {
                        Text(tr("Hali asbob chaqirilmagan.", "No tools called yet.")).font(.callout).foregroundStyle(.secondary)
                    } else {
                        TurnTimeline(steps: agent.steps, turns: turns, showEmptyTurns: agent.isMain, mode: mode, onStep: openStep)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ToolTile(symbol: agentSymbol(agent), color: agent.isMain ? Palette.main : Palette.agents, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.isMain ? tr("Asosiy agent", "Main agent") : agent.title)
                    .font(.headline).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if !agent.subtitle.isEmpty {
                        Text(agent.subtitle).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    StatePill(state: agent.state)
                }
            }
        }
    }

    @ViewBuilder
    private var now: some View {
        if let running = agent.steps.last, running.status == .running {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: running.symbol).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(running.category.color).frame(width: 16)
                Text(running.text).font(.callout.weight(.medium)).lineLimit(2)
                Spacer(minLength: 6)
                HStack(spacing: 4) { Spinner(size: 9); Text(Dur.text(running.duration)) }
                    .font(.caption).monospacedDigit().foregroundStyle(Brand.ok)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: agent.state == .waiting ? "hourglass" : "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary).frame(width: 16)
                Text(agent.lastAction).font(.callout.weight(.medium)).lineLimit(2)
                    .help(agent.state == .waiting ? tr("Asbob natijasini kutyapti", "Waiting for the tool result") : tr("Oxirgi harakat", "Last action"))
            }
        }
    }
}

/// Tokenlar: katta jami, tarkib chizig'i va har bir qism nimaligi izohi bilan
private struct TokenBreakdown: View {
    let tokens: TokenCounts
    let mode: CountMode
    let sessionTotal: Double

    private struct Part: Identifiable {
        let id: String
        let title: String
        let hint: String
        let value: Int
        let color: Color
    }

    private var parts: [Part] {
        [
            Part(id: "cr", title: tr("Keshdan o'qildi", "Cache read"), hint: tr("Avvalgi kontekst qayta ishlatildi — eng arzon", "Earlier context reused — the cheapest"),
                 value: tokens.cacheRead, color: Brand.accent),
            Part(id: "cw", title: tr("Keshga yozildi", "Cache write"), hint: tr("Yangi kontekst keyingi so'rovlar uchun saqlandi", "New context saved for later requests"),
                 value: tokens.cacheWrite, color: Color(light: 0x2F7BE5, dark: 0x4A8FF0)),
            Part(id: "in", title: tr("Yangi kiritish", "New input"), hint: tr("Keshsiz yuborilgan matn", "Text sent without cache"),
                 value: tokens.input, color: Color(light: 0x0E9F8E, dark: 0x16B3A0)),
            Part(id: "out", title: tr("Javob", "Output"), hint: tokens.thinking > 0
                    ? tr("Model yozgan matn · shundan fikrlash \(Fmt.tokens(Double(tokens.thinking)))", "Text the model wrote · of which thinking \(Fmt.tokens(Double(tokens.thinking)))")
                    : tr("Model yozgan matn", "Text the model wrote"),
                 value: tokens.output, color: Color(light: 0xE0731C, dark: 0xEC8432)),
        ]
    }

    var body: some View {
        let total = max(tokens.total, 1)
        let ps = parts
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.tokens(tokens.value(mode)))
                    .font(.system(size: 24, weight: .bold, design: .rounded)).monospacedDigit()
                Text(mode == .weighted ? tr("vaznli", "weighted") : tr("token", "tokens")).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 6)
                Text(Fmt.percent(tokens.value(mode), of: sessionTotal))
                    .font(.caption.weight(.semibold)).foregroundStyle(Brand.accent)
                    .lineLimit(1).fixedSize()
                    .help(tr("Sessiya tokenlarining shu agentga to'g'ri keladigan ulushi", "This agent's share of the session's tokens"))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Brand.accentSoft))
            }

            // Tarkib chizig'i: kichik qismlar ham ko'rinsin (kamida 3 pt)
            GeometryReader { geo in
                let gap: CGFloat = 2
                let visible = ps.filter { $0.value > 0 }
                let usable = geo.size.width - gap * CGFloat(max(visible.count - 1, 0))
                HStack(spacing: gap) {
                    ForEach(visible) { p in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.color)
                            .frame(width: max(3, usable * CGFloat(p.value) / CGFloat(total)))
                            .help("\(p.title): \(Fmt.tokens(Double(p.value)))")
                    }
                }
            }
            .frame(height: 10)

            // Bir qatorli ro'yxat; izoh — sichqoncha ustiga borganda
            VStack(spacing: 7) {
                ForEach(ps) { p in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(p.color).frame(width: 8, height: 8)
                        Text(p.title).font(.callout)
                        Spacer(minLength: 8)
                        Text(Fmt.tokens(Double(p.value))).font(.callout.weight(.semibold)).monospacedDigit()
                        Text(Fmt.percent(Double(p.value), of: Double(total)))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                            .frame(width: 34, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                    .help(p.hint)
                }
            }
        }
    }
}

/// Asbob turlari: plitka, nechta nishon, chaqiruvlar ulushi chizig'i; bosilsa — ro'yxat ochiladi
private struct ResourceList: View {
    let groups: [ResourceGroup]
    let open: (ToolCategory) -> Void

    var body: some View {
        let sorted = groups.sorted { $0.calls > $1.calls }
        let mx = Double(max(sorted.first?.calls ?? 1, 1))
        VStack(spacing: 2) {
            ForEach(sorted) { g in
                Button { open(g.category) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: g.category.symbol).font(.system(size: 14, weight: .medium))
                            .foregroundStyle(g.category.color).frame(width: 22)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(g.category.title).font(.body.weight(.medium))
                                if g.busy { Spinner(size: 10) }
                                Spacer(minLength: 6)
                                Text("\(g.calls)×").font(.callout.weight(.semibold)).monospacedDigit()
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Brand.line)
                                    Capsule().fill(g.category.color)
                                        .frame(width: max(4, geo.size.width * Double(g.calls) / mx))
                                }
                            }
                            .frame(height: 4)
                            HStack(spacing: 6) {
                                Text(tr("\(g.items.count) ta nishon", "\(g.items.count) \(g.items.count == 1 ? "target" : "targets")"))
                                if g.errors > 0 { Text(tr("· \(g.errors) xato", "· \(g.errors) \(g.errors == 1 ? "error" : "errors")")).foregroundStyle(Brand.err) }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle())
                .help(tr("\(g.category.title): ro'yxat va qadamlarni ochish", "\(g.category.title): open list and steps"))
            }
        }
        .padding(.horizontal, -6).padding(.vertical, -4)
    }
}

private struct ResourceInspector: View {
    let owner: AgentSnap
    let group: ResourceGroup
    let now: Date
    var openStep: (StepSnap) -> Void = { _ in }
    let back: () -> Void

    var body: some View {
        let steps = Array(owner.steps.filter { $0.category == group.category }.reversed())
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: back) {
                    Label(owner.isMain ? tr("Asosiy agent", "Main agent") : owner.title, systemImage: "chevron.left")
                        .font(.callout.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .surfaceCapsule()
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    ToolTile(symbol: group.category.symbol, color: group.category.color, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.category.title).font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            Text(tr("\(group.items.count) ta nishon · \(group.calls) chaqiruv", "\(group.items.count) \(group.items.count == 1 ? "target" : "targets") · \(group.calls) \(group.calls == 1 ? "call" : "calls")"))
                            if group.errors > 0 { Text(tr("· \(group.errors) xato", "· \(group.errors) \(group.errors == 1 ? "error" : "errors")")).foregroundStyle(Brand.err) }
                        }
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }

                InspectorBlock(title: tr("Ro'yxat", "List"), trailing: "\(group.items.count)") {
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { i, item in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(item.name).font(.body.weight(.medium)).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 4)
                                    AccessBadges(item: item)
                                }
                                HStack {
                                    Text(item.detail).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(Fmt.ago(item.lastActivity, now: now))
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                            if i < group.items.count - 1 { Divider() }
                        }
                    }
                    .padding(.vertical, -6)
                }

                InspectorBlock(title: tr("Qadamlar", "Steps"), trailing: "\(steps.count)") {
                    StepTimeline(steps: steps, onSelect: openStep)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }
}

/// O'ylash yoki javobning to'liq matni (saqlangan boshi), tanlab nusxa olish mumkin
private struct NoteInspector: View {
    let note: NoteSnap
    let final: Bool
    let back: () -> Void

    var body: some View {
        let reply = note.kind == .reply
        let color = reply ? Brand.ok : Brand.inkFill
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: back) {
                    Label(tr("Asosiy agent", "Main agent"), systemImage: "chevron.left")
                        .font(.callout.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .surfaceCapsule()
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    ToolTile(symbol: reply ? "text.bubble.fill" : "brain", color: color, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply ? (final ? tr("Javob", "Answer") : tr("Xabar", "Message")) : tr("O'yladi", "Thought")).font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            Text(Fmt.clock.string(from: note.date))
                            if let d = note.duration, d >= 1 { Text("· ~" + Dur.text(d)) }
                            if let t = note.turn { Text(tr("· #\(t)-so'rov", "· prompt #\(t)")) }
                            if let a = note.agent { Text("· " + a) }
                        }
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }

                InspectorBlock(title: reply ? tr("Matn", "Text") : tr("O'ylash matni", "Thinking text"),
                               trailing: note.text.count >= TranscriptEvent.noteLimit ? tr("boshi · \(TranscriptEvent.noteLimit) belgi", "first \(TranscriptEvent.noteLimit) chars") : nil) {
                    if note.text.isEmpty {
                        Text(tr("Bu o'ylash shifrlangan — Claude Code matnini saqlamagan. Faqat davomiyligi ma'lum.", "This thinking is encrypted — Claude Code didn't save its text. Only the duration is known."))
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text(note.text).font(.body).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }
}

/// Qadamlar lentasi: vaqt, holat, nima qilindi, qancha davom etdi
private struct StepTimeline: View {
    let steps: [StepSnap]
    /// Bosilganda qadam tafsiloti (kirish / chiqish) ochiladi
    var onSelect: ((StepSnap) -> Void)? = nil

    var body: some View {
        let shown = Array(steps.prefix(80))
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { i, s in
                HStack(alignment: .top, spacing: 10) {
                    VStack(spacing: 0) {
                        statusIcon(s).frame(width: 22, height: 22)
                        if i < shown.count - 1 {
                            Rectangle().fill(Brand.line).frame(width: 1.5).frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.text).font(.callout).lineLimit(3)
                            .foregroundStyle(s.status == .failed ? Brand.err : Color.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 6) {
                            Text(Fmt.clock.string(from: s.date))
                            if let d = s.duration { Text("· " + Dur.text(d)) }
                            if s.status == .failed { Text(tr("· xato", "· error")).foregroundStyle(Brand.err) }
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.top, 2).padding(.bottom, 12)
                    Spacer(minLength: 0)
                    if onSelect != nil {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary).padding(.top, 6)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { onSelect?(s) }
                .help(onSelect == nil ? "" : tr("Kirish va chiqishni ko'rish", "View input and output"))
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ s: StepSnap) -> some View {
        switch s.status {
        case .running:
            Spinner(size: 10)
        case .failed:
            Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(Circle().fill(Brand.err))
        case .done:
            Image(systemName: s.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(s.category.color)
                .frame(width: 22, height: 22).background(Circle().fill(s.category.color.opacity(0.13)))
        }
    }
}

/// Jarayon so'rovlar bo'yicha: har bir so'rov sarlavhasi (davomiyligi, tokenlari, qadamlari) va ichidagi qadamlar.
/// Eng yangi so'rov tepada va ochiq; qolganlari bosilganda ochiladi.
private struct TurnTimeline: View {
    let steps: [StepSnap]
    let turns: [TurnSnap]
    /// Asosiy agentda — qadamsiz (faqat javob yozilgan) so'rovlar ham ko'rinadi
    let showEmptyTurns: Bool
    let mode: CountMode
    var onStep: ((StepSnap) -> Void)? = nil
    @State private var toggled: Set<Int> = []

    private struct Group: Identifiable {
        let id: Int
        let turn: TurnSnap?
        let steps: [StepSnap]
    }

    private var groups: [Group] {
        let byTurn = Dictionary(grouping: steps, by: { $0.turn ?? 0 })
        var out: [Group] = turns.reversed().compactMap { t in
            let st = Array((byTurn[t.id] ?? []).reversed())
            return st.isEmpty && !showEmptyTurns ? nil : Group(id: t.id, turn: t, steps: st)
        }
        if let before = byTurn[0], !before.isEmpty {
            out.append(Group(id: 0, turn: nil, steps: Array(before.reversed())))
        }
        return out
    }

    var body: some View {
        let gs = groups
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(gs.prefix(40).enumerated()), id: \.element.id) { i, g in
                // Tepadagi so'rov sukut bo'yicha ochiq; bosish holatni almashtiradi
                let open = (i == 0) != toggled.contains(g.id)
                let active = g.turn?.active == true
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        withAnimation(Motion.snappy) {
                            if toggled.contains(g.id) { toggled.remove(g.id) } else { toggled.insert(g.id) }
                        }
                    } label: { header(g, open: open) }
                    .buttonStyle(.plain)
                    if open {
                        if g.steps.isEmpty {
                            Text(tr("Asbob chaqirilmadi — faqat javob yozildi.", "No tools called — only an answer was written."))
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            StepTimeline(steps: g.steps, onSelect: onStep)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surface(radius: 14, stroke: active ? Brand.ok.opacity(0.55) : nil)
            }
            if gs.count > 40 {
                Text(tr("Yana \(gs.count - 40) ta eski so'rov", "\(gs.count - 40) more older \(gs.count - 40 == 1 ? "prompt" : "prompts")")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func header(_ g: Group, open: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(g.turn.map { "#\($0.id)" } ?? "—")
                .font(.caption.weight(.bold)).monospacedDigit()
                .foregroundStyle(Brand.accent)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(Brand.accentSoft))
            VStack(alignment: .leading, spacing: 6) {
                Text(g.turn?.shownPrompt ?? tr("So'rovdan oldingi qadamlar", "Steps before the prompt"))
                    .font(.callout.weight(.medium)).lineLimit(open ? 4 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = g.turn {
                    // Ikki qator: vaqt — bir qatorda, hajm — ikkinchisida; hech narsa kesilmaydi
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if t.active { Spinner(size: 10) }
                            Image(systemName: "clock")
                            Text("\(Fmt.hourMinute.string(from: t.start)) · \(Dur.text(t.duration))")
                        }
                        HStack(spacing: 10) {
                            Label(Fmt.tokens(t.tokens.value(mode)), systemImage: "circle.hexagongrid")
                            Label(tr("\(t.steps) qadam", "\(t.steps) \(t.steps == 1 ? "step" : "steps")"), systemImage: "list.bullet")
                            if t.errors > 0 {
                                Label(tr("\(t.errors) xato", "\(t.errors) \(t.errors == 1 ? "error" : "errors")"), systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Brand.err)
                            }
                        }
                        .labelStyle(TightLabel())
                    }
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                .rotationEffect(.degrees(open ? 90 : 0))
                .padding(.top, 4)
        }
        .contentShape(Rectangle())
    }
}

private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon; configuration.title }
    }
}

/// O'ng tafsilotlar paneli: yon menyu bilan bir xil material, oyna tepasigacha; sarlavha qatorida yopish tugmasi
private struct DetailsPanel<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tr("Tafsilotlar", "Details")).font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                PaneToggle(symbol: "sidebar.right", help: tr("Tafsilotlarni yashirish", "Hide details"), action: onClose)
            }
            .padding(.leading, 18).padding(.trailing, 8).padding(.top, 2).frame(height: 30)
            content
        }
        .background(SidebarMaterial().ignoresSafeArea())
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.black.opacity(0.35)).frame(width: 1).ignoresSafeArea()
        }
        .ignoresSafeArea(.container, edges: .top)
    }
}

/// Yon menyu va panel tugmasi (oyna tugmalari qatorida)
struct PaneToggle: View {
    let symbol: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hover ? Color.primary : Color.secondary)
                .frame(width: 28, height: 24)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(hover ? 0.08 : 0)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusRing()
        .onHover { hover = $0 }
        .help(help)
    }
}

/// macOS yon menyu materiali — chap menyu bilan bir xil fon
struct SidebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .sidebar
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {}
}

// MARK: - Qadam tafsiloti

/// Bitta qadamning bajarilishi (n8n'dagi node bajarilishi kabi): Chiqish — asbob nima qaytardi,
/// Kirish — asbobga nima berildi, Tafsilot — vaqtlar, holat va kontekstga qo'shilgan tokenlar.
private struct StepInspector: View {
    let step: StepSnap
    let agent: AgentSnap
    let back: () -> Void

    private enum Tab: Hashable { case output, input, details }
    @State private var tab: Tab?
    @State private var copied = false

    private var current: Tab { tab ?? (step.status == .running ? .input : .output) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Button(action: back) {
                    Label(agent.isMain ? tr("Asosiy agent", "Main agent") : agent.title, systemImage: "chevron.left")
                        .font(.callout.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .surfaceCapsule()
                }
                .buttonStyle(.plain)

                header

                PillSegments(selection: Binding(get: { current }, set: { tab = $0; copied = false }), items: [
                    .init(id: .output, title: tr("Chiqish", "Output"), symbol: "arrow.down.doc"),
                    .init(id: .input, title: tr("Kirish", "Input"), symbol: "arrow.up.doc"),
                    .init(id: .details, title: tr("Tafsilot", "Details"), symbol: "info.circle"),
                ], compact: true)

                switch current {
                case .output: outputBlock
                case .input: inputBlock
                case .details: detailsBlock
                }
            }
            .padding(18)
        }
        .scrollIndicators(.never)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            ToolTile(symbol: step.symbol, color: step.status == .failed ? Brand.err : step.category.color, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(step.text).font(.title3.weight(.semibold)).lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    statusChip
                    Text(Fmt.clock.string(from: step.date))
                    if let d = step.duration { Text("· " + Dur.text(d)) }
                    if let t = step.turn { Text("· #\(t)") }
                }
                .font(.callout.monospacedDigit()).foregroundStyle(.secondary)
            }
        }
    }

    private var statusChip: some View {
        let (text, color): (String, Color) = {
            switch step.status {
            case .running: return (tr("Bajarilmoqda", "Running"), Brand.accent)
            case .failed: return (tr("Xato", "Error"), Brand.err)
            case .done: return (tr("Bajarildi", "Done"), Brand.ok)
            }
        }()
        return Text(text).font(.caption.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.13)))
    }

    @ViewBuilder
    private var outputBlock: some View {
        let trailing = step.resultTokens.map { tr("~\(Fmt.tokens($0)) token", "~\(Fmt.tokens($0)) tokens") }
        InspectorBlock(title: step.status == .failed ? tr("Xato matni", "Error text") : tr("Asbob qaytardi", "Tool returned"), trailing: trailing, card: false) {
            if let out = step.output {
                if out.isEmpty {
                    empty(tr("Asbob bo'sh natija qaytardi.", "The tool returned an empty result."))
                } else {
                    code(out, limit: TranscriptEvent.outputLimit, error: step.status == .failed)
                }
            } else if step.status == .running {
                empty(tr("Natija hali kelmadi — asbob ishlayapti.", "No result yet — the tool is working."))
            } else if step.input == nil {
                empty(tr("Matn saqlanmagan: sessiyaning oxirgi \(Engine.keepStepIO) ta qadami uchungina saqlanadi.", "Text not saved: it's kept only for the session's last \(Engine.keepStepIO) steps."))
            } else {
                empty(tr("Asbob matnli natija qaytarmadi.", "The tool returned no text result."))
            }
        }
    }

    @ViewBuilder
    private var inputBlock: some View {
        InspectorBlock(title: tr("Asbobga berildi", "Given to the tool"), card: false) {
            if let inp = step.input, !inp.isEmpty {
                code(inp, limit: TranscriptEvent.inputLimit, error: false)
            } else if step.output == nil && step.status != .running {
                empty(tr("Matn saqlanmagan: sessiyaning oxirgi \(Engine.keepStepIO) ta qadami uchungina saqlanadi.", "Text not saved: it's kept only for the session's last \(Engine.keepStepIO) steps."))
            } else {
                empty(tr("Parametrsiz chaqirilgan.", "Called without parameters."))
            }
        }
    }

    private var detailsBlock: some View {
        InspectorBlock(title: tr("Bajarilish", "Execution")) {
            VStack(spacing: 0) {
                row(tr("Asbob", "Tool"), step.category.title)
                row(tr("Nishon", "Target"), step.targetName, step.targetDetail)
                row(tr("Boshlandi", "Started"), Fmt.clock.string(from: step.date))
                if let d = step.duration {
                    row(step.status == .running ? tr("Ketmoqda", "Elapsed") : tr("Davomiyligi", "Duration"), Dur.text(d))
                }
                row(tr("Agent", "Agent"), agent.isMain ? tr("Asosiy agent", "Main agent") : agent.title)
                if let t = step.resultTokens {
                    row(tr("Kontekstga qo'shdi", "Added to context"), tr("~\(Fmt.tokens(t)) token", "~\(Fmt.tokens(t)) tokens"),
                        tr("Natija kontekstda qoladi va keyingi har chaqiruvda qayta o'qiladi", "The result stays in context and is re-read on every later call"), last: true)
                }
            }
            .padding(.vertical, -6)
        }
    }

    private func row(_ k: String, _ v: String, _ note: String? = nil, last: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(k).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(v).fontWeight(.medium).multilineTextAlignment(.trailing).lineLimit(2).truncationMode(.middle)
                    if let note, !note.isEmpty {
                        Text(note).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.trailing)
                            .lineLimit(2).truncationMode(.middle)
                    }
                }
                .textSelection(.enabled)
            }
            .font(.callout)
            .padding(.vertical, 8)
            if !last { Divider() }
        }
    }

    /// Mono matn, tanlab nusxa olish mumkin; uzun bo'lsa — boshi saqlangani aytiladi
    private func code(_ s: String, limit: Int, error: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(s)
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundStyle(error ? Brand.err : Color.primary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Brand.sunken))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Brand.line))
            HStack {
                if s.hasSuffix("…") {
                    Text(tr("Faqat boshi saqlangan · \(limit) belgi", "Only the first \(limit) chars saved")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(s, forType: .string)
                    withAnimation(Motion.snappy) { copied = true }
                } label: {
                    Label(copied ? tr("Nusxalandi", "Copied") : tr("Nusxa olish", "Copy"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.callout).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .surface(radius: 14)
    }
}
