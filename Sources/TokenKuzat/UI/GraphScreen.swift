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

    var agentId: String {
        switch self {
        case .agent(let id), .resource(let id, _), .note(let id, _): return id
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
        // Sahifa aylantirilmaydi: kanvas oynaning qolgan balandligini to'liq egallaydi
        VStack(spacing: 0) {
            if let session, let live {
                let turnNo = effectiveTurn(session)
                let turn = turnNo.flatMap { n in session.turns.first { $0.id == n } }
                let flow = FlowModel(session: session, turnId: turnNo, now: now)
                let tl = TimelineModel(flow: flow, session: session, turnId: turnNo, now: now)
                SessionHeader(session: session, turn: turn, mode: mode, costUSD: s.limits?.costBySession[session.id],
                              waiting: replayOn ? nil : s.permissionWaits[session.id])
                TurnChips(turns: live.turns, selected: turnNo) { turnId = $0 ?? 0 }
                    .padding(.top, 14)
                LanesCard(timeline: tl, replayOn: replayOn) { toggleReplay(live) }
                    .padding(.top, 14)
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
                tabs.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 10)
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
                                       onSelectNote: { sid, note in
                                           if sid != sessionId { sessionId = sid }
                                           DispatchQueue.main.async {
                                               if let tid = note.turn { turnId = tid }
                                               if let m = s.sessions.first(where: { $0.id == sid })?.main {
                                                   selection = .note(agentId: m.id, noteId: note.id)
                                                   if !showInspector { showInspector = true }
                                               }
                                           }
                                       },
                                       chat: !replayOn)
                        if showInspector {
                            Divider()
                            inspector(session, now: now).frame(width: 384)
                        }
                    }
                    .frame(minHeight: 320, maxHeight: .infinity)
                    .card(padding: 0)
                    .padding(.horizontal, 24).padding(.bottom, 20)
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
                        if showInspector {
                            Divider()
                            inspector(session, now: now).frame(width: 384)
                        }
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
                                       title: "Sessiya yo'q",
                                       text: "Mac'da Claude Code yoki Cowork'da ish boshlansa, jarayon shu yerda qadamma-qadam chiqadi.")
                        SourcesList(sources: s.sources).card()
                    }
                    .padding(24)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Motion.spring, value: replayOn)
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
            tab("map", "Xarita", "point.3.connected.trianglepath.dotted",
                help: "Butun sessiya: so'rovlar, asboblar va qadamlar zanjiri")
            tab("summary", "Xulosa", "circle.hexagongrid",
                help: "Tanlangan so'rovda qaysi agent va asboblar ishlatilgani")
            tab("files", "Fayllar", "square.grid.3x3", help: "Qaysi fayllar o'qildi va o'zgartirildi")
            tab("outputs", "Natijalar", "photo.on.rectangle.angled",
                help: "Jarayonda yaratilgan yoki ko'rilgan rasm, HTML, PDF va videolar")
            Spacer()
            if !["files", "outputs"].contains(graphMode) {
                Button { withAnimation(Motion.spring) { showInspector.toggle() } } label: { Image(systemName: "sidebar.right") }
                    .buttonStyle(.borderless)
                    .help(showInspector ? "Tafsilotlarni yashirish" : "Tafsilotlarni ko'rsatish")
            }
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

    private func select(_ s: Selection) {
        selection = selection == s ? nil : s
        if !showInspector { showInspector = true }
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
                AgentInspector(agent: a, turns: session.turns, sessionTotal: session.tokens.value(mode), mode: mode) { cat in
                    select(.resource(agentId: a.id, category: cat))
                }
            }
        case .resource(let id, let cat)?:
            if let a = session.agents.first(where: { $0.id == id }), let g = a.resources.first(where: { $0.category == cat }) {
                ResourceInspector(owner: a, group: g, now: now) { select(.agent(a.id)) }
            } else {
                EmptyStateView(symbol: "questionmark", title: "Topilmadi", text: "")
            }
        case .note(let aid, let nid)?:
            if let n = session.notes.first(where: { $0.id == nid }) {
                NoteInspector(note: n, final: session.turns.first { $0.id == n.turn }?.active != true
                              && session.notes.last { $0.kind == .reply && $0.turn == n.turn && $0.agent == nil }?.id == n.id) {
                    select(.agent(aid))
                }
            } else {
                EmptyStateView(symbol: "questionmark", title: "Topilmadi", text: "")
            }
        case nil:
            EmptyStateView(symbol: "cursorarrow.click", title: "Tugunni tanlang",
                           text: "Agent yoki asbob tugunini bosing — jarayon shu yerda chiqadi.")
        }
    }
}

/// O'qish, yozish, ishga tushirish va xatolar soni
private struct AccessBadges: View {
    let item: ResourceItem

