import SwiftUI
import TokenKuzatCore

// Oqim grafigi (metro xaritasi kabi): yo'laklar — Siz, Model va asbob turlari; har bir hodisa o'z yo'lagida
// kichik belgi. Chiziq hodisadan hodisaga silliq egri bo'lib yo'lakdan yo'lakka tepaga/pastga o'tadi va eniga
// o'sib boradi. Matn faqat ko'rsatkich ostida chiqadi. So'rovlar — ingichka vertikal chiziq va «#41».

// MARK: - Model

enum TraceLane: Int, CaseIterable, Comparable {
    case you, model, shell, files, web, mcp, agent, other

    static func < (a: TraceLane, b: TraceLane) -> Bool { a.rawValue < b.rawValue }

    init(_ c: ToolCategory) {
        switch c {
        case .shell: self = .shell
        case .files: self = .files
        case .web: self = .web
        case .mcp: self = .mcp
        case .agent: self = .agent
        case .other: self = .other
        }
    }

    var title: String {
        switch self {
        case .you: return "Siz"
        case .model: return "Model"
        case .shell: return ToolCategory.shell.title
        case .files: return ToolCategory.files.title
        case .web: return ToolCategory.web.title
        case .mcp: return ToolCategory.mcp.title
        case .agent: return ToolCategory.agent.title
        case .other: return ToolCategory.other.title
        }
    }

    var symbol: String {
        switch self {
        case .you: return "person.fill"
        case .model: return "brain"
        case .shell: return ToolCategory.shell.symbol
        case .files: return ToolCategory.files.symbol
        case .web: return ToolCategory.web.symbol
        case .mcp: return ToolCategory.mcp.symbol
        case .agent: return ToolCategory.agent.symbol
        case .other: return ToolCategory.other.symbol
        }
    }

    var color: Color {
        switch self {
        case .you: return Brand.accent
        case .model: return Brand.inkFill
        case .shell: return ToolCategory.shell.iconColor
        case .files: return ToolCategory.files.color
        case .web: return ToolCategory.web.color
        case .mcp: return ToolCategory.mcp.color
        case .agent: return ToolCategory.agent.color
        case .other: return ToolCategory.other.color
        }
    }
}

struct TraceEvent: Identifiable {
    enum Kind {
        case prompt(TurnSnap)
        case step(StepSnap)
        case note(NoteSnap)
    }
    let id: String
    let date: Date
    let lane: TraceLane
    let kind: Kind
    let sessionId: String
    let turnId: Int
    /// Yordamchi agent nomi (asosiy agentda nil)
    let agent: String?

    var symbol: String {
        switch kind {
        case .prompt: return "person.fill"
        case .step(let s): return s.symbol
        case .note(let n): return n.kind == .reply ? "text.bubble.fill" : "brain"
        }
    }

    var failed: Bool { if case .step(let s) = kind { return s.status == .failed }; return false }
    var running: Bool { if case .step(let s) = kind { return s.status == .running }; return false }

    /// Ko'rsatkich ostidagi qisqa matn
    var text: String {
        switch kind {
        case .prompt(let t): return t.shownPrompt
        case .step(let s): return s.text
        case .note(let n): return n.text.isEmpty ? "O'yladi" : n.text
        }
    }

    var label: String {
        switch kind {
        case .prompt(let t): return "#\(t.id) · siz"
        case .step(let s): return s.category.title + (s.duration.map { " · " + Alerts.duration($0) } ?? "")
        case .note(let n): return n.kind == .reply ? "Javob" : "O'yladi"
        }
    }
}

/// Bitta so'rov bo'lagi: o'z hodisalari bilan (eskidan yangiga)
struct TraceSegment: Identifiable {
    let id: String
    let turn: TurnSnap
    let sessionId: String
    let events: [TraceEvent]
}

