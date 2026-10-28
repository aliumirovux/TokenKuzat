import SwiftUI
import AppKit
import TokenKuzatCore

// n8n uslubidagi jarayon oqimi (bitta so'rov yoki butun sessiya):
//
//  (So'rov) ──▶ [ Asosiy agent ] ──────────────────────────────▶ [Natija]
//                 Model ┆  ┆ Asboblar                    ╭──▶ [Yordamchi] ──╮
//                  ◯    ◯  ◯  ◯   (ishlatilish tartibida) │      ┆          │
//               Opus  Fayl Term MCP                        │      ◯ ◯        │
//                                                          ╰──────────────────╯
// Uzuq chiziq — agent ishlatgan asbob; hozir bajarilayotganiga boradigan chiziq oqib turadi.

// MARK: - Ma'lumot

struct FlowBubble: Identifiable {
    let id: String
    let ownerId: String
    /// nil — model tuguni
    let category: ToolCategory?
    let title: String
    let detail: String
    let calls: Int
    let errors: Int
    let busy: Bool
    let recent: Bool
}

struct FlowLane: Identifiable {
    var id: String { agent.id }
    let agent: AgentSnap
    let steps: [StepSnap]
    let bubbles: [FlowBubble]
}

struct FlowResult {
    let active: Bool
    let duration: TimeInterval
    let tokens: TokenCounts
    let steps: Int
    let errors: Int
    let changedFiles: [String]
}

struct FlowModel {
    let prompt: String
    let main: FlowLane?
    let helpers: [FlowLane]
    let result: FlowResult

    /// `turnId` — nil bo'lsa butun sessiya
    init(session: SessionSnap, turnId: Int?, now: Date) {
        let turn = turnId.flatMap { id in session.turns.first { $0.id == id } }
        let nextStart = turnId.flatMap { id in session.turns.first { $0.id == id + 1 }?.start }
        func inTurn(_ s: StepSnap) -> Bool { turnId == nil || s.turn == turnId }
        func inRange(_ d: Date?) -> Bool {
            guard let turn else { return true }
            guard let d else { return false }
            return d >= turn.start && (nextStart.map { d < $0 } ?? true)
        }

        prompt = turn?.prompt ?? session.title

        if let m = session.main {
            let steps = m.steps.filter(inTurn)
            let model = FlowBubble(id: m.id + "#model", ownerId: m.id, category: nil, title: "Claude",
                                   detail: session.model.isEmpty ? "model" : session.model,
                                   calls: m.calls, errors: 0, busy: m.state == .running && steps.last?.status != .running,
                                   recent: m.state != .idle)
            main = FlowLane(agent: m, steps: steps, bubbles: [model] + FlowModel.bubbles(steps, owner: m.id, now: now))
        } else {
            main = nil
        }

        helpers = session.agents.filter { !$0.isMain }.compactMap { a in
            let steps = a.steps.filter(inTurn)
            guard !steps.isEmpty || inRange(a.firstActivity) else { return nil }
            return FlowLane(agent: a, steps: steps, bubbles: FlowModel.bubbles(steps, owner: a.id, now: now))
        }
        .sorted { ($0.agent.firstActivity ?? .distantPast) < ($1.agent.firstActivity ?? .distantPast) }

        let all = ([main].compactMap { $0 } + helpers).flatMap(\.steps)
        let changed = Array(Set(all.filter { $0.access == .write }.map(\.targetName))).sorted()
        if let turn {
            result = FlowResult(active: turn.active, duration: turn.duration, tokens: turn.tokens,
                                steps: turn.steps, errors: turn.errors, changedFiles: changed)
        } else {
            let start = session.turns.first?.start ?? session.agents.compactMap(\.firstActivity).min() ?? now
            result = FlowResult(active: session.state != .idle,
                                duration: (session.lastActivity ?? now).timeIntervalSince(start),
                                tokens: session.tokens, steps: all.count,
                                errors: all.filter { $0.status == .failed }.count, changedFiles: changed)
        }
    }

