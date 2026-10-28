import SwiftUI
import AppKit
import TokenKuzatCore

// n8n canvas'iga o'xshash agentlar sxemasi:
// [Siz] ──▶ [Asosiy agent] ──▶ [Yordamchi agent 1]
//                         ├──▶ [Yordamchi agent 2]
//                         └──▶ [+N ta tugagan]
// Ishlayotgan agentga boradigan chiziq bo'ylab nuqtalar oqib turadi.

private enum G {
    static let nodeW: CGFloat = 260
    static let nodeH: CGFloat = 96
    static let trigW: CGFloat = 210
    static let trigH: CGFloat = 76
    static let gap1: CGFloat = 70     // Siz → Asosiy
    static let gap2: CGFloat = 110    // Asosiy → yordamchilar
    static let rowGap: CGFloat = 20
    static let pad: CGFloat = 48
    static let collapseOver = 7       // shundan ko'p bo'lsa tugaganlar guruhlanadi
    static let visibleIdle = 3
}

enum GraphItem: Identifiable {
    case agent(AgentSnap)
    case group(count: Int, tokens: TokenCounts, expanded: Bool)

    var id: String {
        switch self {
        case .agent(let a): return a.id
        case .group(_, _, let e): return e ? "__collapse" : "__group"
        }
    }
    var state: AgentState {
        if case .agent(let a) = self { return a.state }
        return .idle
    }
}

private struct Edge: Identifiable {
    let id: String
    let from: CGPoint
    let to: CGPoint
    let state: AgentState
    let width: CGFloat
}

private struct ChildPos: Identifiable {
    let item: GraphItem
    let p: CGPoint
    var id: String { item.id }
}

private struct GraphLayout {
    var size: CGSize = .zero
    var trigger: CGPoint = .zero
    var main: CGPoint = .zero
    var children: [ChildPos] = []
    var edges: [Edge] = []
}

// MARK: - Ekran

struct GraphScreen: View {
    @EnvironmentObject var store: Store
    static let selectedSessionKey = "graphSession"
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""
    @State private var selectedId: String?
    @State private var showAllIdle = false

    var body: some View {
        let s = store.snap
        let session = s.sessions.first(where: { $0.id == sessionId }) ?? s.sessions.first
        VStack(spacing: 0) {
            topBar(s, session)
            Divider()
            if let session {
                HStack(spacing: 0) {
                    canvas(session)
                    if let sel = selectedId, let a = session.agents.first(where: { $0.id == sel }) {
                        Divider()
                        InspectorView(agent: a, sessionTotal: session.tokens.value(mode), mode: mode) {
                            selectedId = nil
                        }
                        .frame(width: 290)
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        EmptyStateView(symbol: "point.3.connected.trianglepath.dotted",
                                       title: "Sxema uchun sessiya yo'q",
                                       text: "Mac'da Claude Code yoki Cowork'da ish boshlansa, agentlar shu yerda tugunlar bo'lib chiqadi.")
                        SourcesList(sources: s.sources).card()
                    }
                    .padding(20)
                }
            }
        }
        .onChange(of: sessionId) { _ in selectedId = nil; showAllIdle = false }
    }

    // MARK: Yuqori panel

