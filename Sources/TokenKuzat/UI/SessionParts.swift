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
        // Chapda nom va belgilar (sig'masa — keyingi qatorga o'tadi), o'ngda raqamlar
        HStack(alignment: .bottom, spacing: 16) {
            titleBlock(active: active)
                .frame(maxWidth: .infinity, alignment: .leading)
            kpis(duration: duration, steps: steps, tokens: tokens)
        }
        .padding(.horizontal, 24).padding(.top, 12)
    }

    private func titleBlock(active: Bool) -> some View {
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
            FlowRow(spacing: 14, lineSpacing: 8) {
                StatusChip(active: active, errors: turn?.errors ?? 0, waiting: waiting != nil).fixedSize()
                if session.contextTokens > 0 { ContextGauge(session: session).fixedSize() }
                SavingsChip(session: session).fixedSize()
                if let turn { Text("#\(turn.id)-so'rov").fontWeight(.semibold).foregroundStyle(.primary).fixedSize() }
                if !session.model.isEmpty { Text(session.model).fixedSize() }
                if let start = turn?.start ?? session.timeRange?.lowerBound {
                    Text("\(Fmt.hourMinute.string(from: start)) da boshlangan").foregroundStyle(.tertiary).fixedSize()
                }
            }
            .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func kpis(duration: TimeInterval, steps: Int, tokens: TokenCounts) -> some View {
        HStack(spacing: 20) {
            kpi(Alerts.duration(duration), "davomiylik")
            kpi("\(steps)", "qadam")
            kpi(Fmt.tokens(tokens.value(mode)), costUSD.map { "token · " + String(format: "$%.2f", $0).replacingOccurrences(of: ".", with: ",") } ?? "token")
        }
        .fixedSize()
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

/// Kontekst oynasi to'lishi: kichik chiziq va foiz. 80% dan — sariq, 92% dan — qizil (tez orada avtomatik xulosa)
struct ContextGauge: View {
    let session: SessionSnap

    var body: some View {
        let f = session.contextFraction
        let color = f >= 0.92 ? Brand.err : (f >= 0.8 ? Brand.warn : Brand.accent)
        HStack(spacing: 6) {
            Text("Kontekst").lineLimit(1).fixedSize()
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

/// Elementlarni chapdan o'ngga teradi, sig'masa — keyingi qatorga (belgilar siqilib, harflari ustun bo'lib qolmasin)
struct FlowRow: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let w = rows.map { $0.width }.max() ?? 0
        let h = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: proposal.width.map { min($0, w) } ?? w, height: h)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for i in row.items {
                let size = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let size = subviews[i].sizeThatFits(.unspecified)
            guard size.width > 0 else { continue }
            let add = (rows[rows.count - 1].items.isEmpty ? 0 : spacing) + size.width
            if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + add > width { rows.append(Row()) }
            var r = rows[rows.count - 1]
            r.width += (r.items.isEmpty ? 0 : spacing) + size.width
            r.height = max(r.height, size.height)
            r.items.append(i)
            rows[rows.count - 1] = r
        }
        return rows.filter { !$0.items.isEmpty }
    }
}