    /// Asboblar turi bo'yicha, birinchi ishlatilgan tartibda
    static func bubbles(_ steps: [StepSnap], owner: String, now: Date) -> [FlowBubble] {
        var order: [ToolCategory] = []
        var by: [ToolCategory: [StepSnap]] = [:]
        for s in steps {
            if by[s.category] == nil { order.append(s.category) }
            by[s.category, default: []].append(s)
        }
        return order.map { cat in
            let list = by[cat] ?? []
            let last = list.last
            let distinct = Set(list.map(\.targetName)).count
            let detail = (last?.targetName ?? "") + (distinct > 1 ? "  +\(distinct - 1)" : "")
            return FlowBubble(id: owner + "#" + cat.rawValue, ownerId: owner, category: cat, title: cat.title,
                              detail: detail, calls: list.count,
                              errors: list.filter { $0.status == .failed }.count,
                              busy: last?.status == .running,
                              recent: last.map { now.timeIntervalSince($0.date) < 20 } ?? false)
        }
    }
}

// MARK: - Joylashuv

private enum F {
    static let pad: CGFloat = 56
    static let trig: CGFloat = 104
    static let mainW: CGFloat = 300
    static let mainH: CGFloat = 104
    static let helperW: CGFloat = 270
    static let helperH: CGFloat = 84
    static let resultW: CGFloat = 104
    static let bubble: CGFloat = 70
    static let bubbleSmall: CGFloat = 52
    static let bubbleGap: CGFloat = 128
    static let bubbleGapSmall: CGFloat = 104
    static let labelW: CGFloat = 130
    /// Tugun ostidan dumaloq tugunlar markazigacha
    static let drop: CGFloat = 118
    static let dropSmall: CGFloat = 96
    static let colGap: CGFloat = 110
    static let laneGap: CGFloat = 36
}

private struct FlowEdge: Identifiable {
    enum Kind { case main, sub }
    let id: String
    let from: CGPoint
    let to: CGPoint
    let kind: Kind
    let live: Bool
    let color: Color
    /// sub — pastga tushadigan egri (port pastda)
    let vertical: Bool
}

private struct FlowLayout {
    var size = CGSize.zero
    var trigger = CGPoint.zero
    var main = CGPoint.zero
    var result = CGPoint.zero
    var helpers: [String: CGPoint] = [:]
    var bubbles: [String: CGPoint] = [:]
    var edges: [FlowEdge] = []

    init() {}

