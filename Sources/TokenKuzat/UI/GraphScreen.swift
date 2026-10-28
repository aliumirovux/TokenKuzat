import SwiftUI
import AppKit
import TokenKuzatCore

// n8n canvas'iga o'xshash jarayon sxemasi:
//
// [Siz] ──▶ [Asosiy agent] ──▶ [Fayllar]       ──▶ (tanlangan yordamchining resurslari)
//                         ├──▶ [Terminal]
//                         ├──▶ [Internet]
//                         ├──▶ [Yordamchi agent] ──▶ [Fayllar] …
//                         └──▶ [+N ta tugagan]
//
// Hozir bajarilayotgan qadamga boradigan chiziq bo'ylab nuqtalar oqadi; chiziq qalinligi — chaqiruvlar soni.
// O'ngda — tanlangan tugun tafsiloti: jarayon lentasi (har bir qadam, davomiyligi, natijasi) va resurslar.

private enum G {
    static let nodeW: CGFloat = 250
    static let agentH: CGFloat = 100
    static let resH: CGFloat = 118
    static let trigW: CGFloat = 220
    static let trigH: CGFloat = 76
    static let groupH: CGFloat = 64
    static let colGap: CGFloat = 72
    static let rowGap: CGFloat = 18
    static let pad: CGFloat = 32
    static let minScale: CGFloat = 0.6
    static let collapseOver = 6
    static let visibleIdle = 2
    /// Shuncha soniya ichida ishlatilgan resursga chiziq yorqin chiziladi
    static let recent: TimeInterval = 20
}

extension ToolCategory {
    var color: Color {
        switch self {
        case .files: return .blue
        case .shell: return .mint
        case .web: return .cyan
        case .mcp: return .pink
        case .agent: return .indigo
        case .other: return .gray
        }
    }
}

/// Inspektorda nima ko'rsatiladi
private enum Selection: Equatable {
    case agent(String)
    case resource(agentId: String, category: ToolCategory)

    var agentId: String {
        switch self {
        case .agent(let id), .resource(let id, _): return id
        }
    }
}

private enum Node: Identifiable {
    case agent(AgentSnap)
    case resource(owner: AgentSnap, group: ResourceGroup)
    case idleGroup(count: Int, tokens: TokenCounts, expanded: Bool)

    var id: String {
        switch self {
        case .agent(let a): return a.id
        case .resource(let o, let g): return o.id + "#" + g.id
        case .idleGroup(_, _, let e): return e ? "__collapse" : "__group"
        }
    }

    var height: CGFloat {
        switch self {
        case .agent: return G.agentH
        case .resource: return G.resH
        case .idleGroup: return G.groupH
        }
    }
}

private struct Edge: Identifiable {
    enum Style { case flow, wait, idle, hot, warm, cold }
    let id: String
    let from: CGPoint
    let to: CGPoint
    let style: Style
    let color: Color
    let width: CGFloat
}

private struct Placed: Identifiable {
    let node: Node
    let p: CGPoint
    var id: String { node.id }
}

private struct GraphLayout {
    var size: CGSize = .zero
    /// Tugunlar egallagan o'lcham (canvas'dan kichik bo'lishi mumkin)
    var content: CGSize = .zero
    var fits = true
    var trigger: CGPoint?
    var main: CGPoint = .zero
    var nodes: [Placed] = []
    var edges: [Edge] = []
}

// MARK: - Ekran

struct GraphScreen: View {
    static let selectedSessionKey = "graphSession"
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""
    @AppStorage("graphInspector") private var showInspector = true
    @State private var selection: Selection?
    @State private var showAllIdle = false

