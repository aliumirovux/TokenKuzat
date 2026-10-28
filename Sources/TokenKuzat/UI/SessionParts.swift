import SwiftUI
import TokenKuzatCore

// Sessiya sahifasining qismlari (Browserbase run sahifasi andozasida):
// sarlavha + KPI'lar → so'rov chiplari → qatorli vaqt chizig'i (Model / asbob turlari) → tablar.

// MARK: - Sarlavha

struct SessionHeader: View {
    let session: SessionSnap
    let turn: TurnSnap?
    let mode: CountMode
    let costUSD: Double?
    /// Claude ruxsat so'rab to'xtagan bo'lsa — hook xabari
    var waiting: HookNotice? = nil

    var body: some View {
        let duration = turn?.duration ?? session.timeRange.map { $0.upperBound.timeIntervalSince($0.lowerBound) } ?? 0
        let steps = turn?.steps ?? session.agents.reduce(0) { $0 + $1.steps.count }
        let tokens = turn?.tokens ?? session.tokens
        let active = turn?.active ?? (session.state != .idle)
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                // Uzun so'rov matni sarlavhada emas — u xaritadagi kartada. Sarlavha qisqa: loyiha va holat
                HStack(spacing: 12) {
                    ProjectAvatar(name: session.project, size: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.project)
                            .font(.system(size: 22, weight: .semibold, design: .rounded)).lineLimit(1)
                        Text(session.turns.isEmpty ? "Sessiya" : "Sessiya · \(session.turns.count) so'rov")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
                HStack(spacing: 14) {
                    StatusChip(active: active, errors: turn?.errors ?? 0, waiting: waiting != nil)
                    if session.contextTokens > 0 { ContextGauge(session: session) }
                    if let turn { Text("#\(turn.id)-so'rov").fontWeight(.semibold).foregroundStyle(.primary) }
                    if !session.model.isEmpty { Text(session.model) }
                    if let start = turn?.start ?? session.timeRange?.lowerBound {
                        Text("\(Fmt.hourMinute.string(from: start)) da boshlangan").foregroundStyle(.tertiary)
                    }
                }
                .font(.callout).foregroundStyle(.secondary)
            }
            Spacer(minLength: 16)
            HStack(spacing: 26) {
                kpi(Alerts.duration(duration), "davomiylik")
                kpi("\(steps)", "qadam")
                kpi(Fmt.tokens(tokens.value(mode)), costUSD.map { "token · " + String(format: "$%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "token")
            }
        }
        .padding(.horizontal, 24).padding(.top, 30)
    }

    private func kpi(_ v: String, _ l: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(v).font(.system(size: 22, weight: .semibold, design: .rounded)).monospacedDigit()
                .contentTransition(.numericText()).animation(Motion.smooth, value: v)
            Text(l).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StatusChip: View {
    let active: Bool
    var errors = 0
    var waiting = false

    var body: some View {
        let color = waiting ? Brand.warn : (active ? Brand.ok : (errors > 0 ? Brand.warn : Color.secondary))
        HStack(spacing: 5) {
            if waiting { Image(systemName: "hand.raised.fill") }
            else if active { StateDot(state: .running, size: 6) } else { Image(systemName: errors > 0 ? "exclamationmark.circle.fill" : "checkmark.circle.fill") }
            Text(waiting ? "Ruxsatingizni kutyapti" : (active ? "Ishlayapti" : (errors > 0 ? "Tugadi · \(errors) xato" : "Tugadi")))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(color)
        .padding(.horizontal, 9).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - So'rov chiplari

struct TurnChips: View {
    let turns: [TurnSnap]
    let selected: Int?
    let onSelect: (Int?) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    chip(nil, "Butun sessiya", active: false)
                    ForEach(turns) { t in
                        chip(t.id, "#\(t.id) · \(t.isContinuation ? "↻ davom etdi" : (t.prompt.count > 26 ? String(t.prompt.prefix(26)) + "…" : t.prompt))", active: t.active)
                            .id(t.id)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onAppear { proxy.scrollTo(selected ?? turns.last?.id, anchor: .trailing) }
        }
    }

    private func chip(_ id: Int?, _ text: String, active: Bool) -> some View {
        let on = selected == id
        return Button { withAnimation(Motion.spring) { onSelect(id) } } label: {
            HStack(spacing: 5) {
                if active { StateDot(state: .running, size: 5) }
                Text(text).lineLimit(1)
            }
            .font(.caption.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? Color.white : .secondary)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(Capsule().fill(on ? Brand.ink : Brand.surface))
            .overlay(Capsule().stroke(on ? .clear : Brand.line))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Qatorli vaqt chizig'i

/// Model va har bir asbob turi — alohida tor qator. Model qatori — asbob ishlamagan vaqt (o'ylash, javob yozish).
struct LanesCard: View {
    let timeline: TimelineModel
    let replayOn: Bool
    let onReplay: () -> Void
    /// Sukut bo'yicha yig'ilgan: bitta qator (Replay + vaqt ulushi); ochilsa — qatorli vaqt chizig'i
    @AppStorage("lanesOpen") private var open = false

    private struct Lane: Identifiable {
        let id: String
        let title: String
        let color: Color
        let spans: [(Date, Date, StepStatus)]
    }

    private var lanes: [Lane] {
        let bars = timeline.rows.flatMap(\.bars)
        var out: [Lane] = []
        // Model: asbob ishlamagan oraliqlar
        let busy = bars.map { ($0.start, $0.end) }.sorted { $0.0 < $1.0 }
        var free: [(Date, Date, StepStatus)] = []
        var cursor = timeline.start
        for (a, b) in busy {
            if a > cursor.addingTimeInterval(0.5) { free.append((cursor, a, .done)) }
            cursor = max(cursor, b)
        }
        if timeline.end > cursor.addingTimeInterval(0.5) { free.append((cursor, timeline.end, timeline.active ? .running : .done)) }
        out.append(Lane(id: "model", title: "Model", color: Brand.accent, spans: free))
        let byCat = Dictionary(grouping: bars, by: \.step.category)
        for cat in ToolCategory.allCases {
            guard let list = byCat[cat] else { continue }
            out.append(Lane(id: cat.rawValue, title: cat.title, color: cat.color,
                            spans: list.map { ($0.start, $0.end, $0.step.status) }))
        }
        return out
    }

    var body: some View {
        let ls = lanes
        let total = timeline.duration
        VStack(alignment: .leading, spacing: 8) {
            if open {
            ForEach(ls) { lane in
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle().fill(lane.color).frame(width: 7, height: 7)
                        Text(lane.title).lineLimit(1)
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(width: 118, alignment: .leading)
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Brand.sunken)
                            ForEach(Array(lane.spans.enumerated()), id: \.offset) { _, sp in
                                let x = g.size.width * CGFloat(sp.0.timeIntervalSince(timeline.start) / total)
                                let w = max(3, g.size.width * CGFloat(sp.1.timeIntervalSince(sp.0) / total))
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(sp.2 == .failed ? Brand.err : lane.color)
                                    .opacity(sp.2 == .running ? 0.55 : 0.9)
                                    .frame(width: w)
                                    .offset(x: x)
                            }
                            if timeline.active {
                                Rectangle().fill(Brand.ok).frame(width: 2).offset(x: g.size.width - 2)
                            }
                        }
                    }
                    .frame(height: 16)
                }
            }
            HStack(spacing: 12) {
                Color.clear.frame(width: 118, height: 1)
                HStack {
                    ForEach(0..<5) { i in
                        Text(Alerts.duration(total * Double(i) / 4))
                            .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : (i == 4 ? .trailing : .center))
                    }
                }
                .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
            Divider().padding(.vertical, 4)
            }
            HStack(spacing: 10) {
                Button(action: onReplay) {
                    Image(systemName: replayOn ? "stop.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Brand.ink))
                }
                .buttonStyle(.plain)
                .help(replayOn ? "Replay'ni to'xtatish" : "Bu so'rovni boshidan qayta ijro etish")
                Text("Replay").font(.callout).foregroundStyle(.secondary)
                Divider().frame(height: 16)
                shares
                Spacer(minLength: 8)
                Button { withAnimation(Motion.spring) { open.toggle() } } label: {
                    HStack(spacing: 5) {
                        Text(open ? "Yig'ish" : "Vaqt chizig'i")
                        Image(systemName: "chevron.down").rotationEffect(.degrees(open ? 180 : 0))
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Brand.sunken))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(open ? "Vaqt chizig'ini yashirish" : "Qaysi asbob qachon va qancha ishlaganini qatorlarda ko'rsatish")
            }
        }
        .padding(open ? 16 : 10)
        .card(padding: 0)
        .padding(.horizontal, 24)
    }

    /// «Vaqtning 62% — model o'ylashi · 24% — terminal …»
    private var shares: some View {
        let sum = max(1, timeline.shares.reduce(0) { $0 + $1.seconds })
        return HStack(spacing: 4) {
            Text("Vaqtning").foregroundStyle(.secondary)
            ForEach(Array(timeline.shares.prefix(3).enumerated()), id: \.offset) { i, s in
                if i > 0 { Text("·").foregroundStyle(.tertiary) }
                if let c = shareColor(s.title) { Circle().fill(c).frame(width: 7, height: 7) }
                Text(Fmt.percent(s.seconds, of: sum)).fontWeight(.semibold)
                Text("— \(i == 0 && s.title.hasPrefix("Model") ? "model o'ylashi" : s.title.lowercased())").foregroundStyle(.secondary)
            }
        }
        .font(.callout)
        .lineLimit(1)
    }

    private func shareColor(_ title: String) -> Color? {
        if title.hasPrefix("Model") { return Brand.accent }
        return ToolCategory.allCases.first { $0.title == title }?.color
    }
}

// MARK: - Qadamlar

struct StepsPane: View {
    let steps: [(agent: AgentSnap, step: StepSnap)]
    let origin: Date
    @State private var selected: String?

    var body: some View {
        let current = steps.first { $0.step.id == selected } ?? steps.last
        HStack(alignment: .top, spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(steps, id: \.step.id) { item in
                            row(item, on: current?.step.id == item.step.id).id(item.step.id)
                        }
                    }
                    .padding(8)
                }
                .onAppear { proxy.scrollTo(steps.last?.step.id, anchor: .bottom) }
                .onChange(of: steps.count) { _ in
                    if selected == nil { withAnimation(Motion.spring) { proxy.scrollTo(steps.last?.step.id, anchor: .bottom) } }
                }
            }
            Divider()
            detail(current).frame(width: 320, alignment: .topLeading)
        }
        .card(padding: 0)
        .padding(.horizontal, 24).padding(.bottom, 20)
    }

    private func rel(_ d: Date) -> String {
        let s = max(0, Int(d.timeIntervalSince(origin)))
        return s >= 3600 ? "\(s / 3600):\(String(format: "%02d:%02d", s / 60 % 60, s % 60))" : "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    private func row(_ item: (agent: AgentSnap, step: StepSnap), on: Bool) -> some View {
        let s = item.step
        return Button { withAnimation(Motion.snappy) { selected = s.id } } label: {
            HStack(spacing: 12) {
                Text(rel(s.date)).font(.system(size: 11, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 46, alignment: .leading)
                ToolTile(symbol: s.category.symbol, color: s.category.color, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.category.title + (item.agent.isMain ? "" : " · \(item.agent.title)")).font(.callout.weight(.semibold)).lineLimit(1)
                    Text(s.targetName.isEmpty ? s.text : s.targetName)
                        .font(.system(size: 11.5, design: .monospaced)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                HStack(spacing: 5) {
                    switch s.status {
                    case .running: StateDot(state: .running, size: 6)
                    case .failed: Image(systemName: "xmark").foregroundStyle(Brand.err)
                    case .done: Image(systemName: "checkmark").foregroundStyle(.tertiary)
                    }
                    Text(s.duration.map { Alerts.duration($0) } ?? "—")
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(s.status == .failed ? Brand.err : .secondary)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(on ? Brand.accentSoft : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }

    @ViewBuilder
    private func detail(_ item: (agent: AgentSnap, step: StepSnap)?) -> some View {
        if let item {
            let s = item.step
            VStack(alignment: .leading, spacing: 10) {
                ToolTile(symbol: s.category.symbol, color: s.category.color, size: 40)
                Text(s.text).font(.system(size: 16, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                StatusChip(active: s.status == .running, errors: s.status == .failed ? 1 : 0)
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                    gridRow("Boshlandi", "\(Fmt.clock.string(from: s.date)) (+\(rel(s.date)))")
                    gridRow("Davomiylik", s.duration.map { Alerts.duration($0) } ?? "—")
                    gridRow("Nishon", s.targetName.isEmpty ? "—" : s.targetName)
                    if !s.targetDetail.isEmpty { gridRow("Joyi", s.targetDetail) }
                    gridRow("Agent", item.agent.isMain ? "Asosiy agent" : item.agent.title)
                }
                .font(.caption)
                .padding(.top, 6)
                Spacer()
            }
            .padding(18)
        } else {
            EmptyStateView(symbol: "list.bullet", title: "Qadam yo'q", text: "Bu so'rovda hali asbob chaqirilmagan.")
        }
    }

    private func gridRow(_ k: String, _ v: String) -> some View {
        GridRow {
            Text(k).foregroundStyle(.secondary)
            Text(v).font(.system(size: 11.5, design: .monospaced)).lineLimit(2).truncationMode(.middle).textSelection(.enabled)
        }
    }
}

/// Kontekst oynasi to'lishi: kichik chiziq va foiz. 80% dan — sariq, 92% dan — qizil (tez orada avtomatik xulosa)
struct ContextGauge: View {
    let session: SessionSnap

    var body: some View {
        let f = session.contextFraction
        let color = f >= 0.92 ? Brand.err : (f >= 0.8 ? Brand.warn : Brand.accent)
        HStack(spacing: 6) {
            Text("Kontekst")
            ZStack(alignment: .leading) {
                Capsule().fill(Brand.line)
                Capsule().fill(color).frame(width: max(3, 54 * f))
            }
            .frame(width: 54, height: 5)
            Text("\(Int((f * 100).rounded()))%").monospacedDigit().foregroundStyle(f >= 0.8 ? color : .secondary)
        }
        .help("Kontekst: \(Fmt.tokens(Double(session.contextTokens))) / \(Fmt.tokens(Double(session.contextWindow))) token."
              + (f >= 0.8 ? " Tez orada suhbat avtomatik xulosa qilinadi." : ""))
        .animation(Motion.smooth, value: f)
    }
}