    init(_ m: FlowModel) {
        let rowY = F.pad + F.mainH / 2 + 10
        trigger = CGPoint(x: F.pad + F.trig / 2, y: rowY)
        let mainLeft = trigger.x + F.trig / 2 + F.colGap * 0.8
        main = CGPoint(x: mainLeft + F.mainW / 2, y: rowY)
        let mainRunning = m.main?.agent.state == .running
        edges.append(FlowEdge(id: "t>m", from: CGPoint(x: trigger.x + F.trig / 2, y: rowY),
                              to: CGPoint(x: mainLeft, y: rowY), kind: .main, live: mainRunning,
                              color: Palette.state(m.main?.agent.state ?? .idle), vertical: false))

        var bottom = rowY + F.mainH / 2
        var right = mainLeft + F.mainW
        if let lane = m.main {
            let by = rowY + F.mainH / 2 + F.drop
            placeBubbles(lane, centerX: main.x, topY: rowY + F.mainH / 2, y: by, d: F.bubble, gap: F.bubbleGap,
                         modelPortX: main.x - F.mainW * 0.3, toolPortX: main.x + F.mainW * 0.1)
            if let last = lane.bubbles.last, let p = bubbles[last.id] { right = max(right, p.x + F.labelW / 2) }
            bottom = by + F.bubble / 2 + 52
        }

        // Yordamchilar — asosiy qatordan pastda, router chiqishlari kabi tarmoqlanadi
        let helperLeft = right + F.colGap
        var y = rowY + F.mainH / 2 + 24
        var helpersRight = helperLeft
        for lane in m.helpers {
            let c = CGPoint(x: helperLeft + F.helperW / 2, y: y + F.helperH / 2)
            helpers[lane.agent.id] = c
            edges.append(FlowEdge(id: "m>" + lane.id, from: CGPoint(x: main.x + F.mainW / 2, y: rowY),
                                  to: CGPoint(x: helperLeft, y: c.y), kind: .main, live: lane.agent.state == .running,
                                  color: Palette.state(lane.agent.state), vertical: false))
            var laneBottom = y + F.helperH
            helpersRight = max(helpersRight, helperLeft + F.helperW)
            if !lane.bubbles.isEmpty {
                let by = c.y + F.helperH / 2 + F.dropSmall
                placeBubbles(lane, centerX: c.x, topY: c.y + F.helperH / 2, y: by, d: F.bubbleSmall, gap: F.bubbleGapSmall,
                             modelPortX: nil, toolPortX: c.x)
                if let last = lane.bubbles.last, let p = bubbles[last.id] { helpersRight = max(helpersRight, p.x + F.labelW / 2) }
                laneBottom = by + F.bubbleSmall / 2 + 48
            }
            y = laneBottom + F.laneGap
        }
        bottom = max(bottom, y)

        let resultLeft = max(main.x + F.mainW / 2 + F.colGap * 1.4, m.helpers.isEmpty ? 0 : helpersRight + F.colGap * 0.6)
        result = CGPoint(x: resultLeft + F.resultW / 2, y: rowY)
        edges.append(FlowEdge(id: "m>r", from: CGPoint(x: main.x + F.mainW / 2, y: rowY),
                              to: CGPoint(x: resultLeft, y: rowY), kind: .main, live: mainRunning,
                              color: Palette.state(m.main?.agent.state ?? .idle), vertical: false))
        for lane in m.helpers {
            guard let c = helpers[lane.agent.id] else { continue }
            edges.append(FlowEdge(id: lane.id + ">r", from: CGPoint(x: c.x + F.helperW / 2, y: c.y),
                                  to: CGPoint(x: resultLeft, y: rowY), kind: .main, live: false,
                                  color: Palette.state(lane.agent.state == .idle ? .idle : .waiting), vertical: false))
        }

        size = CGSize(width: resultLeft + F.resultW + F.labelW / 2 + F.pad, height: max(bottom, rowY + 140) + F.pad)
    }

    private mutating func placeBubbles(_ lane: FlowLane, centerX: CGFloat, topY: CGFloat, y: CGFloat,
                                       d: CGFloat, gap: CGFloat, modelPortX: CGFloat?, toolPortX: CGFloat) {
        let n = CGFloat(lane.bubbles.count)
        // Tugun ostidan chapdan boshlab, kerak bo'lsa o'ngga cho'ziladi
        let startX = centerX - min(gap * (n - 1) / 2, F.mainW / 2 - d / 2)
        for (i, b) in lane.bubbles.enumerated() {
            let p = CGPoint(x: startX + CGFloat(i) * gap, y: y)
            bubbles[b.id] = p
            let portX = b.category == nil ? (modelPortX ?? toolPortX) : toolPortX
            edges.append(FlowEdge(id: "s" + b.id, from: CGPoint(x: portX, y: topY + (modelPortX == nil ? 0 : 26)), to: CGPoint(x: p.x, y: y - d / 2),
                                  kind: .sub, live: b.busy, color: b.category?.color ?? Palette.main, vertical: true))
        }
    }
}

// MARK: - Canvas

struct FlowCanvas: View {
    let session: SessionSnap
    let model: FlowModel
    let mode: CountMode
    let selectedAgent: String?
    let selectedBubble: String?
    let onSelectAgent: (String) -> Void
    let onSelectBubble: (FlowBubble) -> Void
    @State private var zoom: CGFloat = 1
    @State private var appearedAt = Date.distantPast
    @State private var entered = false

