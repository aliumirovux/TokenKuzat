import SwiftUI
import AppKit
import TokenKuzatCore

// Sessiya xaritasi (n8n uslubida): chapdan o'ngga so'rov kartalari, har biridan pastga — o'sha so'rovda
// ishlatilgan asboblar. Kontekst tugab davom ettirilgan sessiyalar shu chiziqning davomiga ulanadi.
// Cheksiz kanvas: sudrab surish, g'ildirak/trackpad bilan siljitish, ⌘ + g'ildirak yoki chimdish bilan zoom.

// MARK: - Bog'liq sessiyalar

enum SessionChain {
    /// Davom ettirilgan sessiyani oldingisi bilan bog'lash uchun eng katta oraliq
    static let maxGap: TimeInterval = 6 * 3600

    /// `session` qaysi zanjirda bo'lsa — butun zanjir, eskidan yangiga.
    /// Bog'lanish faqat aniq belgi bo'lganda: keyingi sessiyaning birinchi so'rovi — «davom ettirildi» xulosasi.
    static func chain(for session: SessionSnap, in all: [SessionSnap]) -> [SessionSnap] {
        var out = [session]
        var seen: Set<String> = [session.id]
        var cur = session
        while let p = previous(of: cur, in: all), seen.insert(p.id).inserted {
            out.insert(p, at: 0)
            cur = p
        }
        cur = session
        while let n = all.first(where: { !seen.contains($0.id) && previous(of: $0, in: all)?.id == cur.id }) {
            seen.insert(n.id)
            out.append(n)
            cur = n
        }
        return out
    }

    private static func previous(of s: SessionSnap, in all: [SessionSnap]) -> SessionSnap? {
        guard let first = s.turns.first, first.isContinuation else { return nil }
        return all
            .filter { o in
                guard o.id != s.id, o.project == s.project, let la = o.lastActivity else { return false }
                return la <= first.start.addingTimeInterval(60) && first.start.timeIntervalSince(la) < maxGap
            }
            .max { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }
    }
}

extension ToolCategory {
    /// Belgi rangi: Terminal'ning to'q kulrangi qorong'i fonda ko'rinmaydi — u yerda oddiy ikkilamchi rang
    var iconColor: Color { self == .shell ? .secondary : color }
}

extension TurnSnap {
    /// Ro'yxat va chiplarda ko'rinadigan matn: xulosa matni o'rniga tushunarli yozuv
    var shownPrompt: String { isContinuation ? "Kontekst yangilandi — ish davom etdi" : prompt }
}

/// Xaritada ochilgan so'rov zanjirining bir bo'g'ini: asbob qadami, o'ylash, javob yoki «hozir o'ylayapti».
/// `agent` — yordamchi agent nomi (asosiy agentda nil)
struct MapStep: Identifiable {
    enum Item {
        case step(StepSnap)
        /// Ketma-ket bir xil turdagi qadamlar (ko'pi bilan oxirgisi ko'rsatiladi)
        case group([StepSnap])
        /// `final` — so'rovning yakuniy javobi
        case note(NoteSnap, final: Bool)
        /// Model hozir o'ylayapti yoki javob yozyapti (asbob ishlamayapti)
        case live(since: Date)
    }
    let id: String
    let item: Item
    let agent: String?
    let date: Date

    init(step: StepSnap, agent: String?) {
        id = step.id; item = .step(step); self.agent = agent; date = step.date
    }

    init(note: NoteSnap, final: Bool) {
        id = note.id; item = .note(note, final: final); agent = note.agent; date = note.date
    }

    /// Guruhda eng ko'p uchragan asbob turi
    static func dominant(_ g: [StepSnap]) -> ToolCategory? {
        Dictionary(grouping: g, by: \.category).max { $0.value.count < $1.value.count }?.key
    }

    init(group: [StepSnap], agent: String?) {
        id = "g" + (group.first?.id ?? ""); item = .group(group); self.agent = agent; date = group.first?.date ?? .now
    }

    init(liveSince: Date) {
        id = "live"; item = .live(since: liveSince); agent = nil; date = liveSince
    }

    /// Zanjirdagi balandligi: matnli o'ylash va javob — kattaroq
    /// Chiziq ustidagi yupqa yorliq: asbob qadamlari, o'ylash va «O'ylayapti…». Katta karta — faqat xabar va javob
    var isPill: Bool {
        if case .note(let n, _) = item { return n.kind == .thinking }
        return true
    }

    var height: CGFloat {
        if isPill { return 30 }
        if case .note(_, let final) = item { return final ? 112 : 92 }
        return M.stepH
    }

    var color: Color {
        switch item {
        case .step(let s): return s.category.color
        case .group(let g): return MapStep.dominant(g)?.color ?? .secondary
        case .note(let n, _): return n.kind == .reply ? Brand.ok : Brand.inkFill
        case .live: return Brand.inkFill
        }
    }

    var isLive: Bool {
        switch item {
        case .step(let s): return s.status == .running
        case .group(let g): return g.contains { $0.status == .running }
        case .note: return false
        case .live: return true
        }
    }
}

// MARK: - Joylashuv

private enum M {
    static let cardW: CGFloat = 280
    static let cardH: CGFloat = 144
    static let pillW: CGFloat = 176
    static let pillH: CGFloat = 40
    static let endD: CGFloat = 64
    static let gap: CGFloat = 76
    static let rowY: CGFloat = 110
    static let toolDrop: CGFloat = 112
    static let toolD: CGFloat = 46
    static let toolStep: CGFloat = 68
    static let maxTools = 4
    static let pad: CGFloat = 60
    static let stepH: CGFloat = 52
    static let stepGap: CGFloat = 10
    static let stepTop: CGFloat = 46
    static let maxSteps = 12
    /// Qadamlarsiz xarita balandligi — masshtab shu bo'yicha tanlanadi
    static let baseH: CGFloat = rowY + cardH / 2 + toolDrop + toolD + 50
}