    var body: some View {
        let s = store.snap
        let session = s.sessions.first(where: { $0.id == sessionId }) ?? s.sessions.first
        VStack(spacing: 0) {
            topBar(s, session)
            Divider()
            if let session {
                HStack(spacing: 0) {
                    canvas(session, now: s.updatedAt)
                    if showInspector {
                        Divider()
                        inspector(session, now: s.updatedAt).frame(width: 340)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(symbol: "point.3.connected.trianglepath.dotted",
                                       title: "Sxema uchun sessiya yo'q",
                                       text: "Mac'da Claude Code yoki Cowork'da ish boshlansa, agentlar va ular kirgan fayllar, buyruqlar, saytlar shu yerda tugunlar bo'lib chiqadi.")
                        SourcesList(sources: s.sources).card()
                    }
                    .padding(20)
                }
            }
        }
        .onChange(of: sessionId) { _ in selection = nil; showAllIdle = false }
    }

    // MARK: Yuqori panel

    private func topBar(_ s: Snapshot, _ session: SessionSnap?) -> some View {
        HStack(spacing: 12) {
            if !s.sessions.isEmpty {
                Picker("Sessiya", selection: Binding(get: { session?.id ?? "" }, set: { sessionId = $0 })) {
                    ForEach(s.sessions) { Text(sessionLabel($0)).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 380)
            }
            Spacer()
            if let session {
                let steps = session.agents.reduce(0) { $0 + $1.steps.count }
                Text("\(steps) qadam · \(Fmt.tokens(session.tokens.value(mode))) token")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
            Button { withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() } } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.borderless)
            .help(showInspector ? "Tafsilotlarni yashirish" : "Tafsilotlarni ko'rsatish")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func sessionLabel(_ ss: SessionSnap) -> String {
        var mark = ss.state == .running ? "● " : (ss.state == .waiting ? "◐ " : "")
        if let la = ss.lastActivity, !Calendar.current.isDateInToday(la) {
            mark += Fmt.dayTime.string(from: la) + " · "
        }
        let t = ss.title.count > 42 ? String(ss.title.prefix(42)) + "…" : ss.title
        return "\(mark)\(ss.project) — \(t)"
    }

    // MARK: Canvas

    private func canvas(_ session: SessionSnap, now: Date) -> some View {
        GeometryReader { geo in
            // Oynaga sig'dirish: kerak bo'lsa 60% gacha kichraytiriladi, undan katta bo'lsa — aylantirish
            // Tor oynada «so'rov» tuguni yashiriladi — sessiya nomi tepada baribir ko'rinadi
            let full = makeLayout(session, viewport: geo.size, now: now, trigger: true).content
            let trigger = full.width <= geo.size.width
            let natural = trigger ? full : makeLayout(session, viewport: geo.size, now: now, trigger: false).content
            let fit = min(1, geo.size.width / max(natural.width, 1), geo.size.height / max(natural.height, 1))
            let scale = max(fit, G.minScale)
            let viewport = CGSize(width: geo.size.width / scale, height: geo.size.height / scale)
            let layout = makeLayout(session, viewport: viewport, now: now, trigger: trigger)
            let scaled = canvasContent(session, layout)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: layout.size.width * scale, height: layout.size.height * scale, alignment: .topLeading)
            Group {
                // Sig'sa — ScrollView'siz: aks holda u o'z ichki chekinishi bilan kontentni pastga surib qo'yadi
                if layout.fits {
                    scaled
                } else {
                    ScrollView([.horizontal, .vertical]) { scaled }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(Color(nsColor: .underPageBackgroundColor))
            .overlay(alignment: .bottomLeading) { Legend().padding(12) }
        }
    }

    private func canvasContent(_ session: SessionSnap, _ layout: GraphLayout) -> some View {
        ZStack(alignment: .topLeading) {
            DotGrid()
            EdgesView(edges: layout.edges).allowsHitTesting(false)

            if let t = layout.trigger { TriggerNode(text: session.title).position(t) }

            if let main = session.main {
                AgentNode(agent: main, tokens: main.tokens.value(mode),
                          share: Fmt.percent(main.tokens.value(mode), of: session.tokens.value(mode)),
                          extra: session.contextTokens > 0 ? "Kontekst \(Fmt.tokens(session.contextTokens))" : nil,
                          selected: currentSelection(session) == .agent(main.id))
                    .position(layout.main)
                    .onTapGesture { select(.agent(main.id)) }
            }

            ForEach(layout.nodes) { placed in
                nodeView(placed.node, session).position(placed.p)
            }
        }
        .frame(width: layout.size.width, height: layout.size.height)
        .contentShape(Rectangle())
        .onTapGesture { selection = nil }
    }

    @ViewBuilder
    private func nodeView(_ node: Node, _ session: SessionSnap) -> some View {
        let sel = currentSelection(session)
        switch node {
        case .agent(let a):
            AgentNode(agent: a, tokens: a.tokens.value(mode),
                      share: Fmt.percent(a.tokens.value(mode), of: session.tokens.value(mode)),
                      extra: a.steps.isEmpty ? nil : "\(a.steps.count) qadam",
                      selected: sel?.agentId == a.id)
                .onTapGesture { select(.agent(a.id)) }
        case .resource(let owner, let g):
            ResourceNode(group: g, selected: sel == .resource(agentId: owner.id, category: g.category))
                .onTapGesture { select(.resource(agentId: owner.id, category: g.category)) }
        case .idleGroup(let count, let tokens, let expanded):
            GroupNode(count: count, tokens: tokens.value(mode), expanded: expanded)
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showAllIdle.toggle() } }
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

    // MARK: Ma'lumot → tugunlar

    private func helperNodes(_ session: SessionSnap) -> [Node] {
        let subs = session.agents.filter { !$0.isMain }   // eng yangisi birinchi
        guard subs.count > G.collapseOver else { return subs.map { Node.agent($0) } }
        let idle = subs.filter { $0.state == .idle }
        let keep = Set(idle.prefix(G.visibleIdle).map(\.id))
        let hidden = idle.filter { !keep.contains($0.id) }
        guard !hidden.isEmpty else { return subs.map { Node.agent($0) } }
        if showAllIdle {
            return subs.map { Node.agent($0) } + [.idleGroup(count: hidden.count, tokens: TokenCounts(), expanded: true)]
        }
        let hiddenIds = Set(hidden.map(\.id))
        let sum = hidden.reduce(TokenCounts()) { $0 + $1.tokens }
        return subs.filter { !hiddenIds.contains($0.id) }.map { Node.agent($0) }
            + [.idleGroup(count: hidden.count, tokens: sum, expanded: false)]
    }

    private func makeLayout(_ session: SessionSnap, viewport: CGSize, now: Date, trigger: Bool) -> GraphLayout {
        var l = GraphLayout()
        guard let main = session.main else { return l }

        // 3-ustun: asosiy agentning resurslari, keyin yordamchi agentlar
        let col2: [Node] = main.resources.map { .resource(owner: main, group: $0) } + helperNodes(session)
        // 4-ustun: tanlangan yordamchi agentning resurslari
        let focus: AgentSnap? = selection.flatMap { sel in
            sel.agentId == main.id ? nil : session.agents.first { $0.id == sel.agentId }
        }
        let col3: [Node] = focus.map { f in f.resources.map { Node.resource(owner: f, group: $0) } } ?? []

        func height(_ col: [Node]) -> CGFloat {
            col.isEmpty ? 0 : col.reduce(0) { $0 + $1.height } + CGFloat(col.count - 1) * G.rowGap
        }
        let h2 = height(col2), h3 = height(col3)
        let contentH = max(h2, h3, G.agentH) + 2 * G.pad
        let columns: CGFloat = col3.isEmpty ? (col2.isEmpty ? 2 : 3) : 4
        let lead = trigger ? G.trigW + G.colGap : 0
        let contentW = 2 * G.pad + lead + G.nodeW + (columns - 2) * (G.colGap + G.nodeW)
        let w = max(contentW, viewport.width), h = max(contentH, viewport.height)
        l.size = CGSize(width: w, height: h)
        l.content = CGSize(width: contentW, height: contentH)
        l.fits = contentW <= viewport.width + 1 && contentH <= viewport.height + 1

        // Kontent kichik bo'lsa o'rtaga joylashadi
        let ox = (w - contentW) / 2
        let midY = h / 2
        let x1 = ox + G.pad + lead + G.nodeW / 2
        l.main = CGPoint(x: x1, y: midY)
        if trigger {
            let t = CGPoint(x: ox + G.pad + G.trigW / 2, y: midY)
            l.trigger = t
            l.edges.append(Edge(id: "trigger", from: CGPoint(x: t.x + G.trigW / 2, y: midY),
                                to: CGPoint(x: x1 - G.nodeW / 2, y: midY),
                                style: agentStyle(main.state), color: Palette.state(main.state), width: 2))
        }

        let x2 = x1 + G.nodeW + G.colGap
        let maxCalls = max(1, (col2 + col3).compactMap { n -> Int? in
            if case .resource(_, let g) = n { return g.calls }
            return nil
        }.max() ?? 1)
        let maxTok = col2.compactMap { n -> Double? in
            if case .agent(let a) = n { return a.tokens.value(mode) }
            return nil
        }.max() ?? 0

        var y = midY - h2 / 2
        var focusY = midY
        for node in col2 {
            let p = CGPoint(x: x2, y: y + node.height / 2)
            l.nodes.append(Placed(node: node, p: p))
            l.edges.append(edge(for: node, from: CGPoint(x: x1 + G.nodeW / 2, y: midY),
                                to: CGPoint(x: x2 - G.nodeW / 2, y: p.y), now: now, maxCalls: maxCalls, maxTok: maxTok))
            if case .agent(let a) = node, a.id == focus?.id { focusY = p.y }
            y += node.height + G.rowGap
        }

        if !col3.isEmpty {
            let x3 = x2 + G.nodeW + G.colGap
            // Yordamchi qatoriga yaqin turadi, lekin canvas'dan chiqmaydi
            var y3 = min(max(G.pad, focusY - h3 / 2), h - G.pad - h3)
            for node in col3 {
                let p = CGPoint(x: x3, y: y3 + node.height / 2)
                l.nodes.append(Placed(node: node, p: p))
                l.edges.append(edge(for: node, from: CGPoint(x: x2 + G.nodeW / 2, y: focusY),
                                    to: CGPoint(x: x3 - G.nodeW / 2, y: p.y), now: now, maxCalls: maxCalls, maxTok: maxTok))
                y3 += node.height + G.rowGap
            }
        }
        return l
    }

    private func agentStyle(_ s: AgentState) -> Edge.Style {
        switch s {
        case .running: return .flow
        case .waiting: return .wait
        case .idle: return .idle
        }
    }

    private func edge(for node: Node, from: CGPoint, to: CGPoint, now: Date, maxCalls: Int, maxTok: Double) -> Edge {
        switch node {
        case .agent(let a):
            let w = maxTok > 0 ? 1.5 + 3.5 * CGFloat(sqrt(a.tokens.value(mode) / maxTok)) : 1.5
            return Edge(id: node.id, from: from, to: to, style: agentStyle(a.state), color: Palette.state(a.state), width: w)
        case .resource(_, let g):
            let age = g.lastActivity.map { now.timeIntervalSince($0) } ?? .infinity
            let style: Edge.Style = g.busy ? .hot : (age < G.recent ? .warm : .cold)
            return Edge(id: node.id, from: from, to: to, style: style, color: g.category.color,
                        width: 1.5 + 3 * CGFloat(sqrt(Double(g.calls) / Double(maxCalls))))
        case .idleGroup:
            return Edge(id: node.id, from: from, to: to, style: .idle, color: .secondary, width: 1.5)
        }
    }

    // MARK: Inspektor

    @ViewBuilder
    private func inspector(_ session: SessionSnap, now: Date) -> some View {
        switch currentSelection(session) {
        case .agent(let id)?:
            if let a = session.agents.first(where: { $0.id == id }) {
                AgentInspector(agent: a, sessionTotal: session.tokens.value(mode), mode: mode) { cat in
                    select(.resource(agentId: a.id, category: cat))
                }
            }
        case .resource(let id, let cat)?:
            if let a = session.agents.first(where: { $0.id == id }), let g = a.resources.first(where: { $0.category == cat }) {
                ResourceInspector(owner: a, group: g, now: now) { select(.agent(a.id)) }
            } else {
                EmptyStateView(symbol: "questionmark", title: "Topilmadi", text: "")
            }
        case nil:
            EmptyStateView(symbol: "cursorarrow.click", title: "Tugunni tanlang",
                           text: "Agent yoki resurs tugunini bosing — jarayon shu yerda chiqadi.")
        }
    }
}

// MARK: - Chiziqlar

private struct EdgesView: View {
    let edges: [Edge]

    var body: some View {
        let animated = edges.contains { $0.style == .flow || $0.style == .hot }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, _ in
                for e in edges {
                    let path = curve(e.from, e.to)
                    switch e.style {
                    case .flow, .hot:
                        g.stroke(path, with: .color(e.color.opacity(0.3)), lineWidth: e.width)
                        g.stroke(path, with: .color(e.color),
                                 style: StrokeStyle(lineWidth: e.width + 2.5, lineCap: .round,
                                                    dash: [0.1, 14], dashPhase: CGFloat(-t * 45)))
                    case .wait:
                        g.stroke(path, with: .color(e.color.opacity(0.8)),
                                 style: StrokeStyle(lineWidth: e.width, lineCap: .round, dash: [6, 5]))
                    case .warm:
                        g.stroke(path, with: .color(e.color.opacity(0.85)), lineWidth: e.width)
                    case .cold:
                        g.stroke(path, with: .color(e.color.opacity(0.28)), lineWidth: e.width)
                    case .idle:
                        g.stroke(path, with: .color(Color.secondary.opacity(0.45)), lineWidth: e.width)
                    }
                    let r: CGFloat = 4
                    let dim = e.style == .idle || e.style == .cold
                    g.fill(Path(ellipseIn: CGRect(x: e.to.x - r, y: e.to.y - r, width: r * 2, height: r * 2)),
                           with: .color(dim ? Color.secondary.opacity(0.6) : e.color))
                }
            }
        }
    }

    private func curve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        let dx = max(40, (b.x - a.x) * 0.5)
        p.move(to: a)
        p.addCurve(to: b, control1: CGPoint(x: a.x + dx, y: a.y), control2: CGPoint(x: b.x - dx, y: b.y))
        return p
    }
}