    var body: some View {
        let layout = FlowLayout(model)
        GeometryReader { geo in
            let fit = min(1, geo.size.width / layout.size.width, geo.size.height / layout.size.height)
            let scale = min(2, max(0.3, fit * zoom))
            let w = layout.size.width * scale, h = layout.size.height * scale
            let content = canvas(layout)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: w, height: h, alignment: .topLeading)
            Group {
                if w <= geo.size.width + 1 && h <= geo.size.height + 1 {
                    content.frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ScrollView([.horizontal, .vertical]) {
                        content.frame(minWidth: geo.size.width, minHeight: geo.size.height)
                    }
                }
            }
            .background(DotGridBackground())
            .overlay(alignment: .bottomTrailing) { zoomControls.padding(12) }
            .overlay(alignment: .bottomLeading) { FlowLegend().padding(12) }
        }
        .background(Color.clear)
    }

    private func canvas(_ l: FlowLayout) -> some View {
        ZStack(alignment: .topLeading) {
            FlowEdges(edges: l.edges, appearedAt: appearedAt).allowsHitTesting(false)

            TriggerShapeNode(prompt: model.prompt).position(l.trigger)
                .modifier(Enter(on: entered, delay: 0))
                .onTapGesture { if let m = model.main { onSelectAgent(m.agent.id) } }

            if let lane = model.main {
                FlowAgentNode(agent: lane.agent, steps: lane.steps.count, big: true,
                              selected: selectedAgent == lane.agent.id && selectedBubble == nil)
                    .position(l.main)
                    .modifier(Enter(on: entered, delay: 0.08))
                    .onTapGesture { onSelectAgent(lane.agent.id) }
                bubbles(lane, l, d: F.bubble)
            }

            ForEach(model.helpers) { lane in
                if let p = l.helpers[lane.agent.id] {
                    FlowAgentNode(agent: lane.agent, steps: lane.steps.count, big: false,
                                  selected: selectedAgent == lane.agent.id && selectedBubble == nil)
                        .position(p)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                        .onTapGesture { onSelectAgent(lane.agent.id) }
                    bubbles(lane, l, d: F.bubbleSmall)
                }
            }

            ResultNode(result: model.result, mode: mode).position(l.result)
                .modifier(Enter(on: entered, delay: 0.5))
                .onTapGesture { if let m = model.main { onSelectAgent(m.agent.id) } }
        }
        .frame(width: l.size.width, height: l.size.height, alignment: .topLeading)
        .animation(Motion.spring, value: signature)
        .onAppear { replayEntrance() }
        .onChange(of: model.prompt) { _ in replayEntrance() }
    }

    /// Sxema ochilganda yoki so'rov almashganda: tugunlar birin-ketin paydo bo'ladi, chiziqlar chiziladi
    private func replayEntrance() {
        entered = false
        appearedAt = Date()
        DispatchQueue.main.async { entered = true }
    }

    /// Tugunlar to'plami o'zgarganda (yangi asbob, yangi yordamchi) — yumshoq qayta joylashuv
    private var signature: String {
        ([model.main].compactMap { $0 } + model.helpers).map { "\($0.id):\($0.bubbles.map(\.id).joined())" }.joined(separator: "|")
    }

    @ViewBuilder
    private func bubbles(_ lane: FlowLane, _ l: FlowLayout, d: CGFloat) -> some View {
        ForEach(lane.bubbles) { b in
            if let p = l.bubbles[b.id] {
                ToolBubbleNode(bubble: b, diameter: d, selected: selectedBubble == b.id)
                    .position(x: p.x, y: p.y + 22)   // yozuv bilan birga: markaz doira markaziga to'g'ri keladi
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                    .modifier(Enter(on: entered, delay: 0.25 + Double(lane.bubbles.firstIndex { $0.id == b.id } ?? 0) * 0.06))
                    .onTapGesture { onSelectBubble(b) }
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            zoomButton("minus", "Kichraytirish") { zoom = max(0.4, zoom / 1.25) }
            Divider().frame(height: 16)
            zoomButton("arrow.up.left.and.arrow.down.right", "Oynaga sig'dirish") { zoom = 1 }
            Divider().frame(height: 16)
            zoomButton("plus", "Kattalashtirish") { zoom = min(3, zoom * 1.25) }
        }
        .surface(radius: 10, interactive: true)
    }

    private func zoomButton(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Chiziqlar

private struct FlowEdges: View {
    let edges: [FlowEdge]
    /// Kirish animatsiyasi: shu paytdan boshlab chiziqlar 0,9 s ichida «chiziladi»
    var appearedAt = Date.distantPast

    var body: some View {
        let animated = edges.contains(where: \.live)
        let entering = Date().timeIntervalSince(appearedAt) < 1.4
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animated && !entering)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            let k = min(1, max(0, ctx.date.timeIntervalSince(appearedAt) / 0.9))
            let progress = 1 - pow(1 - k, 3)   // ease-out
            Canvas { g, _ in
                for (i, e) in edges.enumerated() {
                    // Asosiy chiziqlar birinchi, asbob chiziqlari biroz kechroq
                    let delay = e.kind == .main ? 0 : 0.15 + Double(i % 6) * 0.04
                    let pr = min(1, max(0, (progress - delay) / (1 - delay)))
                    guard pr > 0 else { continue }
                    let path = (e.vertical ? vCurve(e.from, e.to) : hCurve(e.from, e.to)).trimmedPath(from: 0, to: pr)
                    switch e.kind {
                    case .main where e.live && pr >= 1:
                        // Jonli: ma'lumot paketlari ikki tomonga yuradi
                        DataFlow.draw(&g, path: path, color: e.color, t: t, seed: Double(i) * 0.37, width: 2.2)
                    case .main:
                        g.stroke(path, with: .color(Color.primary.opacity(0.35)), lineWidth: 2)
                    case .sub where e.live && pr >= 1:
                        DataFlow.draw(&g, path: path, color: e.color, t: t, seed: Double(i) * 0.37, width: 1.8)
                    case .sub:
                        g.stroke(path, with: .color(Color.primary.opacity(0.32)),
                                 style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [7, 6]))
                    }
                    let r: CGFloat = 4.5
                    for p in (pr >= 1 ? [e.from, e.to] : [e.from]) {
                        g.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                               with: .color(Color(nsColor: .tertiaryLabelColor)))
                    }
                }
            }
        }
    }

    private func hCurve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        let dx = max(50, abs(b.x - a.x) * 0.5)
        p.move(to: a)
        p.addCurve(to: b, control1: CGPoint(x: a.x + dx, y: a.y), control2: CGPoint(x: b.x - dx, y: b.y))
        return p
    }

    private func vCurve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        let dy = max(30, (b.y - a.y) * 0.55)
        p.move(to: a)
        p.addCurve(to: b, control1: CGPoint(x: a.x, y: a.y + dy), control2: CGPoint(x: b.x, y: b.y - dy))
        return p
    }
}