private struct MapNode: Identifiable {
    enum Kind {
        case start(Date)
        case divider(title: String, subtitle: String)
        case turn(TurnSnap, sessionId: String, previousPrompt: String?)
        case tool(TurnTool, sessionId: String)
        case more(Int)
        case step(MapStep, sessionId: String, turnId: Int)
        case earlier(Int)
        case end(active: Bool, at: Date?)
    }
    let id: String
    let kind: Kind
    let center: CGPoint
    let size: CGSize

    var rect: CGRect { CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height) }
    var isMainRow: Bool {
        switch kind {
        case .tool, .more, .step, .earlier: return false
        default: return true
        }
    }
}

private struct MapEdge: Identifiable {
    let id: String
    let from: CGPoint
    let to: CGPoint
    let vertical: Bool
    let live: Bool
    let color: Color
}

private struct MapLayout {
    var nodes: [MapNode] = []
    var edges: [MapEdge] = []
    var size = CGSize.zero
    /// Oxirgi so'rov kartasi — «Hozirgiga» va ergashish uchun
    var lastTurn: MapNode?

    /// Qadamlar zanjiri pastga qarab qayergacha boradi (ergashish uchun)
    var stepsBottom: CGFloat?

    /// - Parameters:
    ///   - expanded: ochilgan so'rov kartasi («sessiya#raqam») — uning ostida asboblar o'rniga qadamlar zanjiri
    init(chain: [SessionSnap], expanded: String? = nil, steps: [MapStep] = []) {
        var x = M.pad
        var prev: MapNode?
        var lastReal: String?
        let active = chain.last.map { $0.state != .idle } ?? false

        func add(_ n: MapNode, live: Bool = false) {
            if let p = prev {
                edges.append(MapEdge(id: p.id + ">" + n.id,
                                     from: CGPoint(x: p.rect.maxX, y: M.rowY), to: CGPoint(x: n.rect.minX, y: M.rowY),
                                     vertical: false, live: live, color: Brand.ok))
            }
            nodes.append(n)
            prev = n
            x = n.rect.maxX + M.gap
        }
        func pill(_ id: String, _ kind: MapNode.Kind) -> MapNode {
            MapNode(id: id, kind: kind, center: CGPoint(x: x + M.pillW / 2, y: M.rowY), size: CGSize(width: M.pillW, height: M.pillH))
        }

        for (si, s) in chain.enumerated() {
            let first = s.turns.first
            if si == 0 {
                add(pill("start", .start(first?.start ?? s.lastActivity ?? Date())))
            } else if first?.isContinuation != true {
                add(pill("s\(si)", .divider(title: "Yangi sessiya", subtitle: first.map { Fmt.hourMinute.string(from: $0.start) } ?? "")))
            }
            for t in s.turns {
                if t.isContinuation {
                    let sub = (si > 0 && t.id == first?.id ? "yangi sessiya · " : "") + Fmt.hourMinute.string(from: t.start)
                    add(pill("\(s.id)#\(t.id)c", .divider(title: "Kontekst yangilandi", subtitle: sub)))
                }
                let card = MapNode(id: "\(s.id)#\(t.id)",
                                   kind: .turn(t, sessionId: s.id, previousPrompt: t.isContinuation ? lastReal : nil),
                                   center: CGPoint(x: x + M.cardW / 2, y: M.rowY), size: CGSize(width: M.cardW, height: M.cardH))
                add(card, live: t.active)
                lastTurn = card
                if !t.isContinuation { lastReal = t.prompt }
                if card.id == expanded && !steps.isEmpty {
                    placeSteps(steps, card: card, sessionId: s.id, turnId: t.id)
                } else {
                    placeTools(t, card: card, sessionId: s.id)
                }
            }
        }
        let lastAt = chain.last?.turns.last?.end ?? chain.last?.lastActivity
        add(MapNode(id: "end", kind: .end(active: active, at: lastAt),
                    center: CGPoint(x: x + M.endD / 2, y: M.rowY), size: CGSize(width: M.endD, height: M.endD)),
            live: active)
        let bottom = max(M.baseH, (stepsBottom ?? 0) + 50)
        size = CGSize(width: x - M.gap + M.pad, height: bottom)
    }

    /// Qadamlar karta ostidan pastga, vaqt bo'yicha ketma-ket; ko'p bo'lsa — oxirgilari, tepada «+N oldingi»
    private mutating func placeSteps(_ all: [MapStep], card: MapNode, sessionId: String, turnId: Int) {
        let shown = Array(all.suffix(M.maxSteps))
        let hidden = all.count - shown.count
        var y = card.rect.maxY + M.stepTop
        var prevBottom = CGPoint(x: card.center.x, y: card.rect.maxY)
        func link(_ n: MapNode, live: Bool, color: Color) {
            edges.append(MapEdge(id: "e" + n.id, from: prevBottom, to: CGPoint(x: n.center.x, y: n.rect.minY),
                                 vertical: true, live: live, color: color))
            prevBottom = CGPoint(x: n.center.x, y: n.rect.maxY)
        }
        if hidden > 0 {
            let n = MapNode(id: card.id + "/earlier", kind: .earlier(hidden),
                            center: CGPoint(x: card.center.x, y: y + 15), size: CGSize(width: 170, height: 30))
            nodes.append(n)
            link(n, live: false, color: .secondary)
            y = n.rect.maxY + M.stepGap
        }
        for st in shown {
            let n = MapNode(id: card.id + "/s/" + st.id, kind: .step(st, sessionId: sessionId, turnId: turnId),
                            center: CGPoint(x: card.center.x, y: y + st.height / 2), size: CGSize(width: M.cardW, height: st.height))
            nodes.append(n)
            link(n, live: st.isLive, color: st.color)
            y = n.rect.maxY + M.stepGap
        }
        stepsBottom = y
    }

