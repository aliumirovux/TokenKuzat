import SwiftUI
import AppKit
import TokenKuzatCore

// Agentlar sxemasi: chapda n8n uslubidagi jarayon oqimi (FlowCanvas), o'ngda tanlangan tugun tafsiloti —
// so'rovlar bo'yicha jarayon lentasi (har bir qadam, davomiyligi, natijasi) va resurslar ro'yxati.

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

    var body: some View {
        let s = store.snap
        let session = s.sessions.first(where: { $0.id == sessionId }) ?? s.sessions.first
        VStack(spacing: 0) {
            topBar(s, session)
            Divider()
            if let session {
                HStack(spacing: 0) {
                    let turn = effectiveTurn(session)
                    let flow = FlowModel(session: session, turnId: turn, now: s.updatedAt)
                    if graphMode == "files" {
                        let tl = TimelineModel(flow: flow, session: session, turnId: turn, now: s.updatedAt)
                        FileHeatmapScreen(model: HeatmapModel(timeline: tl)) { f in
                            if let owner = f.ownerId { select(.resource(agentId: owner, category: .files)) }
                        }
                    } else if graphMode == "timeline" {
                        TimelineScreen(model: TimelineModel(flow: flow, session: session, turnId: turn, now: s.updatedAt),
                                       selectedAgent: currentSelection(session)?.agentId,
                                       onSelectAgent: { select(.agent($0)) },
                                       onSelectStep: { a, st in select(.resource(agentId: a.id, category: st.category)) })
                    } else {
                    FlowCanvas(session: session, model: flow,
                               mode: mode,
                               selectedAgent: currentSelection(session)?.agentId,
                               selectedBubble: selectedBubbleId(session),
                               onSelectAgent: { select(.agent($0)) },
                               onSelectBubble: { b in
                                   if let c = b.category { select(.resource(agentId: b.ownerId, category: c)) }
                                   else { select(.agent(b.ownerId)) }
                               })
                    }
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
                                       text: "Mac'da Claude Code yoki Cowork'da ish boshlansa, jarayon shu yerda n8n kabi oqim bo'lib chiqadi: so'rov → agent → asboblar → natija.")
                        SourcesList(sources: s.sources).card()
                    }
                    .padding(20)
                }
            }
        }
        .onChange(of: sessionId) { _ in selection = nil; turnId = nil }
    }

    // MARK: Yuqori panel

    private func topBar(_ s: Snapshot, _ session: SessionSnap?) -> some View {
        HStack(spacing: 12) {
            if !s.sessions.isEmpty {
                Picker("Sessiya", selection: Binding(get: { session?.id ?? "" }, set: { sessionId = $0 })) {
                    ForEach(s.sessions) { Text(sessionLabel($0)).tag($0.id) }
                }
                .labelsHidden()
                .frame(minWidth: 140, maxWidth: 260)
            }
            if let session, !session.turns.isEmpty { turnPicker(session) }
            Spacer()
            Picker("Ko'rinish", selection: $graphMode) {
                Label("Oqim", systemImage: "point.3.connected.trianglepath.dotted").tag("flow")
                Label("Vaqt", systemImage: "chart.bar.doc.horizontal").tag("timeline")
                Label("Fayllar", systemImage: "square.grid.3x3.fill").tag("files")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .help("Oqim — jarayon sxemasi, Vaqt — qadamlar vaqt chizig'ida, Fayllar — issiqlik xaritasi")
            if let session {
                let steps = session.agents.reduce(0) { $0 + $1.steps.count }
                // Joy tor bo'lsa birinchi bo'lib shu yozuv qisqaradi
                Text("\(session.turns.count) so'rov · \(steps) qadam · \(Fmt.tokens(session.tokens.value(mode)))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    .lineLimit(1).truncationMode(.head).layoutPriority(-1)
            }
            Button { withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() } } label: {
                Image(systemName: "sidebar.right")
            }
            .buttonStyle(.borderless)
            .help(showInspector ? "Tafsilotlarni yashirish" : "Tafsilotlarni ko'rsatish")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    /// ‹ #9 so'rov › — oldingi/keyingi so'rov va ro'yxat
    private func turnPicker(_ session: SessionSnap) -> some View {
        let current = effectiveTurn(session)
        let last = session.turns.count
        return HStack(spacing: 4) {
            Button { turnId = max(1, (current ?? last) - 1) } label: { Image(systemName: "chevron.left") }
                .buttonStyle(.borderless)
                .disabled(current == 1)
                .help("Oldingi so'rov")
            // Picker o'z uslubida (bordered menu) — borderless'da matn chegaradan chiqib, strelkalarni yopib qo'yadi
            Picker("So'rov", selection: Binding(get: { current ?? 0 }, set: { turnId = $0 == last ? nil : $0 })) {
                ForEach(session.turns.reversed()) { t in
                    Text("#\(t.id) · \(t.prompt.count > 32 ? String(t.prompt.prefix(32)) + "…" : t.prompt)").tag(t.id)
                }
                Divider()
                Text("Butun sessiya").tag(0)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 210)
            .clipped()
            Button { if let c = current { turnId = c + 1 >= last ? nil : c + 1 } } label: { Image(systemName: "chevron.right") }
                .buttonStyle(.borderless)
                .disabled(current == nil || current == last)
                .help("Keyingi so'rov")
        }
        .layoutPriority(1)
    }

    /// Tanlangan so'rov raqami; nil — butun sessiya
    private func effectiveTurn(_ session: SessionSnap) -> Int? {
        switch turnId {
        case 0?: return nil
        case let id? where session.turns.contains(where: { $0.id == id }): return id
        default: return session.turns.last?.id
        }
    }

    private func sessionLabel(_ ss: SessionSnap) -> String {
        var mark = ss.state == .running ? "● " : (ss.state == .waiting ? "◐ " : "")
        if let la = ss.lastActivity, !Calendar.current.isDateInToday(la) {
            mark += Fmt.dayTime.string(from: la) + " · "
        }
        let t = ss.title.count > 36 ? String(ss.title.prefix(36)) + "…" : ss.title
        return "\(mark)\(ss.project) — \(t)"
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

                InspectorBlock(title: "JARAYON", trailing: trailing) {
                    if agent.steps.isEmpty && (!agent.isMain || turns.isEmpty) {
                        Text("Hali asbob chaqirilmagan.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        TurnTimeline(steps: agent.steps, turns: turns, showEmptyTurns: agent.isMain, mode: mode)
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
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if toggled.contains(g.id) { toggled.remove(g.id) } else { toggled.insert(g.id) }
                        }
                    } label: { header(g, open: open) }
                    .buttonStyle(.plain)
                    if open {
                        if g.steps.isEmpty {
                            Text("Asbob chaqirilmadi — faqat javob yozildi.")
                                .font(.caption2).foregroundStyle(.secondary).padding(.leading, 26)
                        } else {
                            StepTimeline(steps: g.steps).padding(.leading, 4)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(g.turn?.active == true ? 0.07 : 0.04)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(g.turn?.active == true ? Color.green.opacity(0.4) : .clear))
            }
            if gs.count > 40 {
                Text("Yana \(gs.count - 40) ta eski so'rov").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private func header(_ g: Group, open: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(g.turn.map { "#\($0.id)" } ?? "—")
                .font(.caption2.weight(.bold)).monospacedDigit()
                .foregroundStyle(Palette.cacheRead)
                .frame(minWidth: 18, alignment: .leading)
            VStack(alignment: .leading, spacing: 3) {
                Text(g.turn?.prompt ?? "So'rovdan oldingi qadamlar")
                    .font(.caption.weight(.medium)).lineLimit(open ? 3 : 1)
                    .multilineTextAlignment(.leading)
                if let t = g.turn {
                    HStack(spacing: 6) {
                        if t.active { ProgressView().controlSize(.mini) }
                        Text(Fmt.hourMinute.string(from: t.start))
                        Text("· " + Dur.text(t.duration))
                        Text("· \(Fmt.tokens(t.tokens.value(mode)))")
                        Text("· \(t.steps) qadam")
                        if t.errors > 0 { Text("· \(t.errors) xato").foregroundStyle(.red) }
                    }
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.75)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
                .rotationEffect(.degrees(open ? 90 : 0))
        }
        .contentShape(Rectangle())
    }
}