    var body: some View {
        let runs = item.calls - item.reads - item.writes
        HStack(spacing: 6) {
            if item.reads > 0 { badge("eye", item.reads, .secondary, "o'qildi") }
            if item.writes > 0 { badge("pencil", item.writes, .orange, "o'zgartirildi") }
            if runs > 0 { badge("play.fill", runs, .secondary, "chaqirildi") }
            if item.errors > 0 { badge("exclamationmark.triangle.fill", item.errors, .red, "xato") }
        }
    }

    private func badge(_ symbol: String, _ n: Int, _ color: Color, _ help: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: symbol).font(.system(size: 8, weight: .semibold))
            Text("\(n)").font(.caption2).monospacedDigit()
        }
        .foregroundStyle(color)
        .help("\(n) marta \(help)")
    }
}

// MARK: - Inspektorlar

private enum Dur {
    static func text(_ s: TimeInterval?) -> String {
        guard let s else { return "" }
        if s < 1 { return "<1 s" }
        if s < 60 { return "\(Int(s)) s" }
        return "\(Int(s) / 60) daq \(Int(s) % 60) s"
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
            Text(state == .idle ? "Tugagan" : state.title)
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
    let openResource: (ToolCategory) -> Void

    private var trailing: String? {
        let n = agent.isMain ? turns.count : Set(agent.steps.compactMap(\.turn)).count
        guard n > 0 || !agent.steps.isEmpty else { return nil }
        return "\(n) so'rov · \(agent.steps.count) qadam"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                InspectorBlock(title: "Hozir") { now }
                InspectorBlock(title: "Tokenlar", trailing: "\(agent.calls) API chaqiruv") {
                    TokenBreakdown(tokens: agent.tokens, mode: mode, sessionTotal: sessionTotal)
                }
                if !agent.resources.isEmpty {
                    InspectorBlock(title: "Nimalarga kirdi", trailing: "\(agent.resources.reduce(0) { $0 + $1.calls }) chaqiruv") {
                        ResourceList(groups: agent.resources, open: openResource)
                    }
                }
                InspectorBlock(title: "Jarayon", trailing: trailing, card: false) {
                    if agent.steps.isEmpty && (!agent.isMain || turns.isEmpty) {
                        Text("Hali asbob chaqirilmagan.").font(.callout).foregroundStyle(.secondary)
                    } else {
                        TurnTimeline(steps: agent.steps, turns: turns, showEmptyTurns: agent.isMain, mode: mode)
                    }
                }
            }
            .padding(18)
        }
        .background(Brand.sunken)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            ToolTile(symbol: agentSymbol(agent), color: agent.isMain ? Palette.main : Palette.agents, size: 46)
            VStack(alignment: .leading, spacing: 4) {
                Text(agent.isMain ? "Asosiy agent" : agent.title)
                    .font(.title3.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
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
            HStack(alignment: .top, spacing: 12) {
                ToolTile(symbol: running.symbol, color: running.category.color, size: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(running.text).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.mini)
                        Text("\(Dur.text(running.duration)) davom etyapti")
                    }
                    .font(.callout).foregroundStyle(Brand.ok)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 3) {
                Text(agent.state == .waiting ? "Asbob natijasini kutyapti" : "Oxirgi harakat")
                    .font(.caption).foregroundStyle(.secondary)
                Text(agent.lastAction).font(.body.weight(.medium)).fixedSize(horizontal: false, vertical: true)
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
            Part(id: "cr", title: "Keshdan o'qildi", hint: "Avvalgi kontekst qayta ishlatildi — eng arzon",
                 value: tokens.cacheRead, color: Brand.accent),
            Part(id: "cw", title: "Keshga yozildi", hint: "Yangi kontekst keyingi so'rovlar uchun saqlandi",
                 value: tokens.cacheWrite, color: Color(light: 0x2F7BE5, dark: 0x4A8FF0)),
            Part(id: "in", title: "Yangi kiritish", hint: "Keshsiz yuborilgan matn",
                 value: tokens.input, color: Color(light: 0x0E9F8E, dark: 0x16B3A0)),
            Part(id: "out", title: "Javob", hint: tokens.thinking > 0
                    ? "Model yozgan matn · shundan fikrlash \(Fmt.tokens(Double(tokens.thinking)))"
                    : "Model yozgan matn",
                 value: tokens.output, color: Color(light: 0xE0731C, dark: 0xEC8432)),
        ]
    }

    var body: some View {
        let total = max(tokens.total, 1)
        let ps = parts
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.tokens(tokens.value(mode)))
                    .font(.system(size: 30, weight: .bold, design: .rounded)).monospacedDigit()
                Text(mode == .weighted ? "vaznli token" : "token").font(.callout).foregroundStyle(.secondary)
                Spacer()
                Text("sessiyaning \(Fmt.percent(tokens.value(mode), of: sessionTotal))")
                    .font(.caption.weight(.semibold)).foregroundStyle(Brand.accent)
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