private struct DotGrid: View {
    var body: some View {
        Canvas { g, size in
            let step: CGFloat = 22
            let c = Color.primary.opacity(0.13)
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    g.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .color(c))
                    x += step
                }
                y += step
            }
        }
    }
}

// MARK: - Tugunlar

private struct NodeChrome: ViewModifier {
    let live: Bool
    let liveColor: Color
    let selected: Bool
    let width: CGFloat
    let height: CGFloat
    var inPort = true
    var outPort = true

    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.primary.opacity(0.14), lineWidth: selected ? 2 : 1))
            .overlay(RunningGlow(active: live, color: liveColor))
            .overlay(alignment: .leading) { if inPort { Port().offset(x: -4) } }
            .overlay(alignment: .trailing) { if outPort { Port().offset(x: 4) } }
            .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Port: View {
    var body: some View {
        Circle().fill(Color(nsColor: .controlBackgroundColor))
            .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
            .frame(width: 8, height: 8)
    }
}

private struct RunningGlow: View {
    let active: Bool
    var color: Color = .green

    var body: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(color.opacity(0.55 + 0.45 * sin(t * 3)), lineWidth: 2)
                    .shadow(color: color.opacity(0.45), radius: 8)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct AgentNode: View {
    let agent: AgentSnap
    let tokens: Double
    let share: String
    let extra: String?
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: agentSymbol(agent), tint: agent.isMain ? Palette.main : Palette.agents)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(agent.isMain ? "Asosiy agent" : agent.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    StateDot(state: agent.state)
                }
                Text(agent.subtitle.isEmpty ? (agent.isMain ? "" : "yordamchi") : agent.subtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(agent.lastAction)
                    .font(.caption)
                    .foregroundStyle(agent.state == .idle ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Text(Fmt.tokens(tokens)).font(.caption.weight(.semibold)).monospacedDigit()
                    Text(share).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    Spacer(minLength: 0)
                    if let extra { Text(extra).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        }
        .modifier(NodeChrome(live: agent.state == .running, liveColor: .green, selected: selected,
                             width: G.nodeW, height: G.agentH, outPort: agent.isMain || !agent.resources.isEmpty))
        .help("Bosing — jarayon va resurslar")
    }
}

/// Agent kirgan narsalar guruhi: Fayllar, Terminal, Internet…
private struct ResourceNode: View {
    let group: ResourceGroup
    let selected: Bool

