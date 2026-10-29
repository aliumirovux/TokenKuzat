import SwiftUI
import TokenKuzatCore

struct SessionsView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.weighted
    @State private var query = ""
    @State private var expanded: Set<String> = []
    @State private var touched = false
    /// «recent» — eng so'nggisi tepada, «cost» — eng ko'p sarflagani tepada
    @AppStorage("sessions.sort") private var sort = "recent"

    var body: some View {
        let all = store.snap.sessions
        let found = query.isEmpty ? all : all.filter {
            $0.project.localizedCaseInsensitiveContains(query) || $0.title.localizedCaseInsensitiveContains(query)
        }
        // Saralash va chiziq uzunligi narx bo'yicha — limitni aynan shu yeydi
        let list = sort == "cost" ? found.sorted { $0.tokens.weighted > $1.tokens.weighted } : found
        let top = all.map { $0.tokens.value(mode) }.max() ?? 0
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tr("Oxirgi 7 kun · \(all.count) ta sessiya", "Last 7 days · \(all.count == 1 ? "1 session" : "\(all.count) sessions")")).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    PillSegments(selection: $sort, items: [
                        .init(id: "recent", title: tr("Eng so'nggi", "Most recent")),
                        .init(id: "cost", title: tr("Eng qimmat", "Most expensive")),
                    ], compact: true)
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
                    // «Eng so'nggi» — kunlar bo'yicha guruhlar, «Eng qimmat» — bitta ro'yxat
                    ForEach(sort == "recent" ? Self.byDay(list) : [("", list)], id: \.0) { day, items in
                        if !day.isEmpty {
                            Text(day).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                                .padding(.top, 8).padding(.leading, 4)
                        }
                        ForEach(items) { sess in
                            // Foydalanuvchi hech narsa bosmaguncha eng so'nggi sessiya ochiq turadi
                            let isOpen = touched ? expanded.contains(sess.id) : sess.id == all.first?.id
                            SessionCard(session: sess, mode: mode, expanded: isOpen,
                                        costUSD: store.snap.limits?.costBySession[sess.id],
                                        tokensPerPct: store.snap.outside?.tokensPerPct, top: top) {
                                if !touched, let first = all.first?.id { expanded.insert(first); touched = true }
                                if expanded.contains(sess.id) { expanded.remove(sess.id) } else { expanded.insert(sess.id) }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    /// Sessiyalar oxirgi faollik kuni bo'yicha: «Bugun», «Kecha», keyin sana
    static func byDay(_ list: [SessionSnap], now: Date = Date()) -> [(String, [SessionSnap])] {
        let cal = Calendar.current
        var groups: [(String, [SessionSnap])] = []
        for s in list {
            let d = s.lastActivity ?? now
            let name = cal.isDateInToday(d) ? tr("Bugun", "Today")
                : cal.isDateInYesterday(d) ? tr("Kecha", "Yesterday")
                : Fmt.longDay.string(from: d)
            if groups.last?.0 == name { groups[groups.count - 1].1.append(s) } else { groups.append((name, [s])) }
        }
        return groups
    }
}

struct SessionCard: View {
    let session: SessionSnap
    let mode: CountMode
    let expanded: Bool
    var costUSD: Double? = nil
    /// 1% 5 soatlik limit ≈ shuncha vaznli token (o'rganilgan bo'lsa)
    var tokensPerPct: Double? = nil
    /// Ro'yxatdagi eng katta sessiya — yig'iq chiziq shunga nisbatan
    var top: Double = 0
    let onToggle: () -> Void

    var body: some View {
        let total = session.tokens.value(mode)
        let slices = Composition.plain(Composition.session(session, mode))
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation(.easeInOut(duration: 0.18)) { onToggle() } }) {
                HStack(spacing: 12) {
                    StateDot(state: session.state)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(session.project).font(.headline).lineLimit(1)
                            if session.state != .idle {
                                Text(tr("Ishlayapti", "Working")).font(.caption.weight(.semibold)).foregroundStyle(Brand.ok)
                            }
                        }
                        Text(session.title).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 10)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(headline).font(.system(.title3, design: .rounded).weight(.semibold)).monospacedDigit()
                        Text(subline(total)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .help(tr("Sessiya 5 soatlik limitning qanchasiga teng (o'tgan sarfdan o'rganilgan taxmin). Token soni pastda.", "How much of a 5-hour limit this session equals (estimated from past usage). Token count below."))
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                BreakdownBar(slices: slices, height: 10)
            } else {
                // Yig'iq holatda tarkib emas, hajm: sessiyalarni bir qarashda solishtirish uchun
                GeometryReader { geo in
                    Capsule().fill(Color.primary.opacity(0.06))
                        .overlay(alignment: .leading) {
                            Capsule().fill(Palette.main.opacity(session.state == .running ? 1 : 0.7))
                                .frame(width: max(6, geo.size.width * (top > 0 ? total / top : 0)))
                        }
                }
                .frame(height: 6)
            }

            if expanded {
                HStack(spacing: 6) {
                    if !session.model.isEmpty { Chip(text: session.model, symbol: "cpu") }
                    if session.contextTokens > 0 {
                        Chip(text: tr("Kontekst \(Fmt.tokens(session.contextTokens))", "Context \(Fmt.tokens(session.contextTokens))"), symbol: "text.alignleft")
                    }
                    if session.helperCount > 0 {
                        Chip(text: tr("\(session.helperCount) yordamchi agent", session.helperCount == 1 ? "1 subagent" : "\(session.helperCount) subagents"), symbol: "person.2")
                    }
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
                if let insight = Self.insight(session) {
                    Label(insight, systemImage: "lightbulb")
                        .font(.callout).fixedSize(horizontal: false, vertical: true)
                        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.main.opacity(0.1)))
                }
                BreakdownLegend(slices: slices.filter { $0.id != "agents" || $0.value > 0 }, total: total, inlineHints: true)
                // Faqat asosiy agent bo'lsa — «100%» qatori hech narsa qo'shmaydi
                if session.agents.count > 1 {
                    Divider()
                    VStack(spacing: 12) {
                        ForEach(session.agents) { AgentRow(agent: $0, sessionTotal: total, mode: mode) }
                    }
                }
            }
        }
        .card(padding: 16, highlight: session.state == .running ? Brand.ok : nil)
    }

    /// Asosiy raqam: limit ulushi → narx → token (nima ma'lum bo'lsa)
    private var headline: String {
        if let per = tokensPerPct, per > 0 {
            let pct = session.tokens.weighted / per
            return pct < 1 ? tr("5 soatlik limitning <1%", "<1% of 5-h limit") : tr("5 soatlik limitning \(Int(pct.rounded()))%", "\(Int(pct.rounded()))% of 5-h limit")
        }
        if let c = costUSD { return String(format: "$%.2f", c).replacingOccurrences(of: ".", with: ",") }
        return tr("\(Fmt.tokens(session.tokens.value(mode))) token", "\(Fmt.tokens(session.tokens.value(mode))) tokens")
    }

    private func subline(_ total: Double) -> String {
        let ago = Fmt.ago(session.lastActivity)
        guard tokensPerPct != nil || costUSD != nil else { return ago }
        let unit = mode == .weighted ? tr("token (narx bo'yicha)", "tokens (by price)") : tr("token", "tokens")
        return "\(Fmt.tokens(total)) \(unit) · \(ago)"
    }

    /// Bitta xulosa: limit asosan nimaga ketgani va nima qilsa bo'ladi (narx bo'yicha hisoblanadi)
    static func insight(_ s: SessionSnap) -> String? {
        let w = Composition.session(s, .weighted)
        let sum = w.reduce(0) { $0 + $1.value }
        guard sum > 0 else { return nil }
        func share(_ id: String) -> Double { (w.first { $0.id == id }?.value ?? 0) / sum }
        let read = share("read"), agents = share("agents"), out = share("out")
        if read >= 0.4 && s.contextTokens >= 150_000 {
            return tr("Limitning \(Int((read * 100).rounded()))% i suhbatni qayta o'qishga ketdi: kontekst \(Fmt.tokens(Double(s.contextTokens))) ga yetgan va har javobda butun suhbat qayta o'qiladi. Yangi sessiyada davom etsangiz, har javob arzonlashadi.",
                      "\(Int((read * 100).rounded()))% went to re-reading the conversation: the context reached \(Fmt.tokens(Double(s.contextTokens))) and the whole conversation is re-read on every reply. Continuing in a new session makes each reply cheaper.")
        }
        if agents >= 0.4 {
            return tr("Limitning \(Int((agents * 100).rounded()))% i yordamchi agentlarga ketdi. Kichik vazifalar uchun ularsiz ishlash arzonroq.",
                      "\(Int((agents * 100).rounded()))% went to subagents. Small tasks are cheaper without them.")
        }
        if out >= 0.4 {
            return tr("Limitning \(Int((out * 100).rounded()))% i Claude javobi va fikrlashiga ketdi — bu eng qimmat qism. Qisqaroq javob so'rash yoki fikrlash darajasini pasaytirish tejaydi.",
                      "\(Int((out * 100).rounded()))% went to Claude's replies and thinking — the most expensive part. Asking for shorter replies or lowering the thinking level saves the most.")
        }
        if read >= 0.4 {
            return tr("Limitning \(Int((read * 100).rounded()))% i suhbatni qayta o'qishga ketdi. Suhbat uzaygan sari bu ulush o'sadi.",
                      "\(Int((read * 100).rounded()))% went to re-reading the conversation. This share grows as the conversation gets longer.")
        }
        return nil
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
                        .foregroundStyle(src.exists ? (src.recent > 0 ? Brand.ok : Color.secondary) : Color.secondary.opacity(0.6))
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