            VStack(spacing: 10) {
                ForEach(ps) { p in
                    HStack(alignment: .top, spacing: 10) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(p.color)
                            .frame(width: 10, height: 10).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.callout.weight(.medium))
                            Text(p.hint).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(Fmt.tokens(Double(p.value))).font(.callout.weight(.semibold)).monospacedDigit()
                            Text(Fmt.percent(Double(p.value), of: Double(total)))
                                .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
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
                        ToolTile(symbol: g.category.symbol, color: g.category.color, size: 34)
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 6) {
                                Text(g.category.title).font(.body.weight(.medium))
                                if g.busy { ProgressView().controlSize(.mini) }
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
                                Text("\(g.items.count) ta nishon")
                                if g.errors > 0 { Text("· \(g.errors) xato").foregroundStyle(Brand.err) }
                            }
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle())
                .help("\(g.category.title): ro'yxat va qadamlarni ochish")
            }
        }
        .padding(.horizontal, -6).padding(.vertical, -4)
    }
}

private struct ResourceInspector: View {
    let owner: AgentSnap
    let group: ResourceGroup
    let now: Date
    let back: () -> Void

    var body: some View {
        let steps = Array(owner.steps.filter { $0.category == group.category }.reversed())
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Button(action: back) {
                    Label(owner.isMain ? "Asosiy agent" : owner.title, systemImage: "chevron.left")
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
                            Text("\(group.items.count) ta nishon · \(group.calls) chaqiruv")
                            if group.errors > 0 { Text("· \(group.errors) xato").foregroundStyle(Brand.err) }
                        }
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }

                InspectorBlock(title: "Ro'yxat", trailing: "\(group.items.count) ta") {
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

                InspectorBlock(title: "Qadamlar", trailing: "\(steps.count) ta") {
                    StepTimeline(steps: steps)
                }
            }
            .padding(18)
        }
        .background(Brand.sunken)
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
                    Label("Asosiy agent", systemImage: "chevron.left")
                        .font(.callout.weight(.medium)).lineLimit(1)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .surfaceCapsule()
                }
                .buttonStyle(.plain)

                HStack(spacing: 12) {
                    ToolTile(symbol: reply ? "text.bubble.fill" : "brain", color: color, size: 46)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(reply ? (final ? "Javob" : "Xabar") : "O'yladi").font(.title3.weight(.semibold))
                        HStack(spacing: 6) {
                            Text(Fmt.clock.string(from: note.date))
                            if let d = note.duration, d >= 1 { Text("· ~" + Dur.text(d)) }
                            if let t = note.turn { Text("· #\(t)-so'rov") }
                            if let a = note.agent { Text("· " + a) }
                        }
                        .font(.callout).foregroundStyle(.secondary)
                    }
                }

                InspectorBlock(title: reply ? "Matn" : "O'ylash matni",
                               trailing: note.text.count >= TranscriptEvent.noteLimit ? "boshi · \(TranscriptEvent.noteLimit) belgi" : nil) {
                    if note.text.isEmpty {
                        Text("Bu o'ylash shifrlangan — Claude Code matnini saqlamagan. Faqat davomiyligi ma'lum.")
                            .font(.callout).foregroundStyle(.secondary)
                    } else {
                        Text(note.text).font(.body).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(18)
        }
        .background(Brand.sunken)
    }
}

/// Qadamlar lentasi: vaqt, holat, nima qilindi, qancha davom etdi
private struct StepTimeline: View {
    let steps: [StepSnap]

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
                            if s.status == .failed { Text("· xato").foregroundStyle(Brand.err) }
                        }
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.top, 2).padding(.bottom, 12)
                    Spacer(minLength: 0)
                }
            }
        }
    }

    @ViewBuilder
    private func statusIcon(_ s: StepSnap) -> some View {
        switch s.status {
        case .running:
            ProgressView().controlSize(.mini)
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
                            Text("Asbob chaqirilmadi — faqat javob yozildi.")
                                .font(.callout).foregroundStyle(.secondary)
                        } else {
                            StepTimeline(steps: g.steps)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .surface(radius: 14, stroke: active ? Brand.ok.opacity(0.55) : nil)
            }
            if gs.count > 40 {
                Text("Yana \(gs.count - 40) ta eski so'rov").font(.caption).foregroundStyle(.secondary)
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
                Text(g.turn?.shownPrompt ?? "So'rovdan oldingi qadamlar")
                    .font(.callout.weight(.medium)).lineLimit(open ? 4 : 2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                if let t = g.turn {
                    // Ikki qator: vaqt — bir qatorda, hajm — ikkinchisida; hech narsa kesilmaydi
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            if t.active { ProgressView().controlSize(.mini) }
                            Image(systemName: "clock")
                            Text("\(Fmt.hourMinute.string(from: t.start)) · \(Dur.text(t.duration))")
                        }
                        HStack(spacing: 10) {
                            Label(Fmt.tokens(t.tokens.value(mode)), systemImage: "circle.hexagongrid")
                            Label("\(t.steps) qadam", systemImage: "list.bullet")
                            if t.errors > 0 {
                                Label("\(t.errors) xato", systemImage: "exclamationmark.triangle.fill")
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