    var body: some View {
        let c = group.category.color
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                IconTile(symbol: group.category.symbol, tint: c, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.category.title).font(.callout.weight(.semibold)).lineLimit(1)
                    Text("\(group.items.count) ta · \(group.calls) chaqiruv").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if group.errors > 0 {
                    Label("\(group.errors)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption2.weight(.semibold)).foregroundStyle(.red)
                        .help("\(group.errors) ta chaqiruv xato bilan tugadi")
                }
                if group.busy { ProgressView().controlSize(.mini) }
            }
            VStack(alignment: .leading, spacing: 2) {
                ForEach(group.items.prefix(3)) { item in
                    HStack(spacing: 4) {
                        Text(item.name).font(.caption).lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 4)
                        AccessBadges(item: item)
                    }
                }
                if group.items.count > 3 {
                    Text("+\(group.items.count - 3) ta yana").font(.caption2).foregroundStyle(.tertiary)
                }
            }
        }
        .modifier(NodeChrome(live: group.busy, liveColor: c, selected: selected,
                             width: G.nodeW, height: G.resH, outPort: false))
        .help("Bosing — \(group.category.title.lowercased()) ro'yxati")
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

private struct TriggerNode: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: "person.fill", tint: Palette.cacheRead)
            VStack(alignment: .leading, spacing: 2) {
                Text("Sizning so'rovingiz").font(.callout.weight(.semibold)).lineLimit(1)
                Text(text).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .modifier(NodeChrome(live: false, liveColor: .clear, selected: false,
                             width: G.trigW, height: G.trigH, inPort: false))
    }
}

