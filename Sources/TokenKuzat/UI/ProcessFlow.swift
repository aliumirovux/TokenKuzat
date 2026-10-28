import SwiftUI
import TokenKuzatCore

// Jarayon oqimi — so'rov qanday bajarilgani, ketma-ketlikda (n8n bajarilish ko'rinishi kabi):
//
//  (So'rov) → [Terminal ×4] → [Fayllar ×2] → [MCP] ↴
//  ↙ [Natija] ← [Fayllar] ← [Terminal ×3]   ←
//
// Ketma-ket kelgan bir xil turdagi qadamlar (bir agentda) bitta bosqichga birlashadi.
// Bosqichlar orasidagi bo'shliq — model o'ylagan vaqt, strelka ustida yoziladi.
// Qatorlar ilon izi bo'lib boradi: juft qator chapdan o'ngga, toq qator o'ngdan chapga.

struct Phase: Identifiable {
    /// Shundan qisqa tanaffus bilan kelgan bir xil turdagi qadamlar bitta bosqich bo'ladi
    static let mergeGap: TimeInterval = 20

    let id: String
    let category: ToolCategory
    let agent: AgentSnap
    let steps: [StepSnap]
    let start: Date
    let end: Date
    /// Oldingi bosqich tugagandan beri o'tgan vaqt (model o'ylashi)
    let think: TimeInterval?

    var status: StepStatus {
        if steps.contains(where: { $0.status == .running }) { return .running }
        return steps.contains(where: { $0.status == .failed }) ? .failed : .done
    }
    var errors: Int { steps.filter { $0.status == .failed }.count }
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    var targets: [String] {
        var seen = Set<String>()
        return steps.map(\.targetName).filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    static func build(_ timeline: TimelineModel) -> [Phase] {
        let items = timeline.rows.flatMap { r in r.bars.map { (agent: r.agent, bar: $0) } }
            .sorted { $0.bar.start < $1.bar.start }
        var phases: [Phase] = []
        var cur: [(agent: AgentSnap, bar: TimelineBar)] = []
        var lastEnd: Date?
        func flush() {
            guard let first = cur.first else { return }
            let end = cur.map(\.bar.end).max() ?? first.bar.end
            let think = lastEnd.map { first.bar.start.timeIntervalSince($0) }
            phases.append(Phase(id: first.bar.id, category: first.bar.step.category, agent: first.agent,
                                steps: cur.map(\.bar.step), start: first.bar.start, end: end,
                                think: think.flatMap { $0 >= 1 ? $0 : nil }))
            lastEnd = max(lastEnd ?? end, end)
            cur = []
        }
        for it in items {
            if let last = cur.last, last.bar.step.category == it.bar.step.category, last.agent.id == it.agent.id,
               it.bar.start.timeIntervalSince(cur.map(\.bar.end).max() ?? last.bar.end) < Phase.mergeGap {
                cur.append(it)
            } else {
                flush()
                cur = [it]
            }
        }
        flush()
        return phases
    }
}

struct ProcessFlowView: View {
    let phases: [Phase]
    let prompt: String
    let result: FlowResult
    let mode: CountMode
    let origin: Date
    @State private var selected: String?
    @State private var width: CGFloat = 900
    @State private var entered = false
    @State private var appearedAt = Date.distantPast

    private let nodeW: CGFloat = 210
    private let nodeH: CGFloat = 104
    private let gapX: CGFloat = 64
    private let gapY: CGFloat = 70
    private let pad: CGFloat = 28

    private enum Item: Identifiable {
        case start, phase(Phase), end
        var id: String {
            switch self {
            case .start: return "__start"
            case .phase(let p): return p.id
            case .end: return "__end"
            }
        }
    }

    var body: some View {
        let items: [Item] = [.start] + phases.map { .phase($0) } + [.end]
        let current = phases.first { $0.id == selected } ?? phases.last { $0.status == .running } ?? phases.last
        let cols = max(2, Int((width - 2 * pad + gapX) / (nodeW + gapX)))
        let positions = layout(count: items.count, cols: cols, width: width)
        let rows = Int(ceil(Double(items.count) / Double(cols)))
        let height = max(300, CGFloat(rows) * (nodeH + gapY) - gapY + 2 * pad)
        HStack(alignment: .top, spacing: 0) {
            ZStack(alignment: .topLeading) {
                DotsBackground()
                edges(items, positions, cols: cols)
                ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                    node(item, selected: current.map { $0.id == item.id } ?? false)
                        .position(positions[i])
                        .modifier(Enter(on: entered, delay: min(1.2, Double(i) * 0.045)))
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { width = g.size.width }
                    .onChange(of: g.size.width) { width = $0 }
            })
            .animation(Motion.spring, value: items.map(\.id))
            .animation(Motion.spring, value: cols)
            .onAppear { entered = false; appearedAt = Date(); DispatchQueue.main.async { entered = true } }
            .onChange(of: prompt) { _ in entered = false; appearedAt = Date(); DispatchQueue.main.async { entered = true } }
            Divider()
            PhaseDetail(phase: current, origin: origin)
                .frame(width: 300)
                .frame(maxHeight: max(300, height))
        }
    }

