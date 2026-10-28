import SwiftUI
import TokenKuzatCore

struct SessionsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @State private var query = ""
    @State private var expanded: Set<String> = []
    @State private var touched = false

    var body: some View {
        let all = store.snap.sessions
        let list = query.isEmpty ? all : all.filter {
            $0.project.localizedCaseInsensitiveContains(query) || $0.title.localizedCaseInsensitiveContains(query)
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tr("Oxirgi 7 kun · \(all.count) ta sessiya", "Last 7 days · \(all.count == 1 ? "1 session" : "\(all.count) sessions")")).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    TextField(tr("Loyiha yoki so'rov bo'yicha qidirish", "Search by project or prompt"), text: $query)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 280)
                }
                if list.isEmpty {
                    EmptyStateView(symbol: all.isEmpty ? "moon.zzz" : "magnifyingglass",
                                   title: all.isEmpty ? tr("Sessiya yo'q", "No sessions") : tr("Hech narsa topilmadi", "Nothing found"),
                                   text: all.isEmpty
                                       ? tr("Mac'dagi Claude Code yoki Cowork sessiyalari shu yerda chiqadi. Bulutdagi sessiyalar Mac'ga yozilmaydi.", "Claude Code and Cowork sessions on this Mac show up here. Cloud sessions aren't saved to this Mac.")
                                       : tr("Boshqa so'z bilan qidirib ko'ring.", "Try a different search."))
                        .card()
                    if all.isEmpty { SourcesList(sources: store.snap.sources).card() }
                } else {
                    ForEach(list) { sess in
                        // Foydalanuvchi hech narsa bosmaguncha eng so'nggi sessiya ochiq turadi
                        let isOpen = touched ? expanded.contains(sess.id) : sess.id == all.first?.id
                        SessionCard(session: sess, mode: mode, expanded: isOpen,
                                    costUSD: store.snap.limits?.costBySession[sess.id]) {
                            if !touched, let first = all.first?.id { expanded.insert(first); touched = true }
                            if expanded.contains(sess.id) { expanded.remove(sess.id) } else { expanded.insert(sess.id) }
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}

struct SessionCard: View {
    let session: SessionSnap
    let mode: CountMode
    let expanded: Bool
    var costUSD: Double? = nil
    let onToggle: () -> Void

    var body: some View {
        let total = session.tokens.value(mode)
        let slices = Composition.session(session, mode)
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { onToggle() } }) {
                HStack(spacing: 12) {
                    StateDot(state: session.state)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.project).font(.headline).lineLimit(1)
                        Text(session.title).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(Fmt.tokens(total)).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text(Fmt.ago(session.lastActivity)).font(.caption).foregroundStyle(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            BreakdownBar(slices: slices, height: expanded ? 10 : 6)

            if expanded {
                HStack(spacing: 6) {
                    if !session.model.isEmpty { Chip(text: session.model, symbol: "cpu") }
                    if session.contextTokens > 0 {
                        Chip(text: tr("Kontekst \(Fmt.tokens(session.contextTokens))", "Context \(Fmt.tokens(session.contextTokens))"), symbol: "text.alignleft")
                    }
                    Chip(text: tr("\(session.helperCount) yordamchi agent", session.helperCount == 1 ? "1 subagent" : "\(session.helperCount) subagents"), symbol: "person.2")
                    if let cost = costUSD {
                        Chip(text: String(format: "$%.2f", cost).replacingOccurrences(of: ".", with: ","), symbol: "dollarsign.circle")
                            .help(tr("Claude Code hisoblagan taxminiy narx (API narxlarida)", "Estimated cost calculated by Claude Code (at API prices)"))
                    }
                    Spacer()
                    Button {
                        UserDefaults.standard.set(session.id, forKey: GraphScreen.selectedSessionKey)
                        WindowManager.shared.show(.graph)
                    } label: {
                        Label(tr("Sxemada ochish", "Open in map"), systemImage: "point.3.connected.trianglepath.dotted")
                    }
                    .buttonStyle(.link).font(.caption)
                }
                BreakdownLegend(slices: slices, total: total)
                Divider()
                VStack(spacing: 12) {
                    ForEach(session.agents) { AgentRow(agent: $0, sessionTotal: total, mode: mode) }
                }
            }
        }
        .card(padding: 16, highlight: session.state == .running ? .green : nil)
    }
}

struct AgentRow: View {
    let agent: AgentSnap
    let sessionTotal: Double
    let mode: CountMode

    var body: some View {
        let v = agent.tokens.value(mode)
        HStack(alignment: .top, spacing: 12) {
            IconTile(symbol: agentSymbol(agent), tint: agent.isMain ? Palette.main : Palette.agents, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.isMain ? tr("Asosiy agent", "Main agent") : agent.title).font(.callout.weight(.medium)).lineLimit(1)
                    if !agent.subtitle.isEmpty { Chip(text: agent.subtitle) }
                    StateDot(state: agent.state, size: 7)
                }
                Text(agent.lastAction).font(.caption)
                    .foregroundStyle(agent.state == .idle ? Color.secondary : Color.primary).lineLimit(1)
                if !agent.toolsLine.isEmpty {
                    Text(agent.toolsLine).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(Fmt.tokens(v)).font(.callout.weight(.medium)).monospacedDigit()
                Text(tr("\(Fmt.percent(v, of: sessionTotal)) · \(agent.calls) chaqiruv", "\(Fmt.percent(v, of: sessionTotal)) · \(agent.calls == 1 ? "1 call" : "\(agent.calls) calls")"))
                    .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            }
        }
    }
}

/// Qaysi papkalar o'qilayotgani — sessiya topilmasa nosozlikni tushunish uchun
struct SourcesList: View {
    let sources: [SourceInfo]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(tr("Manbalar", "Sources")).font(.headline)
            ForEach(sources) { src in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: src.exists ? (src.recent > 0 ? "checkmark.circle.fill" : "circle") : "xmark.circle")
                        .foregroundStyle(src.exists ? (src.recent > 0 ? Color.green : Color.secondary) : Color.secondary.opacity(0.6))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(src.path).font(.caption.monospaced()).lineLimit(1).truncationMode(.middle)
                        Text(detail(src)).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func detail(_ s: SourceInfo) -> String {
        guard s.exists else { return tr("Papka yo'q", "No folder") }
        guard s.total > 0 else { return tr("Papka bor, lekin sessiya fayli yo'q", "Folder exists, but no session files") }
        let last = s.latest.map { Fmt.dayTime.string(from: $0) } ?? "—"
        return tr("Jami \(s.total) fayl · 30 kunda \(s.recent) · bugun \(s.today) · oxirgisi: \(last)", "\(s.total == 1 ? "1 file" : "\(s.total) files") total · \(s.recent) in 30 days · \(s.today) today · latest: \(last)")
    }
}