private struct GroupNode: View {
    let count: Int
    let tokens: Double
    let expanded: Bool
    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: expanded ? "chevron.up" : "square.stack.3d.up.fill", tint: .secondary, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(expanded ? "Tugaganlarni yig'ish" : "+\(count) ta tugagan agent").font(.callout.weight(.semibold))
                Text(expanded ? "\(count) ta tugagan agentni yashirish" : "Jami \(Fmt.tokens(tokens)) token · bosib oching")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: G.nodeW, height: G.groupH, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .overlay(alignment: .leading) { Port().offset(x: -4) }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(Palette.state(.running), "Ishlayapti")
            item(Palette.state(.waiting), "Natija kutyapti")
            item(Palette.state(.idle), "Tugagan")
            Divider().frame(height: 10)
            ForEach([ToolCategory.files, .shell, .web, .mcp], id: \.self) { item($0.color, $0.title) }
            Text("Qalinlik = hajm").foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }

    private func item(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t)
        }
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

private struct InspectorBlock<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if let trailing { Text(trailing).font(.caption2).foregroundStyle(.tertiary) }
            }
            content
        }
    }
}

private struct KV: View {
    let k: String
    let v: String
    var bold = false

    var body: some View {
        HStack {
            Text(k).font(.caption)
            Spacer()
            Text(v).font(bold ? .caption.weight(.semibold) : .caption).monospacedDigit()
        }
    }
}