    // MARK: Joylashuv

    private func layout(count: Int, cols: Int, width: CGFloat) -> [CGPoint] {
        let used = CGFloat(cols) * nodeW + CGFloat(cols - 1) * gapX
        let left = max(pad, (width - used) / 2) + nodeW / 2
        return (0..<count).map { i in
            let row = i / cols
            var col = i % cols
            if row % 2 == 1 { col = cols - 1 - col }   // ilon izi
            return CGPoint(x: left + CGFloat(col) * (nodeW + gapX), y: pad + nodeH / 2 + CGFloat(row) * (nodeH + gapY))
        }
    }

    // MARK: Chiziqlar

    private func edges(_ items: [Item], _ pos: [CGPoint], cols: Int) -> some View {
        let anyLive = phases.contains { $0.status == .running }
        let entering = Date().timeIntervalSince(appearedAt) < 2
        return TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !anyLive && !entering)) { ctx in
        let t = ctx.date.timeIntervalSinceReferenceDate
        // Chiziqlar tugunlar bilan birga, ketma-ket chiziladi
        let elapsed = ctx.date.timeIntervalSince(appearedAt)
        Canvas { g, _ in
            for i in 0..<max(0, items.count - 1) {
                let pr = min(1, max(0, (elapsed - Double(i) * 0.045) / 0.35))
                guard pr > 0 else { continue }
                let a = pos[i], b = pos[i + 1]
                let sameRow = abs(a.y - b.y) < 1
                var path = Path()
                let from: CGPoint, to: CGPoint
                if sameRow {
                    let dir: CGFloat = b.x > a.x ? 1 : -1
                    from = CGPoint(x: a.x + dir * nodeW / 2, y: a.y)
                    to = CGPoint(x: b.x - dir * nodeW / 2, y: b.y)
                    path.move(to: from); path.addLine(to: to)
                } else {
                    from = CGPoint(x: a.x, y: a.y + nodeH / 2)
                    to = CGPoint(x: b.x, y: b.y - nodeH / 2)
                    path.move(to: from)
                    path.addCurve(to: to, control1: CGPoint(x: from.x, y: from.y + gapY * 0.6),
                                  control2: CGPoint(x: to.x, y: to.y - gapY * 0.6))
                }
                let live: Bool = {
                    if case .phase(let p) = items[i + 1] { return p.status == .running }
                    return false
                }()
                path = path.trimmedPath(from: 0, to: pr)
                if live && pr >= 1 {
                    // Bajarilayotgan bosqichga: ma'lumot paketlari ikki tomonga
                    DataFlow.draw(&g, path: path, color: Brand.ok, t: t, seed: Double(i) * 0.37, width: 2)
                } else {
                    g.stroke(path, with: .color(Color.secondary.opacity(0.45)),
                             style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
                }
                guard pr >= 1 else { continue }
                // Strelka uchi
                let ang = sameRow ? (to.x > from.x ? 0 : CGFloat.pi) : CGFloat.pi / 2
                var head = Path()
                head.move(to: to)
                head.addLine(to: CGPoint(x: to.x - 7 * cos(ang - 0.5), y: to.y - 7 * sin(ang - 0.5)))
                head.move(to: to)
                head.addLine(to: CGPoint(x: to.x - 7 * cos(ang + 0.5), y: to.y - 7 * sin(ang + 0.5)))
                g.stroke(head, with: .color(live ? Brand.ok : Color.secondary.opacity(0.6)), lineWidth: 1.6)
                // O'ylash vaqti — chiziq o'rtasida
                if case .phase(let p) = items[i + 1], let t = p.think {
                    let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2)
                    let text = Text("💭 \(Alerts.duration(t))").font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    let r = g.resolve(text)
                    let s = r.measure(in: CGSize(width: 200, height: 40))
                    let box = CGRect(x: mid.x - s.width / 2 - 5, y: mid.y - s.height / 2 - 2, width: s.width + 10, height: s.height + 4)
                    g.fill(Path(roundedRect: box, cornerRadius: 6), with: .color(Brand.canvas))
                    g.draw(r, at: mid)
                }
            }
        }
        }
    }

    // MARK: Tugunlar

    @ViewBuilder
    private func node(_ item: Item, selected: Bool) -> some View {
        switch item {
        case .start:
            terminal(symbol: "person.wave.2.fill", color: Palette.cacheRead, title: "So'rov", sub: prompt)
        case .end:
            terminal(symbol: result.active ? "ellipsis" : (result.errors > 0 ? "checkmark.circle.trianglebadge.exclamationmark" : "checkmark.circle.fill"),
                     color: result.active ? Brand.ok : (result.errors > 0 ? Brand.warn : Brand.accent),
                     title: result.active ? "Davom etyapti…" : "Natija",
                     sub: "\(Alerts.duration(result.duration)) · \(Fmt.tokens(result.tokens.value(mode)))" +
                          (result.changedFiles.isEmpty ? "" : " · ✎ \(result.changedFiles.count) fayl"))
        case .phase(let p):
            Button { withAnimation(Motion.snappy) { self.selected = p.id } } label: { phaseNode(p, selected: selected) }
                .buttonStyle(.plain)
        }
    }

    private func terminal(symbol: String, color: Color, title: String, sub: String) -> some View {
        HStack(spacing: 10) {
            ToolTile(symbol: symbol, color: color, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.semibold))
                Text(sub).font(.caption).foregroundStyle(.secondary).lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: nodeW, height: nodeH, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: nodeH / 2.6, style: .continuous).fill(Brand.surface))
        .overlay(RoundedRectangle(cornerRadius: nodeH / 2.6, style: .continuous).stroke(Brand.line))
    }

    private func phaseNode(_ p: Phase, selected: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ToolTile(symbol: p.category.symbol, color: p.category.color, size: 28)
                VStack(alignment: .leading, spacing: 0) {
                    Text(p.category.title + (p.steps.count > 1 ? " ×\(p.steps.count)" : ""))
                        .font(.callout.weight(.semibold)).lineLimit(1)
                    if !p.agent.isMain {
                        Text(p.agent.title).font(.caption2).foregroundStyle(Palette.agents).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                statusBadge(p)
            }
            Text(p.targets.prefix(3).joined(separator: " · ") + (p.targets.count > 3 ? " +\(p.targets.count - 3)" : ""))
                .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle)
            Spacer(minLength: 0)
            HStack {
                Text("+" + clock(p.start.timeIntervalSince(origin)))
                Spacer()
                Text(Alerts.duration(p.duration))
            }
            .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.tertiary)
        }
        .padding(11)
        .frame(width: nodeW, height: nodeH, alignment: .topLeading)
        .background(shape.fill(Brand.surface))
        .background(shape.fill((p.status == .failed ? Brand.err : (p.status == .running ? Brand.ok : .clear)).opacity(0.06)))
        .overlay(shape.stroke(selected ? Brand.accent : (p.status == .running ? Brand.ok : (p.status == .failed ? Brand.err.opacity(0.5) : Brand.line)),
                              lineWidth: selected || p.status == .running ? 1.8 : 1))
        .shadow(color: .black.opacity(selected ? 0.12 : 0.04), radius: selected ? 10 : 4, y: 2)
        .scaleEffect(selected ? 1.02 : 1)
        .animation(Motion.spring, value: selected)
        .contentShape(shape)
        .help(p.steps.map(\.text).joined(separator: "\n"))
    }

    @ViewBuilder
    private func statusBadge(_ p: Phase) -> some View {
        switch p.status {
        case .running:
            HStack(spacing: 4) { StateDot(state: .running, size: 6); Text("jonli") }
                .font(.caption2.weight(.semibold)).foregroundStyle(Brand.ok)
        case .failed:
            Label("\(p.errors)", systemImage: "xmark.circle.fill").font(.caption2.weight(.semibold)).foregroundStyle(Brand.err)
        case .done:
            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func clock(_ s: TimeInterval) -> String {
        let t = max(0, Int(s))
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }
}

/// Tanlangan bosqich: ichidagi har bir qadam — vaqti, nishoni, davomiyligi, holati
private struct PhaseDetail: View {
    let phase: Phase?
    let origin: Date

    var body: some View {
        if let p = phase {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        ToolTile(symbol: p.category.symbol, color: p.category.color, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.category.title).font(.system(size: 16, weight: .semibold, design: .rounded))
                            Text(p.agent.isMain ? "Asosiy agent" : p.agent.title).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    HStack(spacing: 14) {
                        stat("\(p.steps.count)", "qadam")
                        stat(Alerts.duration(p.duration), "davomiylik")
                        if let t = p.think { stat(Alerts.duration(t), "oldin o'yladi") }
                    }
                    Divider()
                    ForEach(p.steps) { s in
                        HStack(alignment: .top, spacing: 8) {
                            Group {
                                switch s.status {
                                case .running: StateDot(state: .running, size: 7).padding(.top, 4)
                                case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(Brand.err)
                                case .done: Image(systemName: "checkmark.circle").foregroundStyle(.tertiary)
                                }
                            }
                            .font(.caption).frame(width: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.text).font(.caption).lineLimit(3)
                                    .foregroundStyle(s.status == .failed ? Brand.err : .primary)
                                Text("\(Fmt.clock.string(from: s.date)) · \(s.duration.map { Alerts.duration($0) } ?? "—")")
                                    .font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(18)
            }
        } else {
            EmptyStateView(symbol: "point.3.connected.trianglepath.dotted", title: "Hali qadam yo'q",
                           text: "Bu so'rovda asbob chaqirilishi bilan jarayon shu yerda paydo bo'ladi.")
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(v).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct DotsBackground: View {
    var body: some View {
        Canvas { g, size in
            let step: CGFloat = 22
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    g.fill(Path(ellipseIn: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6)), with: .color(Color.primary.opacity(0.1)))
                    x += step
                }
                y += step
            }
        }
    }
}