enum TraceModel {
    /// Zanjirdagi sessiyalar → so'rov bo'laklari. Har bo'lak so'rov belgisi (Siz) bilan boshlanadi
    static func segments(_ chain: [SessionSnap]) -> [TraceSegment] {
        var out: [TraceSegment] = []
        for s in chain {
            let steps = s.agents.flatMap { a in a.steps.map { (step: $0, agent: a.isMain ? nil : a.title) } }
            let byTurn = Dictionary(grouping: steps, by: { $0.step.turn ?? 0 })
            let notes = Dictionary(grouping: s.notes.filter { !($0.kind == .thinking && $0.text.isEmpty) }, by: { $0.turn ?? 0 })
            for t in s.turns {
                var ev: [TraceEvent] = [TraceEvent(id: "\(s.id)#\(t.id)/p", date: t.start, lane: .you, kind: .prompt(t),
                                                   sessionId: s.id, turnId: t.id, agent: nil)]
                ev += (byTurn[t.id] ?? []).map {
                    TraceEvent(id: $0.step.id, date: $0.step.date, lane: TraceLane($0.step.category), kind: .step($0.step),
                               sessionId: s.id, turnId: t.id, agent: $0.agent)
                }
                ev += (notes[t.id] ?? []).map {
                    TraceEvent(id: $0.id, date: $0.date, lane: .model, kind: .note($0), sessionId: s.id, turnId: t.id, agent: $0.agent)
                }
                ev.sort { $0.date < $1.date }
                // Prompt doim birinchi (vaqti teng bo'lsa ham)
                if let i = ev.firstIndex(where: { if case .prompt = $0.kind { return true }; return false }), i != 0 {
                    ev.insert(ev.remove(at: i), at: 0)
                }
                out.append(TraceSegment(id: "\(s.id)#\(t.id)", turn: t, sessionId: s.id, events: ev))
            }
        }
        return out
    }

    static func lanes(_ segs: [TraceSegment]) -> [TraceLane] {
        var set: Set<TraceLane> = [.you, .model]
        for s in segs { for e in s.events { set.insert(e.lane) } }
        return set.sorted()
    }
}

// MARK: - Ko'rinish

private enum T {
    static let top: CGFloat = 34
    static let lead: CGFloat = 30
    static let tail: CGFloat = 18
    static let r: CGFloat = 9
}

struct TraceView: View {
    let chain: [SessionSnap]
    let selectedTurn: String?
    let onSelectTurn: (_ sessionId: String, _ turnId: Int) -> Void
    let onSelectTool: (_ sessionId: String, _ turnId: Int, _ category: ToolCategory) -> Void
    var onSelectNote: (_ sessionId: String, _ note: NoteSnap) -> Void = { _, _ in }

    /// Hodisalar orasidagi masofa (zoom)
    @AppStorage("traceSpacing") private var dx: Double = 30
    @State private var follow = true
    @State private var hovered: String?

    var body: some View {
        let segs = TraceModel.segments(chain)
        let lanes = TraceModel.lanes(segs)
        let lastId = segs.last.map { "\($0.id)|\($0.events.count)" } ?? ""
        GeometryReader { geo in
        // Yo'laklar oyna balandligini to'liq egallaydi (juda siqilmaydi va cho'zilib ketmaydi)
        let laneH = min(120, max(40, (geo.size.height - T.top - 56) / CGFloat(max(lanes.count, 1))))
        let height = T.top + CGFloat(lanes.count) * laneH + 8
        HStack(alignment: .top, spacing: 0) {
            laneLabels(lanes, laneH: laneH)
                .frame(height: geo.size.height, alignment: .top)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(segs.enumerated()), id: \.element.id) { i, seg in
                            TraceSegmentView(segment: seg, lanes: lanes, laneH: laneH, dx: CGFloat(dx),
                                             prevLane: i > 0 ? segs[i - 1].events.last?.lane : nil,
                                             selected: selectedTurn == seg.id,
                                             live: seg.turn.active,
                                             hovered: $hovered,
                                             onTap: tap)
                                .frame(height: height)
                                // Ko'rsatkich ostidagi bo'lak ustida — yozuvi qo'shnilari tagida qolmasin
                                .zIndex(seg.events.contains { $0.id == hovered } ? 1 : 0)
                        }
                        Color.clear.frame(width: 60, height: 1).id("end")
                    }
                }
                .frame(height: height + 14, alignment: .top)
                .frame(maxHeight: .infinity, alignment: .top)
                .onAppear { proxy.scrollTo("end", anchor: .trailing) }
                .onChange(of: lastId) { _ in
                    if follow { withAnimation(Motion.smooth) { proxy.scrollTo("end", anchor: .trailing) } }
                }
                .overlay(alignment: .bottomLeading) { controls(proxy).padding(10) }
            }
        }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Brand.canvas)
    }

    /// Chapdagi qotib turgan yo'lak belgilari
    private func laneLabels(_ lanes: [TraceLane], laneH: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: T.top)
            ForEach(lanes, id: \.self) { l in
                HStack(spacing: 6) {
                    Image(systemName: l.symbol).font(.system(size: 10, weight: .semibold)).foregroundStyle(l.color)
                        .frame(width: 22, height: 22).background(Circle().fill(l.color.opacity(0.14)))
                    Text(l.title).font(.caption2.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(height: laneH, alignment: .leading)
                .help(l.title)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(width: 118, alignment: .leading)
        .background(Brand.surface.opacity(0.5))
        .overlay(alignment: .trailing) { Rectangle().fill(Brand.line).frame(width: 1) }
    }

    private func controls(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                button("minus", "Zichroq") { dx = max(14, dx / 1.25) }
                button("plus", "Kengroq") { dx = min(80, dx * 1.25) }
            }
            .surface(radius: 10, interactive: true)
            Button {
                follow.toggle()
                if follow { withAnimation(Motion.smooth) { proxy.scrollTo("end", anchor: .trailing) } }
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(follow ? Brand.ok : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                    Text(follow ? "Ergashyapti" : "Ergashish")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).frame(height: 28)
                .surface(radius: 10, interactive: true)
            }
            .buttonStyle(.plain)
            .help("Yangi hodisalar kelganda oxiriga o'tib turish")
        }
    }

    private func button(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button { withAnimation(Motion.snappy) { action() } } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func tap(_ e: TraceEvent) {
        switch e.kind {
        case .prompt(let t): onSelectTurn(e.sessionId, t.id)
        case .step(let s): onSelectTool(e.sessionId, e.turnId, s.category)
        case .note(let n): onSelectNote(e.sessionId, n)
        }
    }
}