    @ViewBuilder
    private func topBar(_ s: Snapshot, _ session: SessionSnap?) -> some View {
        HStack(spacing: 12) {
            if !s.sessions.isEmpty {
                Picker("Sessiya", selection: Binding(
                    get: { session?.id ?? "" },
                    set: { sessionId = $0 })) {
                    ForEach(s.sessions) { ss in
                        Text(sessionLabel(ss)).tag(ss.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 360)
            }
            Spacer()
            if let session {
                Text("Sessiya: \(Fmt.tokens(session.tokens.value(mode))) token")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
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

    @ViewBuilder
    private func canvas(_ session: SessionSnap) -> some View {
        let items = graphItems(session)
        GeometryReader { geo in
            let layout = makeLayout(session, items, viewport: geo.size)
            ScrollView([.horizontal, .vertical]) {
                ZStack(alignment: .topLeading) {
                    DotGrid().frame(width: layout.size.width, height: layout.size.height)
                    EdgesView(edges: layout.edges).frame(width: layout.size.width, height: layout.size.height)
                        .allowsHitTesting(false)

                    TriggerNode(text: session.title)
                        .position(layout.trigger)

                    if let main = session.agents.first(where: { $0.isMain }) {
                        AgentNode(agent: main, isMain: true, tokens: main.tokens.value(mode),
                                  share: Fmt.percent(main.tokens.value(mode), of: session.tokens.value(mode)),
                                  extra: session.contextTokens > 0 ? "Kontekst \(Fmt.tokens(Double(session.contextTokens)))" : nil,
                                  selected: selectedId == main.id)
                            .position(layout.main)
                            .onTapGesture { toggleSelect(main.id) }
                    }

                    ForEach(layout.children) { c in
                        childNode(c.item, session).position(c.p)
                    }
                }
                .frame(width: layout.size.width, height: layout.size.height)
                .contentShape(Rectangle())
                .onTapGesture { selectedId = nil }
            }
            .background(Color(nsColor: .underPageBackgroundColor))
            .overlay(alignment: .bottomLeading) { Legend().padding(12) }
        }
    }

    @ViewBuilder
    private func childNode(_ item: GraphItem, _ session: SessionSnap) -> some View {
        switch item {
        case .agent(let a):
            AgentNode(agent: a, isMain: false, tokens: a.tokens.value(mode),
                      share: Fmt.percent(a.tokens.value(mode), of: session.tokens.value(mode)),
                      extra: nil, selected: selectedId == a.id)
                .onTapGesture { toggleSelect(a.id) }
        case .group(let count, let tokens, let expanded):
            GroupNode(count: count, tokens: tokens.value(mode), expanded: expanded)
                .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { showAllIdle.toggle() } }
        }
    }

    private func toggleSelect(_ id: String) {
        selectedId = selectedId == id ? nil : id
    }

    // MARK: Ma'lumot → tugunlar

    private func graphItems(_ session: SessionSnap) -> [GraphItem] {
        let subs = session.agents.filter { !$0.isMain }   // eng yangisi birinchi
        guard subs.count > G.collapseOver else { return subs.map { GraphItem.agent($0) } }
        let idle = subs.filter { $0.state == .idle }
        let keepIdle = Set(idle.prefix(G.visibleIdle).map(\.id))
        let hidden = idle.filter { !keepIdle.contains($0.id) }
        guard !hidden.isEmpty else { return subs.map { GraphItem.agent($0) } }
        if showAllIdle {
            return subs.map { GraphItem.agent($0) } + [GraphItem.group(count: hidden.count, tokens: TokenCounts(), expanded: true)]
        }
        var sum = TokenCounts()
        hidden.forEach { sum.add($0.tokens) }
        let hiddenIds = Set(hidden.map(\.id))
        return subs.filter { !hiddenIds.contains($0.id) }.map { GraphItem.agent($0) }
            + [GraphItem.group(count: hidden.count, tokens: sum, expanded: false)]
    }

    private func makeLayout(_ session: SessionSnap, _ items: [GraphItem], viewport: CGSize) -> GraphLayout {
        var l = GraphLayout()
        let n = CGFloat(items.count)
        let colH = n > 0 ? n * G.nodeH + (n - 1) * G.rowGap : 0
        let contentH = max(colH, G.nodeH) + 2 * G.pad
        let contentW = G.pad * 2 + G.trigW + G.gap1 + G.nodeW + (items.isEmpty ? 0 : G.gap2 + G.nodeW)
        let w = max(contentW, viewport.width)
        let h = max(contentH, viewport.height)
        l.size = CGSize(width: w, height: h)

        // Kontent kichik bo'lsa o'rtaga joylashadi
        let ox = (w - contentW) / 2
        let midY = h / 2
        l.trigger = CGPoint(x: ox + G.pad + G.trigW / 2, y: midY)
        let mainX = ox + G.pad + G.trigW + G.gap1 + G.nodeW / 2
        l.main = CGPoint(x: mainX, y: midY)

        let mainState = session.agents.first(where: { $0.isMain })?.state ?? .idle
        l.edges.append(Edge(id: "trigger", from: CGPoint(x: l.trigger.x + G.trigW / 2, y: midY),
                            to: CGPoint(x: mainX - G.nodeW / 2, y: midY), state: mainState, width: 2))

        let childX = mainX + G.nodeW / 2 + G.gap2 + G.nodeW / 2
        let top = midY - colH / 2
        let maxTok = items.compactMap { item -> Double? in
            if case .agent(let a) = item { return a.tokens.value(mode) }
            return nil
        }.max() ?? 0
        for (i, item) in items.enumerated() {
            let y = top + CGFloat(i) * (G.nodeH + G.rowGap) + G.nodeH / 2
            let p = CGPoint(x: childX, y: y)
            l.children.append(ChildPos(item: item, p: p))
            var width: CGFloat = 1.5
            if case .agent(let a) = item, maxTok > 0 {
                width = 1.5 + 3.5 * CGFloat(sqrt(a.tokens.value(mode) / maxTok))
            }
            l.edges.append(Edge(id: item.id, from: CGPoint(x: mainX + G.nodeW / 2, y: midY),
                                to: CGPoint(x: childX - G.nodeW / 2, y: y), state: item.state, width: width))
        }
        return l
    }
}

// MARK: - Chiziqlar

private struct EdgesView: View {
    let edges: [Edge]

    var body: some View {
        let anyLive = edges.contains { $0.state == .running }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !anyLive)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, _ in
                for e in edges {
                    let path = curve(e.from, e.to)
                    let color = Palette.state(e.state)
                    switch e.state {
                    case .running:
                        g.stroke(path, with: .color(color.opacity(0.3)), lineWidth: e.width)
                        g.stroke(path, with: .color(color),
                                 style: StrokeStyle(lineWidth: e.width + 2.5, lineCap: .round,
                                                    dash: [0.1, 14], dashPhase: CGFloat(-t * 45)))
                    case .waiting:
                        g.stroke(path, with: .color(color.opacity(0.8)),
                                 style: StrokeStyle(lineWidth: e.width, lineCap: .round, dash: [6, 5]))
                    case .idle:
                        g.stroke(path, with: .color(Color.secondary.opacity(0.45)), lineWidth: e.width)
                    }
                    // Kirish porti (strelka o'rnida kichik doira)
                    let r: CGFloat = 4
                    g.fill(Path(ellipseIn: CGRect(x: e.to.x - r, y: e.to.y - r, width: r * 2, height: r * 2)),
                           with: .color(e.state == .idle ? Color.secondary.opacity(0.6) : color))
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
    let state: AgentState
    let selected: Bool
    let width: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(10)
            .frame(width: width, height: height, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .stroke(selected ? Color.accentColor : Color.primary.opacity(0.14), lineWidth: selected ? 2 : 1))
            .overlay(RunningGlow(active: state == .running))
            .overlay(alignment: .leading) { Port().offset(x: -4) }
            .overlay(alignment: .trailing) { Port().offset(x: 4) }
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
    var body: some View {
        if active {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.green.opacity(0.55 + 0.45 * sin(t * 3)), lineWidth: 2)
                    .shadow(color: .green.opacity(0.45), radius: 8)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct AgentNode: View {
    let agent: AgentSnap
    let isMain: Bool
    let tokens: Double
    let share: String
    let extra: String?
    let selected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            IconTile(symbol: agentSymbol(agent), tint: isMain ? Palette.main : Palette.agents)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(isMain ? "Asosiy agent" : agent.title)
                        .font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 4)
                    StateDot(state: agent.state)
                }
                Text(agent.subtitle.isEmpty ? (isMain ? "" : "yordamchi") : agent.subtitle)
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                Text(agent.lastAction)
                    .font(.caption)
                    .foregroundStyle(agent.state == .idle ? Color.secondary : Color.primary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(Fmt.tokens(tokens)).font(.caption.weight(.semibold)).monospacedDigit()
                    Text(share).font(.caption2).foregroundStyle(.secondary).monospacedDigit()
                    Spacer(minLength: 0)
                    if let extra { Text(extra).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
                }
            }
        }
        .modifier(NodeChrome(state: agent.state, selected: selected, width: G.nodeW, height: G.nodeH))
        .help("Bosing — tafsilotlar")
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
        .padding(10)
        .frame(width: G.trigW, height: G.trigH, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.14), lineWidth: 1))
        .overlay(alignment: .trailing) { Port().offset(x: 4) }
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
}

private struct GroupNode: View {
    let count: Int
    let tokens: Double
    let expanded: Bool
    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: expanded ? "chevron.up" : "square.stack.3d.up.fill", tint: Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(expanded ? "Tugaganlarni yig'ish" : "+\(count) ta tugagan agent")
                    .font(.callout.weight(.semibold))
                Text(expanded ? "\(count) ta tugagan agentni yashirish" : "Jami \(Fmt.tokens(tokens)) token · bosib oching")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(width: G.nodeW, height: G.nodeH * 0.7, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.primary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .overlay(alignment: .leading) { Port().offset(x: -4) }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct Legend: View {
    var body: some View {
        HStack(spacing: 12) {
            item(.running, "Ishlayapti")
            item(.waiting, "Natija kutyapti")
            item(.idle, "Tugagan")
            Text("Chiziq qalinligi = token").foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
    }
    private func item(_ s: AgentState, _ t: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Palette.state(s)).frame(width: 7, height: 7)
            Text(t)
        }
    }
}

// MARK: - Tafsilotlar paneli

private struct InspectorView: View {
    let agent: AgentSnap
    let sessionTotal: Double
    let mode: CountMode
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    IconTile(symbol: agentSymbol(agent),
                             tint: agent.isMain ? Palette.main : Palette.agents)
                    Spacer()
                    Button(action: onClose) { Image(systemName: "xmark") }
                        .buttonStyle(.borderless)
                        .help("Yopish")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.isMain ? "Asosiy agent" : agent.title)
                        .font(.headline).fixedSize(horizontal: false, vertical: true)
                    if !agent.subtitle.isEmpty {
                        Text(agent.subtitle).font(.caption).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        StateDot(state: agent.state)
                        Text(agent.state.title).font(.caption)
                    }
                }

                block("Hozirgi harakat") { Text(agent.lastAction).font(.callout) }

                block("Tokenlar") {
                    VStack(spacing: 6) {
                        row("Jami", Fmt.tokens(Double(agent.tokens.total)), bold: true)
                        row("Vaznli (taxminiy)", Fmt.tokens(agent.tokens.weighted))
                        row("Sessiyadagi ulushi", Fmt.percent(agent.tokens.value(mode), of: sessionTotal))
                        Divider()
                        row("Kesh o'qish (qayta o'qish)", Fmt.tokens(Double(agent.tokens.cacheRead)))
                        row("Kesh yozish (yangi kontekst)", Fmt.tokens(Double(agent.tokens.cacheWrite)))
                        row("Kiritish", Fmt.tokens(Double(agent.tokens.input)))
                        row("Javob va fikrlash", Fmt.tokens(Double(agent.tokens.output)))
                        if agent.tokens.thinking > 0 {
                            row("  shundan fikrlash", Fmt.tokens(Double(agent.tokens.thinking)))
                        }
                    }
                }

                block("Faollik") {
                    VStack(spacing: 6) {
                        row("API chaqiruvlar", "\(agent.calls)")
                        row("Boshlangan", agent.firstActivity.map { Fmt.clock.string(from: $0) } ?? "—")
                        row("Oxirgi harakat", Fmt.ago(agent.lastActivity))
                    }
                }

                if !agent.topTools.isEmpty {
                    block("Asboblar") {
                        VStack(spacing: 6) {
                            ForEach(agent.topTools.prefix(8), id: \.name) { t in row(t.name, "\(t.count)") }
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func block<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
    }

    private func row(_ k: String, _ v: String, bold: Bool = false) -> some View {
        HStack {
            Text(k).font(.caption)
            Spacer()
            Text(v).font(bold ? .caption.weight(.semibold) : .caption).monospacedDigit()
        }
    }
}