private struct AgentInspector: View {
    let agent: AgentSnap
    let sessionTotal: Double
    let mode: CountMode
    let openResource: (ToolCategory) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    IconTile(symbol: agentSymbol(agent), tint: agent.isMain ? Palette.main : Palette.agents, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(agent.isMain ? "Asosiy agent" : agent.title)
                            .font(.headline).fixedSize(horizontal: false, vertical: true)
                        if !agent.subtitle.isEmpty { Text(agent.subtitle).font(.caption).foregroundStyle(.secondary) }
                        HStack(spacing: 6) {
                            StateDot(state: agent.state, size: 7)
                            Text(agent.state.title).font(.caption)
                        }
                    }
                }

                InspectorBlock(title: "HOZIR") {
                    HStack(alignment: .top, spacing: 8) {
                        if let running = agent.steps.last, running.status == .running {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(running.text).font(.callout)
                                Text("\(Dur.text(running.duration)) davom etyapti").font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text(agent.lastAction).font(.callout)
                        }
                    }
                }

                InspectorBlock(title: "TOKENLAR") {
                    VStack(spacing: 5) {
                        KV(k: "Jami", v: Fmt.tokens(agent.tokens.value(mode)), bold: true)
                        KV(k: "Sessiyadagi ulushi", v: Fmt.percent(agent.tokens.value(mode), of: sessionTotal))
                        KV(k: "Kesh o'qish / yozish", v: "\(Fmt.tokens(agent.tokens.cacheRead)) / \(Fmt.tokens(agent.tokens.cacheWrite))")
                        KV(k: "Javob (shundan fikrlash)", v: "\(Fmt.tokens(agent.tokens.output)) (\(Fmt.tokens(agent.tokens.thinking)))")
                        KV(k: "API chaqiruvlar", v: "\(agent.calls)")
                    }
                }

                if !agent.resources.isEmpty {
                    InspectorBlock(title: "NIMALARGA KIRDI") {
                        VStack(spacing: 4) {
                            ForEach(agent.resources) { g in
                                Button { openResource(g.category) } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: g.category.symbol).foregroundStyle(g.category.color).frame(width: 16)
                                        Text(g.category.title).font(.callout)
                                        if g.busy { ProgressView().controlSize(.mini) }
                                        Spacer()
                                        Text("\(g.items.count) ta · \(g.calls)×").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                        Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4).padding(.horizontal, 6)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(RowButtonStyle())
                            }
                        }
                    }
                }

                InspectorBlock(title: "JARAYON", trailing: agent.steps.isEmpty ? nil : "\(agent.steps.count) qadam") {
                    if agent.steps.isEmpty {
                        Text("Hali asbob chaqirilmagan.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        StepTimeline(steps: Array(agent.steps.reversed()))
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
            VStack(alignment: .leading, spacing: 18) {
                Button(action: back) {
                    Label(owner.isMain ? "Asosiy agent" : owner.title, systemImage: "chevron.left")
                        .font(.caption).lineLimit(1)
                }
                .buttonStyle(.link)

                HStack(spacing: 12) {
                    IconTile(symbol: group.category.symbol, tint: group.category.color, size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.category.title).font(.headline)
                        Text("\(group.items.count) ta · \(group.calls) chaqiruv\(group.errors > 0 ? " · \(group.errors) xato" : "")")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                InspectorBlock(title: "RO'YXAT") {
                    VStack(spacing: 8) {
                        ForEach(group.items) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name).font(.callout).lineLimit(1).truncationMode(.middle)
                                    Spacer(minLength: 4)
                                    AccessBadges(item: item)
                                }
                                HStack {
                                    Text(item.detail).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(Fmt.ago(item.lastActivity, now: now))
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }

                InspectorBlock(title: "QADAMLAR", trailing: "\(steps.count) ta") {
                    StepTimeline(steps: steps)
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
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
                        statusIcon(s).frame(width: 16, height: 16)
                        if i < shown.count - 1 {
                            Rectangle().fill(Color.primary.opacity(0.1)).frame(width: 1).frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.text).font(.caption).lineLimit(2)
                            .foregroundStyle(s.status == .failed ? Color.red : Color.primary)
                        HStack(spacing: 6) {
                            Text(Fmt.clock.string(from: s.date))
                            if let d = s.duration { Text("· " + Dur.text(d)) }
                            if s.status == .failed { Text("· xato").foregroundStyle(.red) }
                        }
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 10)
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
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
        case .done:
            Image(systemName: s.symbol).foregroundStyle(s.category.color).font(.system(size: 10, weight: .semibold))
        }
    }
}