private struct DotGridBackground: View {
    var body: some View {
        Canvas { g, size in
            let step: CGFloat = 24
            let c = Color.primary.opacity(0.14)
            var y: CGFloat = step / 2
            while y < size.height {
                var x: CGFloat = step / 2
                while x < size.width {
                    g.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(c))
                    x += step
                }
                y += step
            }
        }
    }
}

// MARK: - Tugunlar



/// n8n trigger tuguni kabi: chap tomoni yumaloq
private struct TriggerShapeNode: View {
    let prompt: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "person.wave.2.fill").font(.system(size: 32, weight: .medium))
                .foregroundStyle(Palette.cacheRead)
                .frame(width: F.trig, height: F.trig)
                .modifier(Surface(shape: UnevenRoundedShape(left: F.trig / 2, right: 18), tint: Palette.cacheRead))
            VStack(spacing: 2) {
                Text("Sizning so'rovingiz").font(.caption.weight(.semibold))
                Text(prompt).font(.caption2).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(width: 170)
        }
        .offset(y: 30)   // yozuv tugun ostida; tugun markazi qatorda qoladi
        .contentShape(Rectangle())
    }
}

/// Chap va o'ng burchaklari turlicha yumaloq to'rtburchak (macOS 13 da UnevenRoundedRectangle yo'q)
private struct UnevenRoundedShape: Shape {
    let left: CGFloat
    let right: CGFloat