    private mutating func placeTools(_ t: TurnSnap, card: MapNode, sessionId: String) {
        let shown = Array(t.tools.prefix(M.maxTools))
        let extra = t.tools.count - shown.count
        let n = shown.count + (extra > 0 ? 1 : 0)
        guard n > 0 else { return }
        let y = card.rect.maxY + M.toolDrop
        let x0 = card.center.x - CGFloat(n - 1) * M.toolStep / 2
        let port = CGPoint(x: card.center.x, y: card.rect.maxY)
        for (i, tool) in shown.enumerated() {
            let c = CGPoint(x: x0 + CGFloat(i) * M.toolStep, y: y)
            let node = MapNode(id: card.id + "/" + tool.id, kind: .tool(tool, sessionId: sessionId),
                               center: c, size: CGSize(width: M.toolStep, height: M.toolD + 30))
            nodes.append(node)
            edges.append(MapEdge(id: node.id, from: port, to: CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 vertical: true, live: tool.busy, color: tool.category.color))
        }
        if extra > 0 {
            let c = CGPoint(x: x0 + CGFloat(shown.count) * M.toolStep, y: y)
            nodes.append(MapNode(id: card.id + "/more", kind: .more(extra), center: c,
                                 size: CGSize(width: M.toolStep, height: M.toolD + 30)))
            edges.append(MapEdge(id: card.id + "/more", from: port, to: CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 vertical: true, live: false, color: .secondary))
        }
    }
}

// MARK: - G'ildirak

/// Kursor xarita ustida bo'lganda g'ildirak/trackpad hodisalarini xaritaga beradi (sahifa aylanmaydi)
private final class WheelMonitor: ObservableObject {
    var active = false
    var onWheel: ((NSEvent) -> Void)?
    private var token: Any?

    func start() {
        guard token == nil else { return }
        token = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] e in
            guard let self, self.active, let f = self.onWheel else { return e }
            f(e)
            return nil
        }
    }

    func stop() {
        if let token { NSEvent.removeMonitor(token) }
        token = nil
    }

    deinit { stop() }
}

// MARK: - Xarita

struct SessionMapView: View {
    let chain: [SessionSnap]
    let mode: CountMode
    let selectedTurn: String?
    /// Ochilgan so'rov qadamlari (eskidan yangiga)
    var steps: [MapStep] = []
    /// Oxirgi sessiya ruxsat kutayotgan bo'lsa — yakuniy tugunda ko'rsatiladi
    var waiting: HookNotice? = nil
    let onSelectTurn: (_ sessionId: String, _ turnId: Int) -> Void
    let onSelectTool: (_ sessionId: String, _ turnId: Int, _ category: ToolCategory) -> Void
    /// O'ylash yoki javob kartasi bosildi — to'liq matn o'ng panelda
    var onSelectNote: (_ sessionId: String, _ note: NoteSnap) -> Void = { _, _ in }

    @State private var scale: CGFloat = 0.9
    @State private var pan = CGSize.zero
    @State private var follow = true
    @State private var placed = false
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?
    @State private var cursor: CGPoint?
    @State private var viewport = CGSize.zero
    @State private var world = CGSize.zero
    @StateObject private var wheel = WheelMonitor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let layout = MapLayout(chain: chain, expanded: selectedTurn ?? lastTurnId, steps: steps)
        GeometryReader { geo in
            let vs = geo.size
            let visible = CGRect(x: -pan.width / scale, y: -pan.height / scale,
                                 width: vs.width / scale, height: vs.height / scale).insetBy(dx: -80, dy: -80)
            let detail = scale >= 0.5
            ZStack(alignment: .topLeading) {
                MapGrid(scale: scale, pan: pan)
                MapEdges(edges: layout.edges.filter { detail || !$0.vertical }, scale: scale, pan: pan,
                         reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                ForEach(layout.nodes.filter { $0.rect.intersects(visible) && (detail || $0.isMainRow) }) { n in
                    node(n)
                        .frame(width: n.size.width, height: n.size.height)
                        .scaleEffect(scale)
                        .position(screen(n.center))
                }
            }
            .frame(width: vs.width, height: vs.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { v in
                        if dragStart == nil { dragStart = pan; follow = false }
                        pan = clamped(CGSize(width: dragStart!.width + v.translation.width,
                                             height: dragStart!.height + v.translation.height))
                    }
                    .onEnded { _ in dragStart = nil }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { m in
                        if pinchStart == nil { pinchStart = scale; follow = false }
                        zoom(to: pinchStart! * m, around: cursor ?? CGPoint(x: vs.width / 2, y: vs.height / 2))
                    }
                    .onEnded { _ in pinchStart = nil }
            )
            .onContinuousHover { phase in
                switch phase {
                case .active(let p): cursor = p; wheel.active = true
                case .ended: cursor = nil; wheel.active = false
                }
            }
            .overlay(alignment: .bottomLeading) { controls(layout, vs).padding(12) }
            .overlay(alignment: .bottomTrailing) {
                MiniMap(layout: layout, scale: scale, pan: pan, viewport: vs) { center in
                    follow = false
                    pan = clamped(CGSize(width: vs.width / 2 - center.x * scale, height: vs.height / 2 - center.y * scale))
                }
                .padding(12)
            }
            .onAppear {
                viewport = vs
                world = layout.size
                wheel.onWheel = { e in handleWheel(e) }
                wheel.start()
                if !placed { placed = true; focusLast(layout, vs, animated: false, rescale: true) }
            }
            .onDisappear { wheel.stop() }
            .onChange(of: vs) { new in
                // Oyna o'lchami o'zgarsa: zoom va vertikal joylashuv yangi o'lchamga moslashadi
                let old = viewport
                viewport = new
                if follow { focusLast(layout, new, animated: false, rescale: true); return }
                let dy = (new.height - old.height) / 2
                pan = clamped(CGSize(width: pan.width, height: pan.height + dy))
            }
            .onChange(of: layout.size) { world = $0 }
            .onChange(of: layout.lastTurn?.id) { _ in
                if follow { focusLast(layout, vs, animated: true) }
            }
            .onChange(of: steps.count) { _ in
                if follow { focusLast(layout, vs, animated: true) }
            }
        }
        .background(Brand.canvas)
    }