/// Bitta so'rov bo'lagi: chapda so'rov chizig'i va «#41», keyin hodisalar o'z yo'laklarida, oldingi bo'lakdan kelgan chiziq bilan
private struct TraceSegmentView: View {
    let segment: TraceSegment
    let lanes: [TraceLane]
    let laneH: CGFloat
    let dx: CGFloat
    let prevLane: TraceLane?
    let selected: Bool
    let live: Bool
    @Binding var hovered: String?
    let onTap: (TraceEvent) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var width: CGFloat { T.lead + CGFloat(max(0, segment.events.count - 1)) * dx + T.tail }

    private func y(_ l: TraceLane) -> CGFloat {
        T.top + CGFloat(lanes.firstIndex(of: l) ?? 0) * laneH + laneH / 2
    }

    private func point(_ i: Int) -> CGPoint {
        CGPoint(x: T.lead + CGFloat(i) * dx, y: y(segment.events[i].lane))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { ctx in
            Canvas { g, size in draw(&g, size: size, t: ctx.date.timeIntervalSinceReferenceDate) }
        }
        .frame(width: width)
        .overlay(alignment: .topLeading) { marker }
        .overlay(alignment: .topLeading) { tooltip }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case .active(let p): hovered = nearest(p)?.id
            case .ended: if let h = hovered, segment.events.contains(where: { $0.id == h }) { hovered = nil }
            }
        }
        .gesture(SpatialTapGesture().onEnded { v in
            if let e = nearest(v.location) { onTap(e) }
        })
    }

    private func nearest(_ p: CGPoint) -> TraceEvent? {
        var best: (Int, CGFloat)?
        for i in segment.events.indices {
            let q = point(i)
            let d = hypot(q.x - p.x, q.y - p.y)
            if d < 16, best.map({ d < $0.1 }) ?? true { best = (i, d) }
        }
        return best.map { segment.events[$0.0] }
    }

    private func draw(_ g: inout GraphicsContext, size: CGSize, t: Double) {
        // Yo'lak chiziqlari
        for l in lanes {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: y(l)))
            p.addLine(to: CGPoint(x: size.width, y: y(l)))
            g.stroke(p, with: .color(Color.primary.opacity(0.05)), lineWidth: 1)
        }
        // So'rov chegarasi
        var m = Path()
        m.move(to: CGPoint(x: 8, y: 22))
        m.addLine(to: CGPoint(x: 8, y: size.height - 4))
        g.stroke(m, with: .color(selected ? Brand.accent.opacity(0.7) : Color.primary.opacity(0.14)),
                 style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

        let ev = segment.events
        guard !ev.isEmpty else { return }
        // Oldingi bo'lakdan kelgan chiziq
        var pts: [(CGPoint, TraceEvent)] = ev.indices.map { (point($0), ev[$0]) }
        if let pl = prevLane {
            let start = CGPoint(x: 0, y: y(pl))
            g.stroke(curve(start, pts[0].0), with: .color(Color.primary.opacity(0.25)), lineWidth: 1.6)
        }
        // Hodisadan hodisaga: egri, borayotgan yo'lak rangida
        for i in 1..<max(1, pts.count) where pts.count > 1 {
            let a = pts[i - 1].0, b = pts[i].0, e = pts[i].1
            let path = curve(a, b)
            let isLast = i == pts.count - 1
            if live && isLast && !reduceMotion {
                DataFlow.draw(&g, path: path, color: e.lane.color, t: t, seed: 0.3, width: 1.8, duplex: false)
            } else {
                g.stroke(path, with: .color(e.lane.color.opacity(0.55)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
        // Belgilar
        for (p, e) in pts {
            let hover = hovered == e.id
            let r = T.r * (hover ? 1.35 : 1)
            let c = e.failed ? Brand.err : e.lane.color
            let circle = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            switch e.kind {
            case .prompt:
                g.fill(circle, with: .color(Brand.accent))
                g.draw(Text(Image(systemName: "person.fill")).font(.system(size: r * 0.95, weight: .bold)).foregroundColor(.white), at: p)
            case .note(let n):
                if n.kind == .reply {
                    g.fill(circle, with: .color(Brand.ok.opacity(0.9)))
                    g.draw(Text(Image(systemName: "text.bubble.fill")).font(.system(size: r * 0.85)).foregroundColor(.white), at: p)
                } else {
                    let rr = r * 0.6
                    g.fill(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)), with: .color(Brand.canvas))
                    g.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                             with: .color(c), lineWidth: 1.6)
                }
            case .step:
                g.fill(circle, with: .color(Brand.surface))
                g.fill(circle, with: .color(c.opacity(0.18)))
                g.stroke(circle, with: .color(c), lineWidth: e.failed ? 2 : 1.4)
                g.draw(Text(Image(systemName: e.failed ? "xmark" : e.symbol))
                        .font(.system(size: r * 0.9, weight: .semibold)).foregroundColor(c), at: p)
                if e.running {
                    // Bajarilayotgan qadam atrofida to'lqin
                    let k = (t.truncatingRemainder(dividingBy: 1.4)) / 1.4
                    let rr = r + 2 + CGFloat(k) * 8
                    g.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                             with: .color(c.opacity(0.6 * (1 - k))), lineWidth: 1.5)
                }
            }
            if e.agent != nil {
                // Yordamchi agent qadami — kichik nuqta-belgi
                g.fill(Path(ellipseIn: CGRect(x: p.x + r * 0.55, y: p.y - r * 1.05, width: 5, height: 5)), with: .color(Brand.accent))
            }
        }
    }

    /// Silliq o'tish: bir yo'lakda — to'g'ri, boshqa yo'lakka — S-egri
    private func curve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        p.move(to: a)
        if abs(a.y - b.y) < 0.5 {
            p.addLine(to: b)
        } else {
            let mx = (a.x + b.x) / 2
            p.addCurve(to: b, control1: CGPoint(x: mx, y: a.y), control2: CGPoint(x: mx, y: b.y))
        }
        return p
    }

    /// Tepada so'rov raqami (bosilsa — shu so'rov tanlanadi)
    private var marker: some View {
        let t = segment.turn
        return HStack(spacing: 4) {
            Text("#\(t.id)").font(.caption2.weight(.bold)).monospacedDigit()
            if t.errors > 0 { Circle().fill(Brand.err).frame(width: 5, height: 5) }
            if t.active { Circle().fill(Brand.ok).frame(width: 5, height: 5) }
        }
        .foregroundStyle(selected ? .white : Brand.accent)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(selected ? Brand.accent : Brand.accentSoft))
        .offset(x: 2, y: 4)
        .onTapGesture { if let p = segment.events.first { onTap(p) } }
        .help(t.shownPrompt)
    }

    /// Ko'rsatkich ostidagi hodisa haqida qisqa yozuv
    @ViewBuilder
    private var tooltip: some View {
        if let h = hovered, let i = segment.events.firstIndex(where: { $0.id == h }) {
            let e = segment.events[i], p = point(i)
            VStack(alignment: .leading, spacing: 2) {
                Text(e.label + (e.agent.map { " · " + $0 } ?? "")).font(.caption2.weight(.semibold)).foregroundStyle(e.lane.color)
                Text(e.text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "**", with: "")).font(.caption).lineLimit(3).frame(maxWidth: 240, alignment: .leading)
                Text(Fmt.clock.string(from: e.date)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            .padding(8)
            .surface(radius: 10)
            .fixedSize()
            .offset(x: min(max(4, p.x - 40), width - 60), y: p.y + 16)
            .allowsHitTesting(false)
            .zIndex(10)
        }
    }
}