    func path(in r: CGRect) -> Path {
        var p = Path()
        let l = min(left, r.height / 2), rr = min(right, r.height / 2)
        p.move(to: CGPoint(x: r.minX + l, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rr, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - rr, y: r.minY + rr), radius: rr, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - rr))
        p.addArc(center: CGPoint(x: r.maxX - rr, y: r.maxY - rr), radius: rr, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX + l, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + l, y: r.maxY - l), radius: l, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + l))
        p.addArc(center: CGPoint(x: r.minX + l, y: r.minY + l), radius: l, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

private struct FlowAgentNode: View {
    let agent: AgentSnap
    let steps: Int
    let big: Bool
    let selected: Bool

    var body: some View {
        let w = big ? F.mainW : F.helperW, h = big ? F.mainH : F.helperH
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(spacing: 14) {
            Image(systemName: agentSymbol(agent))
                .font(.system(size: big ? 30 : 22, weight: .medium))
                .foregroundStyle(agent.isMain ? Palette.main : Palette.agents)
                .frame(width: big ? 44 : 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(agent.isMain ? "Asosiy agent" : agent.title)
                        .font((big ? Font.headline : .callout).weight(.semibold)).lineLimit(1)
                    StateDot(state: agent.state, size: 7)
                }
                Text(agent.lastAction).font(.caption).foregroundStyle(agent.state == .idle ? .secondary : .primary).lineLimit(2)
                Text([agent.subtitle, steps > 0 ? "\(steps) qadam" : ""].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(width: w, height: h)
        .modifier(Surface(shape: shape, tint: agent.state == .running ? .green : nil, interactive: true,
                               stroke: selected ? .accentColor : nil))
        .overlay { if agent.state == .running { LiveBorder(shape: shape, color: Brand.ok, lineWidth: 2) } }
        .scaleEffect(selected ? 1.02 : 1)
        .animation(Motion.spring, value: selected)
        .overlay(alignment: .topLeading) {
            if big {
                // Port yorliqlari — chiziq boshlanadigan nuqta ustida, fonli: chiziq yorliq tagidan chiqadi
                portPill("Model", Brand.accent).position(x: w * 0.2, y: h + 14)
                portPill("Asboblar", .secondary).position(x: w * 0.6, y: h + 14)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .contentShape(shape)
        .help("Bosing — jarayon va tokenlar")
    }
}

func portPill(_ text: String, _ color: Color) -> some View {
    HStack(spacing: 4) {
        Circle().fill(color).frame(width: 5, height: 5)
        Text(text)
    }
    .font(.system(size: 10.5, weight: .semibold))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 8).padding(.vertical, 3)
    .background(Capsule().fill(Brand.canvas))
    .overlay(Capsule().stroke(Brand.line))
    .fixedSize()
}

private struct ToolBubbleNode: View {
    let bubble: FlowBubble
    let diameter: CGFloat
    let selected: Bool

    var body: some View {
        let color = bubble.category?.color ?? Palette.main
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Color.clear
                    .modifier(Surface(shape: Circle(), tint: bubble.busy || bubble.recent ? color : nil, interactive: true,
                                           stroke: selected ? .accentColor : nil))
                    .overlay {
                        Image(systemName: bubble.category?.symbol ?? "sparkles")
                            .font(.system(size: diameter * 0.36, weight: .medium))
                            .foregroundStyle(bubble.recent || bubble.busy ? color : color.opacity(0.75))
                    }
                    .overlay { if bubble.busy { LiveBorder(shape: Circle(), color: color, lineWidth: 2, period: 2.4) } }
                    .frame(width: diameter, height: diameter)
                if bubble.category != nil {
                    Text(bubble.errors > 0 ? "\(bubble.calls) · \(bubble.errors)!" : "\(bubble.calls)")
                        .font(.system(size: 9, weight: .bold)).monospacedDigit()
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(bubble.errors > 0 ? Color.red : color))
                        .foregroundStyle(.white)
                        .offset(x: 6, y: -2)
                }
            }
            .frame(width: diameter, height: diameter)
            VStack(spacing: 1) {
                Text(bubble.title).font(.caption.weight(.medium)).lineLimit(1)
                Text(bubble.detail).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            .frame(width: F.labelW)
        }
        .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
        .contentShape(Rectangle())
        .help(bubble.category == nil ? "Model" : "\(bubble.title): \(bubble.calls) chaqiruv — bosing, ro'yxat ochiladi")
    }
}

private struct ResultNode: View {
    let result: FlowResult
    let mode: CountMode

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        let color: Color = result.active ? .green : (result.errors > 0 ? .orange : .accentColor)
        VStack(spacing: 10) {
            ZStack {
                if result.active {
                    ProgressView().controlSize(.regular)
                } else {
                    Image(systemName: result.errors > 0 ? "checkmark.circle.trianglebadge.exclamationmark" : "checkmark.circle.fill")
                        .font(.system(size: 34, weight: .medium)).foregroundStyle(color)
                }
            }
            .frame(width: F.resultW, height: F.resultW)
            .modifier(Surface(shape: shape, tint: result.active ? .green : color))
            .overlay { if result.active { LiveBorder(shape: shape, color: Brand.ok, lineWidth: 2) } }
            VStack(spacing: 2) {
                Text(result.active ? "Ishlayapti…" : "Natija").font(.caption.weight(.semibold))
                Text("\(Alerts.duration(result.duration)) · \(Fmt.tokens(result.tokens.value(mode)))")
                    .font(.caption2.monospaced()).foregroundStyle(.secondary)
                Text("\(result.steps) qadam\(result.errors > 0 ? " · \(result.errors) xato" : "")")
                    .font(.caption2.monospaced()).foregroundStyle(result.errors > 0 ? .orange : .secondary)
                if !result.changedFiles.isEmpty {
                    Text("✎ \(result.changedFiles.count) fayl o'zgardi")
                        .font(.caption2.monospaced()).foregroundStyle(.orange)
                        .help(result.changedFiles.joined(separator: "\n"))
                }
            }
            .frame(width: 170)
        }
        .offset(y: 38)
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
        .contentShape(Rectangle())
    }
}

private struct FlowLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 5) {
                Rectangle().fill(Color.primary.opacity(0.4)).frame(width: 18, height: 2)
                Text("Jarayon")
            }
            HStack(spacing: 5) {
                DashLine().stroke(Color.primary.opacity(0.4), style: StrokeStyle(lineWidth: 1.6, dash: [4, 3]))
                    .frame(width: 18, height: 2)
                Text("Asbob")
            }
            HStack(spacing: 5) {
                Circle().fill(Color.green).frame(width: 7, height: 7)
                Text("Hozir ishlayapti")
            }
            Text("Raqam — chaqiruvlar").foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .surfaceCapsule()
    }

    private struct DashLine: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.midY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
            return p
        }
    }
}

/// Kirish animatsiyasi: tugun pastdan, kichikroq va xira holatdan o'z joyiga keladi
struct Enter: ViewModifier {
    let on: Bool
    let delay: Double

    func body(content: Content) -> some View {
        content
            .opacity(on ? 1 : 0)
            .scaleEffect(on ? 1 : 0.9)
            .offset(y: on ? 0 : 8)
            .animation(Motion.spring.delay(delay), value: on)
    }
}