    /// Hech narsa tanlanmagan bo'lsa — eng so'nggi so'rov ochiladi
    private var lastTurnId: String? {
        guard let s = chain.last, let t = s.turns.last else { return nil }
        return "\(s.id)#\(t.id)"
    }

    // MARK: Tugunlar

    @ViewBuilder
    private func node(_ n: MapNode) -> some View {
        switch n.kind {
        case .start(let d):
            MapPill(symbol: "flag.fill", title: "Boshlandi", subtitle: Fmt.hourMinute.string(from: d), color: Brand.accent)
        case .divider(let title, let subtitle):
            MapPill(symbol: "arrow.triangle.2.circlepath", title: title, subtitle: subtitle, color: Brand.warn)
        case .turn(let t, let sid, let prev):
            TurnCard(turn: t, previousPrompt: prev, mode: mode, selected: selectedTurn == n.id,
                     expandedSteps: (selectedTurn ?? lastTurnId) == n.id && !steps.isEmpty ? steps.count : nil)
                .onTapGesture { onSelectTurn(sid, t.id) }
        case .tool(let tool, let sid):
            MapToolNode(tool: tool)
                .onTapGesture {
                    if let turnId = Int(n.id.split(separator: "#").last?.split(separator: "/").first ?? "") {
                        onSelectTool(sid, turnId, tool.category)
                    }
                }
        case .step(let st, let sid, let tid):
            MapStepNode(item: st)
                .onTapGesture {
                    switch st.item {
                    case .step(let s): onSelectTool(sid, tid, s.category)
                    case .group(let g): if let c = g.first?.category { onSelectTool(sid, tid, c) }
                    case .note(let n, _): onSelectNote(sid, n)
                    case .live: break
                    }
                }
        case .earlier(let k):
            Text("+\(k) oldingi qadam")
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .surfaceCapsule()
                .help("Eski qadamlar — o'ng paneldagi «Jarayon»da to'liq ro'yxat")
        case .more(let k):
            VStack(spacing: 6) {
                Text("+\(k)").font(.callout.weight(.semibold)).foregroundStyle(.secondary)
                    .frame(width: M.toolD, height: M.toolD).surfaceCircle()
                Text("yana").font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        case .end(let active, let at):
            MapEndNode(active: active, at: at, waiting: waiting)
        }
    }

    // MARK: Boshqaruv

    private func controls(_ layout: MapLayout, _ vs: CGSize) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                iconButton("minus", "Kichraytirish") { zoom(to: scale / 1.25, around: center(vs)) }
                Text("\(Int((scale * 100).rounded()))%")
                    .font(.caption.weight(.semibold)).monospacedDigit().frame(width: 44)
                iconButton("plus", "Kattalashtirish") { zoom(to: scale * 1.25, around: center(vs)) }
                Divider().frame(height: 16)
                iconButton("arrow.up.left.and.arrow.down.right", "Hammasini ko'rsatish") { fit(layout, vs) }
            }
            .surface(radius: 10, interactive: true)

            Button {
                follow = true
                focusLast(layout, vs, animated: true)
            } label: {
                HStack(spacing: 6) {
                    Circle().fill(follow ? Brand.ok : Color.secondary.opacity(0.5)).frame(width: 7, height: 7)
                    Text(follow ? "Ergashyapti" : "Hozirgiga qaytish")
                }
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10).frame(height: 28)
                .surface(radius: 10, interactive: true)
            }
            .buttonStyle(.plain)
            .help("Oxirgi so'rovga o'tish va yangi so'rovlarga ergashish")
        }
    }

    private func iconButton(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button {
            follow = false
            withAnimation(Motion.snappy) { action() }
        } label: {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 28)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: Hisob

    private func screen(_ p: CGPoint) -> CGPoint {
        CGPoint(x: p.x * scale + pan.width, y: p.y * scale + pan.height)
    }

    private func center(_ vs: CGSize) -> CGPoint { CGPoint(x: vs.width / 2, y: vs.height / 2) }

    /// Zoom: `anchor` ostidagi nuqta joyida qoladi
    private func zoom(to s: CGFloat, around anchor: CGPoint) {
        let ns = min(2, max(0.2, s))
        let wx = (anchor.x - pan.width) / scale, wy = (anchor.y - pan.height) / scale
        scale = ns
        pan = clamped(CGSize(width: anchor.x - wx * ns, height: anchor.y - wy * ns))
    }

    private func fit(_ layout: MapLayout, _ vs: CGSize) {
        let s = min(1, max(0.2, min(vs.width / layout.size.width, vs.height / layout.size.height)))
        scale = s
        pan = CGSize(width: (vs.width - layout.size.width * s) / 2, height: (vs.height - layout.size.height * s) / 2)
    }

    /// Oxirgi kartani o'ng tomonda, vertikal — markazda ko'rsatadi. Balandlik katta bo'lsa — biroz kattaroq masshtab
    private func focusLast(_ layout: MapLayout, _ vs: CGSize, animated: Bool, rescale: Bool = false) {
        guard vs.width > 0 else { return }
        if rescale {
            scale = min(1.15, max(0.6, (vs.height - 80) / M.baseH * 0.9))
        }
        let end = layout.nodes.last?.rect.maxX ?? layout.size.width
        // Bo'yiga sig'sa — markazda; sig'masa — eng so'nggi qadam ko'rinadigan qilib pastga suriladi
        let ch = layout.size.height * scale
        let y = ch <= vs.height ? (vs.height - ch) / 2
            : vs.height - ((layout.stepsBottom ?? layout.size.height) + 40) * scale
        let target = clamped(CGSize(width: min(M.pad * scale, vs.width - (end + M.pad) * scale), height: y),
                             vs: vs, world: layout.size)
        if animated && !reduceMotion { withAnimation(Motion.spring) { pan = target } } else { pan = target }
    }

    /// Xarita ekrandan butunlay chiqib ketmasin: kamida 160 pt ko'rinib turadi; sig'sa — vertikal ichkarida qoladi
    private func clamped(_ p: CGSize, vs: CGSize? = nil, world: CGSize? = nil) -> CGSize {
        let v = vs ?? viewport, w = world ?? self.world
        guard v.width > 0, w.width > 0 else { return p }
        let cw = w.width * scale, ch = w.height * scale
        let keep = min(160, cw / 2)
        let x = min(v.width - keep, max(keep - cw, p.width))
        let y: CGFloat = ch <= v.height
            ? min(v.height - ch, max(0, p.height))
            : min(0, max(v.height - ch, p.height))
        return CGSize(width: x, height: y)
    }

    private func handleWheel(_ e: NSEvent) {
        var dx = e.scrollingDeltaX, dy = e.scrollingDeltaY
        if !e.hasPreciseScrollingDeltas { dx *= 10; dy *= 10 }
        follow = false
        if e.modifierFlags.contains(.command) || e.modifierFlags.contains(.option) {
            zoom(to: scale * (1 + dy * 0.01), around: cursor ?? center(viewport))
        } else {
            pan = clamped(CGSize(width: pan.width + dx, height: pan.height + dy))
        }
    }
}

// MARK: - Fon va chiziqlar

/// Nuqtali fon: xarita bilan birga siljiydi va kattalashadi
private struct MapGrid: View {
    let scale: CGFloat
    let pan: CGSize

    var body: some View {
        Canvas { g, size in
            var step = 24 * scale
            while step < 12 { step *= 2 }
            let c = Color.primary.opacity(0.13)
            let ox = pan.width.truncatingRemainder(dividingBy: step), oy = pan.height.truncatingRemainder(dividingBy: step)
            var y = oy - step
            while y < size.height {
                var x = ox - step
                while x < size.width {
                    g.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(c))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MapEdges: View {
    let edges: [MapEdge]
    let scale: CGFloat
    let pan: CGSize
    let reduceMotion: Bool

    var body: some View {
        let animated = edges.contains(where: \.live) && !reduceMotion
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: !animated)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            Canvas { g, size in
                let bounds = CGRect(origin: .zero, size: size).insetBy(dx: -40, dy: -40)
                for (i, e) in edges.enumerated() {
                    let a = sp(e.from), b = sp(e.to)
                    guard bounds.intersects(CGRect(x: min(a.x, b.x), y: min(a.y, b.y),
                                                   width: abs(b.x - a.x) + 1, height: abs(b.y - a.y) + 1)) else { continue }
                    let path = e.vertical ? vCurve(a, b) : hCurve(a, b)
                    let w = max(1.2, 2 * scale)
                    if e.live && animated {
                        DataFlow.draw(&g, path: path, color: e.color, t: t, seed: Double(i) * 0.37, width: w)
                    } else if e.vertical {
                        g.stroke(path, with: .color(Color.primary.opacity(0.28)),
                                 style: StrokeStyle(lineWidth: w * 0.8, lineCap: .round, dash: [6 * scale, 5 * scale]))
                    } else {
                        g.stroke(path, with: .color(Color.primary.opacity(0.32)), lineWidth: w)
                    }
                    let r = max(2.5, 4 * scale)
                    for p in [a, b] {
                        g.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                               with: .color(Color(nsColor: .tertiaryLabelColor)))
                    }
                }
            }
        }
    }

    private func sp(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x * scale + pan.width, y: p.y * scale + pan.height) }

    private func hCurve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        let dx = max(20, abs(b.x - a.x) * 0.5)
        p.move(to: a)
        p.addCurve(to: b, control1: CGPoint(x: a.x + dx, y: a.y), control2: CGPoint(x: b.x - dx, y: b.y))
        return p
    }

    private func vCurve(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path()
        let dy = max(16, (b.y - a.y) * 0.55)
        p.move(to: a)
        p.addCurve(to: b, control1: CGPoint(x: a.x, y: a.y + dy), control2: CGPoint(x: b.x, y: b.y - dy))
        return p
    }
}

// MARK: - Tugun ko'rinishlari

private struct TurnCard: View {
    let turn: TurnSnap
    let previousPrompt: String?
    let mode: CountMode
    let selected: Bool
    /// Ostida qadamlar zanjiri ochilgan bo'lsa — qadamlar soni
    var expandedSteps: Int? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("#\(turn.id)")
                    .font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(Brand.accent)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Brand.accentSoft))
                Text(Fmt.hourMinute.string(from: turn.start)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                status
            }
            VStack(alignment: .leading, spacing: 2) {
                if turn.isContinuation {
                    Label("Ish davom etdi", systemImage: "arrow.triangle.2.circlepath")
                        .font(.callout.weight(.semibold)).foregroundStyle(Brand.warn)
                    if let previousPrompt {
                        Text(previousPrompt).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                } else {
                    Text(turn.prompt).font(.callout.weight(.medium)).lineLimit(3)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            HStack(spacing: 10) {
                meta("clock", Alerts.duration(turn.duration))
                meta("circle.hexagongrid", Fmt.tokens(turn.tokens.value(mode)))
                meta("list.bullet", "\(turn.steps)")
                if !turn.helpers.isEmpty { meta("person.2", "\(turn.helpers.count)") }
            }
        }
        .padding(14)
        .frame(width: M.cardW, height: M.cardH, alignment: .topLeading)
        .modifier(Surface(shape: shape, tint: turn.active ? Brand.ok : nil, interactive: true,
                          stroke: selected ? Brand.accent : nil))
        .overlay { if turn.active { LiveBorder(shape: shape, color: Brand.ok, lineWidth: 2) } }
        .overlay(alignment: .bottom) {
            if let n = expandedSteps {
                portPill("Jarayon · \(n) qadam", Brand.accent).offset(y: 11)
            } else if !turn.tools.isEmpty {
                portPill("Asboblar", .secondary).offset(y: 11)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        .contentShape(shape)
        .help(turn.isContinuation ? "Kontekst tugab, suhbat xulosa bilan davom ettirildi" : turn.prompt)
    }

    @ViewBuilder
    private var status: some View {
        if turn.active {
            HStack(spacing: 4) { ProgressView().controlSize(.mini); Text("ishlayapti") }
                .font(.caption.weight(.semibold)).foregroundStyle(Brand.ok)
        } else if turn.errors > 0 {
            Label("\(turn.errors) xato", systemImage: "exclamationmark.triangle.fill")
                .font(.caption.weight(.semibold)).foregroundStyle(Brand.err)
        } else {
            Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(.tertiary)
        }
    }

    private func meta(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) { Image(systemName: symbol); Text(text) }
            .font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
    }
}

private struct MapPill: View {
    let symbol: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(color)
                .frame(width: 26, height: 26).background(Circle().fill(color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption.weight(.semibold)).lineLimit(1)
                if !subtitle.isEmpty { Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(width: M.pillW, height: M.pillH)
        .surfaceCapsule()
    }
}

private struct MapToolNode: View {
    let tool: TurnTool

    var body: some View {
        let color = tool.category.color
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: tool.category.symbol)
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(tool.category.iconColor)
                    .frame(width: M.toolD, height: M.toolD)
                    .surfaceCircle(tint: tool.busy ? color : nil, interactive: true)
                    .overlay { if tool.busy { LiveBorder(shape: Circle(), color: color, lineWidth: 2, period: 2.4) } }
                Text(tool.errors > 0 ? "\(tool.calls)·\(tool.errors)!" : "\(tool.calls)")
                    .font(.system(size: 9, weight: .bold)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(tool.errors > 0 ? Brand.err : color))
                    .foregroundStyle(.white)
                    .offset(x: 8, y: -3)
            }
            Text(tool.category.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .contentShape(Rectangle())
        .help("\(tool.category.title): \(tool.calls) chaqiruv\(tool.top.isEmpty ? "" : " · ko'pi: \(tool.top)")")
    }
}

private struct MapEndNode: View {
    let active: Bool
    let at: Date?
    var waiting: HookNotice? = nil

    var body: some View {
        if let waiting {
            waitingBody(waiting)
        } else {
            normal
        }
    }

    /// Ruxsat kutilyapti: to'q sariq qo'l, aylanuvchi chegara va qaysi asbob uchunligi
    private func waitingBody(_ n: HookNotice) -> some View {
        Image(systemName: "hand.raised.fill").font(.system(size: 22, weight: .semibold)).foregroundStyle(Brand.warn)
            .frame(width: M.endD, height: M.endD)
            .surfaceCircle(tint: Brand.warn)
            .overlay { LiveBorder(shape: Circle(), color: Brand.warn, lineWidth: 2, period: 1.8) }
            .overlay(alignment: .bottom) {
                VStack(spacing: 1) {
                    Text("Ruxsatingizni kutyapti").font(.caption.weight(.semibold)).foregroundStyle(Brand.warn)
                    Text(Alerts.uz(n.message)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .fixedSize().offset(y: 34)
            }
            .help(n.message)
    }

    private var normal: some View {
        ZStack {
            if active {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark").font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: M.endD, height: M.endD)
        .surfaceCircle(tint: active ? Brand.ok : nil)
        .overlay { if active { LiveBorder(shape: Circle(), color: Brand.ok, lineWidth: 2) } }
        .overlay(alignment: .bottom) {
            Text(active ? "Ishlayapti" : at.map { "Tugadi · " + Fmt.hourMinute.string(from: $0) } ?? "Tugadi")
                .font(.caption2.weight(.medium)).foregroundStyle(active ? Brand.ok : .secondary)
                .fixedSize().offset(y: 20)
        }
    }
}

// MARK: - Mini-xarita

private struct MiniMap: View {
    let layout: MapLayout
    let scale: CGFloat
    let pan: CGSize
    let viewport: CGSize
    let jump: (CGPoint) -> Void

    var body: some View {
        // Sxematik: gorizontal masshtab — butun sessiya, vertikal — qatorlar (so'rovlar tepada, asboblar pastda)
        let w: CGFloat = 220, h: CGFloat = 44
        let k = w / max(layout.size.width, 1)
        let rowY: CGFloat = 12, toolY: CGFloat = 32
        Canvas { g, _ in
            for n in layout.nodes {
                let x = n.rect.minX * k, bw = max(2, n.rect.width * k)
                switch n.kind {
                case .turn(let t, _, _):
                    g.fill(Path(roundedRect: CGRect(x: x, y: rowY - 7, width: bw, height: 14), cornerRadius: 2),
                           with: .color(t.active ? Brand.ok : Brand.accent.opacity(0.6)))
                case .divider:
                    g.fill(Path(roundedRect: CGRect(x: x, y: rowY - 4, width: bw, height: 8), cornerRadius: 2),
                           with: .color(Brand.warn.opacity(0.8)))
                case .tool(let t, _):
                    g.fill(Path(ellipseIn: CGRect(x: n.center.x * k - 2, y: toolY - 2, width: 4, height: 4)),
                           with: .color(t.category.color))
                case .more:
                    break
                case .step(let st, _, _):
                    g.fill(Path(ellipseIn: CGRect(x: n.center.x * k - 1.5, y: toolY + 5, width: 3, height: 3)),
                           with: .color(st.color))
                case .earlier:
                    break
                default:
                    g.fill(Path(ellipseIn: CGRect(x: n.center.x * k - 3, y: rowY - 3, width: 6, height: 6)),
                           with: .color(Color.secondary))
                }
            }
            let vx = max(0, (-pan.width / scale) * k)
            let vw = min(w - vx, viewport.width / scale * k)
            if vw > 0 {
                let v = CGRect(x: vx, y: 1, width: max(6, vw), height: h - 2)
                g.fill(Path(roundedRect: v, cornerRadius: 4), with: .color(Brand.accent.opacity(0.14)))
                g.stroke(Path(roundedRect: v, cornerRadius: 4), with: .color(Brand.accent), lineWidth: 1.2)
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            jump(CGPoint(x: v.location.x / k, y: layout.size.height / 2))
        })
        .padding(8)
        .surface(radius: 12)
        .help("Mini-xarita: bosing yoki suring")
    }
}

/// Zanjir bo'g'ini: asbob qadami (belgi, nima qilindi, vaqti), o'ylash (💭 matni yoki davomiyligi),
/// javob (💬 matn boshi) yoki «O'ylayapti…». Bajarilayotgani — jonli chegara bilan
private struct MapStepNode: View {
    let item: MapStep

    var body: some View {
        if item.isPill { pill } else { card }
    }

    /// Yupqa yorliq: belgi, qisqa matn va vaqt — chiziq ustida, markazda
    private var pill: some View {
        let color = item.color
        return HStack(spacing: 6) {
            switch item.item {
            case .step(let s):
                Image(systemName: s.status == .failed ? "xmark.circle.fill" : s.symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(s.status == .failed ? Brand.err : s.category.iconColor)
                Text(Self.shortText(s.text)).font(.caption).lineLimit(1)
                    .foregroundStyle(s.status == .failed ? Brand.err : .primary)
                if let d = s.duration, d >= 1 { Text(Self.dur(d)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize() }
            case .group(let g):
                let byCat = Dictionary(grouping: g, by: \.category).sorted { $0.value.count > $1.value.count }
                ForEach(byCat.prefix(4), id: \.key) { cat, list in
                    HStack(spacing: 2) {
                        Image(systemName: cat.symbol).font(.system(size: 9, weight: .semibold))
                        Text("\(list.count)").font(.caption2.weight(.semibold)).monospacedDigit()
                    }
                    .foregroundStyle(cat.iconColor)
                }
                Text("\(g.count) qadam").font(.caption).foregroundStyle(.secondary)
                let errs = g.filter { $0.status == .failed }.count
                if errs > 0 { Text("\(errs) xato").font(.caption2.weight(.semibold)).foregroundStyle(Brand.err) }
                let total = g.compactMap(\.duration).reduce(0, +)
                if total >= 1 { Text("· " + Self.dur(total)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize() }
            case .note(let n, _):
                Image(systemName: "brain").font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text(Self.oneLine(n.text)).font(.caption).italic().lineLimit(1).foregroundStyle(.secondary)
            case .live(let since):
                Image(systemName: "brain").font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                Text("O'ylayapti…").font(.caption.weight(.medium))
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(Self.dur(ctx.date.timeIntervalSince(since))).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 11)
        .frame(height: 28)
        .frame(maxWidth: M.cardW - 20)
        .fixedSize(horizontal: true, vertical: false)
        .modifier(Surface(shape: Capsule(), tint: item.isLive ? color : nil, interactive: true))
        .overlay { if item.isLive { LiveBorder(shape: Capsule(), color: color, lineWidth: 1.5, period: 2.4) } }
        .frame(width: M.cardW, height: item.height)
        .contentShape(Rectangle())
        .help(help)
    }

    private var card: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let color = item.color
        let final: Bool = { if case .note(_, let f) = item.item { return f }; return false }()
        return HStack(alignment: isText ? .top : .center, spacing: 10) {
            icon.frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                content
                meta.font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if item.isLive { ProgressView().controlSize(.mini) }
        }
        .padding(.horizontal, 10).padding(.vertical, isText ? 10 : 0)
        .frame(width: M.cardW, height: item.height, alignment: isText ? .topLeading : .leading)
        .modifier(Surface(shape: shape, tint: isReply ? color : nil, interactive: true,
                          stroke: final ? color.opacity(0.7) : nil))
        .contentShape(shape)
        .help(help)
    }

    private var isText: Bool {
        if case .note(let n, _) = item.item { return !n.text.isEmpty }
        return false
    }

    private var isReply: Bool {
        if case .note(let n, _) = item.item { return n.kind == .reply }
        return false
    }

    @ViewBuilder
    private var icon: some View {
        switch item.item {
        case .step(let s):
            ZStack {
                Circle().fill(s.category.color.opacity(s.status == .failed ? 0 : 0.15))
                if s.status == .failed {
                    Circle().fill(Brand.err)
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                } else {
                    Image(systemName: s.symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(s.category.iconColor)
                }
            }
        case .group(let g):
            ZStack(alignment: .topTrailing) {
                Circle().fill(item.color.opacity(0.15))
                    .overlay {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(MapStep.dominant(g)?.iconColor ?? .secondary)
                    }
                if g.contains(where: { $0.status == .failed }) {
                    Circle().fill(Brand.err).frame(width: 8, height: 8).offset(x: 1, y: -1)
                }
            }
        case .note(let n, _):
            ZStack {
                Circle().fill(item.color.opacity(0.16))
                Image(systemName: n.kind == .reply ? "text.bubble.fill" : "brain")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(item.color)
            }
        case .live:
            ZStack {
                Circle().fill(item.color.opacity(0.16))
                Image(systemName: "brain").font(.system(size: 12, weight: .semibold)).foregroundStyle(item.color)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch item.item {
        case .step(let s):
            Text(s.text).font(.callout).lineLimit(1).truncationMode(.tail)
                .foregroundStyle(s.status == .failed ? Brand.err : Color.primary)
        case .group(let g):
            // «6 ta qadam  ▣3 ⌘2 ◎1» — turlar bo'yicha sanoq
            HStack(spacing: 6) {
                Text("\(g.count) ta qadam").font(.callout.weight(.medium))
                let byCat = Dictionary(grouping: g, by: \.category).sorted { $0.value.count > $1.value.count }
                ForEach(byCat.prefix(4), id: \.key) { cat, list in
                    HStack(spacing: 2) {
                        Image(systemName: cat.symbol).font(.system(size: 9, weight: .semibold))
                        Text("\(list.count)").font(.caption2.weight(.semibold)).monospacedDigit()
                    }
                    .foregroundStyle(cat.iconColor)
                    .help(cat.title)
                }
                let errs = g.filter { $0.status == .failed }.count
                if errs > 0 { Text("\(errs) xato").font(.caption2.weight(.semibold)).foregroundStyle(Brand.err) }
            }
            .lineLimit(1)
        case .note(let n, let final):
            if n.text.isEmpty {
                Text("O'yladi").font(.callout.weight(.medium))
            } else {
                Text(n.kind == .reply ? (final ? "Javob" : "Xabar") : "O'yladi")
                    .font(.caption.weight(.semibold)).foregroundStyle(item.color)
                Text(Self.oneLine(n.text)).font(.callout).lineLimit(final ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .live:
            Text("O'ylayapti…").font(.callout.weight(.medium))
        }
    }

    @ViewBuilder
    private var meta: some View {
        HStack(spacing: 5) {
            switch item.item {
            case .step(let s):
                Text(Fmt.clock.string(from: s.date))
                if let d = s.duration { Text("· " + Self.dur(d)) }
            case .group(let g):
                // Oxirgi qadam nima edi va jami qancha vaqt ketdi
                Text(g.last?.text ?? "").lineLimit(1).truncationMode(.tail)
                let total = g.compactMap(\.duration).reduce(0, +)
                if total >= 1 { Text("· " + Self.dur(total)).fixedSize() }
            case .note(let n, _):
                Text(Fmt.clock.string(from: n.date))
                if let d = n.duration, d >= 1 { Text("· ~" + Self.dur(d)) }
                if n.kind == .thinking && n.text.isEmpty { Text("· matn yashirin") }
            case .live(let since):
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(Self.dur(ctx.date.timeIntervalSince(since)))
                }
            }
            if let a = item.agent { Text("· " + a).lineLimit(1) }
        }
    }

    private var help: String {
        switch item.item {
        case .step(let s): return s.text
        case .group(let g): return g.map(\.text).joined(separator: "\n")
        case .note(let n, _): return n.text.isEmpty ? "O'ylash matni shifrlangan" : "Bosing — to'liq matn o'ng panelda"
        case .live: return "Model hozir o'ylayapti yoki javob yozyapti"
        }
    }

    /// «Terminal · Read event dispatch» → «Read event dispatch» (tur nomi sarlavhada bor)
    static func shortText(_ s: String) -> String {
        guard let r = s.range(of: " · ") else { return s }
        return String(s[r.upperBound...])
    }

    /// Markdown belgilari va qator uzilishlarisiz qisqa ko'rinish
    static func oneLine(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func dur(_ s: TimeInterval) -> String {
        if s < 1 { return "<1 s" }
        if s < 60 { return "\(Int(s)) s" }
        return "\(Int(s) / 60) daq \(Int(s) % 60) s"
    }
}
