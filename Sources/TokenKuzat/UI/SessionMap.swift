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
    static let endD: CGFloat = 64
    static let gap: CGFloat = 64
    static let rowGap: CGFloat = 64
    static let toolDrop: CGFloat = 112
    static let toolD: CGFloat = 46
    static let toolStep: CGFloat = 68
    static let maxTools = 4
    static let pad: CGFloat = 48
    static let stepH: CGFloat = 52
    static let stepGap: CGFloat = 10
    static let stepTop: CGFloat = 46
    static let maxSteps = 12
    static let chipH: CGFloat = 28
    static let headH: CGFloat = 34
    static let barH: CGFloat = 56
    static let framePad: CGFloat = 18
    static let sectionGap: CGFloat = 40
    /// Shundan uzun tanaffus — yangi bo'lim
    static let sectionBreak: TimeInterval = 600
    /// Shu masshtabdan past — uzoqdan ko'rinish (faqat raqam va qisqa nom, katta harfda)
    static let lod: CGFloat = 0.5
    /// Satr kengligi shu masshtabda oynaga to'liq sig'adi
    static let fitScale: CGFloat = 0.85
}

/// Xaritadagi bitta katta karta: so'rov va unga ilingan qisqa javob-so'rovlar («ha», «boshla», «Bosdim»…)
private struct MapCard {
    let turn: TurnSnap
    let sessionId: String
    let previousPrompt: String?
    var followUps: [TurnSnap] = []
    var id: String { "\(sessionId)#\(turn.id)" }
    func contains(_ key: String?) -> Bool {
        key == id || followUps.contains { "\(sessionId)#\($0.id)" == key }
    }
}

/// Bo'lim: tanaffus, kontekst yangilanishi yoki yangi sessiya bilan ajralgan so'rovlar to'plami
private struct MapSection: Identifiable {
    let id: String
    let topic: String
    /// «Kontekst yangilandi» / «Yangi sessiya»; oddiy tanaffusda nil
    let reason: String?
    let start: Date
    var end: Date
    var cards: [MapCard] = []
    var turnCount = 0
    var tokens: Double = 0
    var steps = 0
    var errors = 0
    var active = false

    func contains(_ key: String?) -> Bool { cards.contains { $0.contains(key) } }

    /// «ha», «ha boshla», «Bosdim», «Sinab ko'rdim» — oldingi ishning davomi, alohida mavzu emas
    static func isFollowUp(_ prompt: String) -> Bool {
        let s = prompt.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, s.count <= 30, !s.contains("\n") else { return false }
        let first = s.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "." || $0 == "!" }).first.map(String.init) ?? ""
        let words: Set<String> = ["ha", "xa", "ok", "okay", "mayli", "maqul", "ma'qul", "ma‘qul", "bo'ldi", "boshla",
                                  "davom", "bosdim", "kirdim", "sinab", "zo'r", "zor", "yes", "qil", "qilaver",
                                  "tushundim", "rahmat", "ajoyib", "yaxshi"]
        return words.contains(first)
    }

    static func build(_ chain: [SessionSnap], mode: CountMode) -> [MapSection] {
        var out: [MapSection] = []
        var lastReal: String?
        var prevEnd: Date?
        for (si, s) in chain.enumerated() {
            for t in s.turns {
                let newSession = si > 0 && t.id == s.turns.first?.id
                let reason: String? = t.isContinuation ? "Kontekst yangilandi" : (newSession ? "Yangi sessiya" : nil)
                let gap = prevEnd.map { t.start.timeIntervalSince($0) > M.sectionBreak } ?? true
                let follow = reason == nil && !gap && !t.isContinuation && isFollowUp(t.prompt)
                    && !(out.last?.cards.isEmpty ?? true)
                if follow {
                    out[out.count - 1].cards[out[out.count - 1].cards.count - 1].followUps.append(t)
                } else {
                    if out.isEmpty || reason != nil || gap {
                        let topic = t.isContinuation ? (lastReal.map { "Davomi: " + $0 } ?? "Ish davom etdi") : t.prompt
                        out.append(MapSection(id: "\(s.id)#\(t.id)", topic: topic, reason: reason, start: t.start, end: t.end))
                    }
                    out[out.count - 1].cards.append(MapCard(turn: t, sessionId: s.id,
                                                            previousPrompt: t.isContinuation ? lastReal : nil))
                    if !t.isContinuation { lastReal = t.prompt }
                }
                var sec = out[out.count - 1]
                sec.turnCount += 1
                sec.tokens += t.tokens.value(mode)
                sec.steps += t.steps
                sec.errors += t.errors
                sec.active = sec.active || t.active
                sec.end = max(sec.end, t.end)
                out[out.count - 1] = sec
                prevEnd = t.end
            }
        }
        return out
    }
}

private struct MapNode: Identifiable {
    enum Kind {
        case header(MapSection, open: Bool)
        case turn(TurnSnap, sessionId: String, previousPrompt: String?, expanded: Int?, followUps: Int)
        case followUp(TurnSnap, sessionId: String)
        case tool(TurnTool, sessionId: String, turnId: Int)
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
    /// Uzoqdan ham ko'rinadi (bo'lim, so'rov kartasi, yakun)
    var isMainRow: Bool {
        switch kind {
        case .header, .turn, .end: return true
        default: return false
        }
    }
}

private struct MapEdge: Identifiable {
    enum Route {
        /// Bir satrda: chapdan o'ngga
        case h
        /// Karta ostiga: asboblar, javob-so'rovlar, qadamlar
        case v
        /// Satr tugadi: o'ngga chiqib, satrlar oralig'ida (`midY`) chapga qaytadi va keyingi kartaga kiradi
        case wrap(midY: CGFloat)
    }
    let id: String
    let from: CGPoint
    let to: CGPoint
    let route: Route
    let live: Bool
    let color: Color

    var isBranch: Bool { if case .v = route { return true }; return false }
}

/// Ochiq bo'limning ramkasi
private struct MapFrame: Identifiable {
    let id: String
    let rect: CGRect
    let active: Bool
}

private struct MapLayout {
    var nodes: [MapNode] = []
    var edges: [MapEdge] = []
    var frames: [MapFrame] = []
    var size = CGSize.zero
    /// Oxirgi so'rov kartasi — «Hozirgiga» va ergashish uchun
    var lastTurn: MapNode?
    /// Qadamlar zanjiri pastga qarab qayergacha boradi (ergashish uchun)
    var stepsBottom: CGFloat?

    /// - Parameters:
    ///   - expanded: qadamlar zanjiri ochiladigan so'rov («sessiya#raqam»)
    ///   - rowWidth: satr kengligi; kartalar shunga sig'guncha teriladi, keyin keyingi satrga o'tadi
    init(sections: [MapSection], expanded: String?, steps: [MapStep], rowWidth: CGFloat,
         isOpen: (MapSection) -> Bool, active: Bool, lastAt: Date?) {
        let left = M.pad, right = M.pad + rowWidth
        var y = M.pad
        var flow: MapNode?          // oqim chizig'ining oxirgi nuqtasi
        var flowMid: CGFloat?       // keyingi ulanish satrlar oralig'idan o'tadigan bo'lsa — o'sha y

        func connect(_ n: MapNode, live: Bool) {
            guard let p = flow else { return }
            let a = CGPoint(x: p.rect.maxX, y: p.center.y), b = CGPoint(x: n.rect.minX, y: n.center.y)
            if abs(a.y - b.y) < 1 && b.x > a.x {
                edges.append(MapEdge(id: p.id + ">" + n.id, from: a, to: b, route: .h, live: live, color: Brand.ok))
            } else {
                edges.append(MapEdge(id: p.id + ">" + n.id, from: a, to: b,
                                     route: .wrap(midY: flowMid ?? (n.rect.minY - M.rowGap / 2)), live: live, color: Brand.ok))
            }
        }

        for (si, sec) in sections.enumerated() {
            let open = isOpen(sec)
            let isLast = si == sections.count - 1
            let frameTop = y
            let h = open ? M.headH : M.barH
            let head = MapNode(id: "h" + sec.id, kind: .header(sec, open: open),
                               center: CGPoint(x: left + rowWidth / 2, y: y + h / 2), size: CGSize(width: rowWidth, height: h))
            nodes.append(head)
            if !open {
                // Yig'ilgan bo'lim — bitta chiziq: oqim unga kirib, undan chiqadi
                connect(head, live: false)
                flow = head
                flowMid = nil
                y = head.rect.maxY + M.sectionGap
                if isLast {
                    flowMid = y - M.sectionGap / 2
                    let e = MapNode(id: "end", kind: .end(active: active, at: lastAt),
                                    center: CGPoint(x: left + M.endD / 2, y: y + M.endD / 2), size: CGSize(width: M.endD, height: M.endD))
                    nodes.append(e)
                    connect(e, live: active)
                    y = e.rect.maxY + 40
                }
                continue
            }
            if flow != nil { flowMid = frameTop - M.sectionGap / 2 }
            var x = left
            var rowTop = head.rect.maxY + 16
            var rowBottom = rowTop + M.cardH
            for card in sec.cards {
                if x > left && x + M.cardW > right {
                    rowTop = rowBottom + M.rowGap
                    rowBottom = rowTop + M.cardH
                    x = left
                    flowMid = rowTop - M.rowGap / 2
                }
                let n = MapNode(id: card.id, kind: .turn(card.turn, sessionId: card.sessionId, previousPrompt: card.previousPrompt,
                                                         expanded: card.contains(expanded) && !steps.isEmpty ? steps.count : nil,
                                                         followUps: card.followUps.count),
                                center: CGPoint(x: x + M.cardW / 2, y: rowTop + M.cardH / 2), size: CGSize(width: M.cardW, height: M.cardH))
                nodes.append(n)
                connect(n, live: card.turn.active)
                flow = n
                flowMid = nil
                lastTurn = n

                // Karta ostidagi ustun: ilingan javob-so'rovlar, keyin qadamlar zanjiri yoki asboblar
                var port = CGPoint(x: n.center.x, y: n.rect.maxY)
                var colY = n.rect.maxY
                for f in card.followUps {
                    let c = MapNode(id: "\(card.sessionId)#\(f.id)", kind: .followUp(f, sessionId: card.sessionId),
                                    center: CGPoint(x: n.center.x, y: colY + 14 + M.chipH / 2),
                                    size: CGSize(width: M.cardW - 24, height: M.chipH))
                    nodes.append(c)
                    edges.append(MapEdge(id: "f" + c.id, from: port, to: CGPoint(x: c.center.x, y: c.rect.minY),
                                         route: .v, live: f.active, color: Brand.ok))
                    port = CGPoint(x: c.center.x, y: c.rect.maxY)
                    colY = c.rect.maxY
                }
                if card.contains(expanded) && !steps.isEmpty {
                    let tid = Int(expanded?.split(separator: "#").last ?? "") ?? card.turn.id
                    colY = placeSteps(steps, port: port, top: colY + (card.followUps.isEmpty ? M.stepTop : 22),
                                      idPrefix: card.id, sessionId: card.sessionId, turnId: tid)
                    stepsBottom = colY
                } else {
                    colY = placeTools(card.turn.tools, port: port,
                                      centerY: colY + (card.followUps.isEmpty ? M.toolDrop : 70),
                                      idPrefix: card.id, sessionId: card.sessionId, turnId: card.turn.id) ?? colY
                }
                rowBottom = max(rowBottom, colY)
                x += M.cardW + M.gap
            }
            if isLast {
                // Yakun tuguni — oxirgi karta yonida (sig'sa) yoki keyingi satr boshida
                if x + M.endD > right + M.gap {
                    rowTop = rowBottom + M.rowGap
                    rowBottom = rowTop + M.cardH
                    x = left
                    flowMid = rowTop - M.rowGap / 2
                }
                let e = MapNode(id: "end", kind: .end(active: active, at: lastAt),
                                center: CGPoint(x: x + M.endD / 2, y: rowTop + M.cardH / 2), size: CGSize(width: M.endD, height: M.endD))
                nodes.append(e)
                connect(e, live: active)
            }
            frames.append(MapFrame(id: sec.id,
                                   rect: CGRect(x: left - M.framePad, y: frameTop - 8,
                                                width: rowWidth + 2 * M.framePad, height: rowBottom + M.framePad - frameTop + 8),
                                   active: sec.active))
            y = rowBottom + M.framePad + M.sectionGap
        }
        size = CGSize(width: right + M.pad, height: y + M.pad)
    }

    /// Qadamlar ustun bo'ylab pastga, vaqt bo'yicha; ko'p bo'lsa — oxirgilari, tepada «+N oldingi». Pastki chegarani qaytaradi
    private mutating func placeSteps(_ all: [MapStep], port: CGPoint, top: CGFloat, idPrefix: String,
                                     sessionId: String, turnId: Int) -> CGFloat {
        let shown = Array(all.suffix(M.maxSteps))
        let hidden = all.count - shown.count
        var y = top
        var prevBottom = port
        func link(_ n: MapNode, live: Bool, color: Color) {
            edges.append(MapEdge(id: "e" + n.id, from: prevBottom, to: CGPoint(x: n.center.x, y: n.rect.minY),
                                 route: .v, live: live, color: color))
            prevBottom = CGPoint(x: n.center.x, y: n.rect.maxY)
        }
        if hidden > 0 {
            let n = MapNode(id: idPrefix + "/earlier", kind: .earlier(hidden),
                            center: CGPoint(x: port.x, y: y + 15), size: CGSize(width: 170, height: 30))
            nodes.append(n)
            link(n, live: false, color: .secondary)
            y = n.rect.maxY + M.stepGap
        }
        for st in shown {
            let n = MapNode(id: idPrefix + "/s/" + st.id, kind: .step(st, sessionId: sessionId, turnId: turnId),
                            center: CGPoint(x: port.x, y: y + st.height / 2), size: CGSize(width: M.cardW, height: st.height))
            nodes.append(n)
            link(n, live: st.isLive, color: st.color)
            y = n.rect.maxY + M.stepGap
        }
        return y
    }

    /// Asbob doiralari karta ostida bir qatorda. Pastki chegarani qaytaradi (asbob bo'lmasa — nil)
    private mutating func placeTools(_ tools: [TurnTool], port: CGPoint, centerY: CGFloat, idPrefix: String,
                                     sessionId: String, turnId: Int) -> CGFloat? {
        let shown = Array(tools.prefix(M.maxTools))
        let extra = tools.count - shown.count
        let n = shown.count + (extra > 0 ? 1 : 0)
        guard n > 0 else { return nil }
        let x0 = port.x - CGFloat(n - 1) * M.toolStep / 2
        for (i, tool) in shown.enumerated() {
            let c = CGPoint(x: x0 + CGFloat(i) * M.toolStep, y: centerY)
            let node = MapNode(id: idPrefix + "/" + tool.id, kind: .tool(tool, sessionId: sessionId, turnId: turnId),
                               center: c, size: CGSize(width: M.toolStep, height: M.toolD + 30))
            nodes.append(node)
            edges.append(MapEdge(id: node.id, from: port, to: CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 route: .v, live: tool.busy, color: tool.category.color))
        }
        if extra > 0 {
            let c = CGPoint(x: x0 + CGFloat(shown.count) * M.toolStep, y: centerY)
            nodes.append(MapNode(id: idPrefix + "/more", kind: .more(extra), center: c,
                                 size: CGSize(width: M.toolStep, height: M.toolD + 30)))
            edges.append(MapEdge(id: idPrefix + "/more", from: port, to: CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 route: .v, live: false, color: .secondary))
        }
        return centerY + M.toolD / 2 + 30
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
    /// Foydalanuvchi qo'lda yig'gan/ochgan bo'limlar
    @State private var toggled: Set<String> = []
    @StateObject private var wheel = WheelMonitor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let secs = MapSection.build(chain, mode: mode)
        let expandedId = selectedTurn ?? lastTurnId
        GeometryReader { geo in
            let vs = geo.size
            // Satr kengligi: odatdagi masshtabda oynaga to'liq sig'adi (kamida 3 karta)
            let rowWidth = max(3 * M.cardW + 2 * M.gap, vs.width / M.fitScale - 2 * M.pad)
            let layout = MapLayout(sections: secs, expanded: expandedId, steps: steps, rowWidth: rowWidth,
                                   isOpen: { isOpen($0, last: secs.last?.id, expanded: expandedId) },
                                   active: chain.last.map { $0.state != .idle } ?? false,
                                   lastAt: chain.last?.turns.last?.end ?? chain.last?.lastActivity)
            let visible = CGRect(x: -pan.width / scale, y: -pan.height / scale,
                                 width: vs.width / scale, height: vs.height / scale).insetBy(dx: -80, dy: -80)
            let detail = scale >= M.lod
            ZStack(alignment: .topLeading) {
                MapGrid(scale: scale, pan: pan)
                ForEach(layout.frames.filter { $0.rect.intersects(visible) }) { f in
                    RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                        .fill(Brand.surface.opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                            .stroke(f.active ? Brand.ok.opacity(0.35) : Brand.line, lineWidth: 1))
                        .frame(width: f.rect.width * scale, height: f.rect.height * scale)
                        .position(screen(CGPoint(x: f.rect.midX, y: f.rect.midY)))
                        .allowsHitTesting(false)
                }
                MapEdges(edges: layout.edges.filter { detail || !$0.isBranch }, scale: scale, pan: pan,
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

    /// Sukut bo'yicha ochiq: oxirgi bo'lim, ishlayotgani va tanlangan so'rov turgani; bosish — almashtiradi
    private func isOpen(_ s: MapSection, last: String?, expanded: String?) -> Bool {
        let def = s.id == last || s.active || s.contains(expanded)
        return def != toggled.contains(s.id)
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
        case .header(let sec, let open):
            MapSectionHeader(section: sec, open: open, mode: mode, lod: scale < M.lod ? scale : nil)
                .onTapGesture {
                    withAnimation(Motion.spring) {
                        if toggled.contains(sec.id) { toggled.remove(sec.id) } else { toggled.insert(sec.id) }
                    }
                }
        case .turn(let t, let sid, let prev, let expanded, let followUps):
            TurnCard(turn: t, previousPrompt: prev, mode: mode, selected: selectedTurn == n.id,
                     expandedSteps: expanded, followUps: followUps, lod: scale < M.lod ? scale : nil)
                .onTapGesture { onSelectTurn(sid, t.id) }
        case .followUp(let t, let sid):
            FollowUpChip(turn: t, mode: mode, selected: selectedTurn == n.id)
                .onTapGesture { onSelectTurn(sid, t.id) }
        case .tool(let tool, let sid, let tid):
            MapToolNode(tool: tool)
                .onTapGesture { onSelectTool(sid, tid, tool.category) }
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

    /// Oxirgi so'rov kartasini ko'rsatadi: satr boshi chapda; ostidagi zanjir uzun bo'lsa — eng so'nggi qadam ko'rinadigan qilib
    private func focusLast(_ layout: MapLayout, _ vs: CGSize, animated: Bool, rescale: Bool = false) {
        guard vs.width > 0, let card = layout.lastTurn?.rect else { return }
        if rescale { scale = M.fitScale }
        let end = layout.nodes.first { $0.id == "end" }?.rect
        let rightEdge = max(card.maxX, end?.maxX ?? 0)
        let bottom = max(card.maxY, layout.stepsBottom ?? 0)
        let x = min(0, vs.width - (rightEdge + M.pad) * scale)
        let a = 56 - card.minY * scale
        let b = vs.height - (bottom + 40) * scale
        let target = clamped(CGSize(width: x, height: b < a ? b : a), vs: vs, world: layout.size)
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
                    var box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x) + 1, height: abs(b.y - a.y) + 1)
                    if case .wrap(let m) = e.route { box = box.union(CGRect(x: 0, y: m * scale + pan.height, width: 1, height: 1)).insetBy(dx: -40, dy: 0) }
                    guard bounds.intersects(box) else { continue }
                    let path: Path
                    switch e.route {
                    case .h: path = hCurve(a, b)
                    case .v: path = vCurve(a, b)
                    case .wrap(let m): path = wrapPath(a, b, midY: m * scale + pan.height)
                    }
                    let w = max(1.2, 2 * scale)
                    if e.live && animated {
                        DataFlow.draw(&g, path: path, color: e.color, t: t, seed: Double(i) * 0.37, width: w)
                    } else if e.isBranch {
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

    /// Satr oxiridan keyingi satr boshiga: o'ngga chiqadi, satrlar oralig'ida chapga qaytadi, yumaloq burchaklar bilan
    private func wrapPath(_ a: CGPoint, _ b: CGPoint, midY: CGFloat) -> Path {
        let o = 26 * scale, r = 14 * scale
        let pts = [a, CGPoint(x: a.x + o, y: a.y), CGPoint(x: a.x + o, y: midY),
                   CGPoint(x: b.x - o, y: midY), CGPoint(x: b.x - o, y: b.y), b]
        var p = Path()
        p.move(to: pts[0])
        for i in 1..<pts.count - 1 {
            let prev = pts[i - 1], cur = pts[i], next = pts[i + 1]
            let d1 = hypot(cur.x - prev.x, cur.y - prev.y), d2 = hypot(next.x - cur.x, next.y - cur.y)
            let rr = min(r, d1 / 2, d2 / 2)
            let p1 = CGPoint(x: cur.x - (cur.x - prev.x) / max(d1, 0.001) * rr, y: cur.y - (cur.y - prev.y) / max(d1, 0.001) * rr)
            let p2 = CGPoint(x: cur.x + (next.x - cur.x) / max(d2, 0.001) * rr, y: cur.y + (next.y - cur.y) / max(d2, 0.001) * rr)
            p.addLine(to: p1)
            p.addQuadCurve(to: p2, control: cur)
        }
        p.addLine(to: pts[pts.count - 1])
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
    /// Ostiga ilingan javob-so'rovlar soni (port yorlig'i ular bilan to'qnashmasin)
    var followUps = 0
    /// Uzoqdan ko'rinish: masshtab (faqat raqam va qisqa nom, katta harfda)
    var lod: CGFloat? = nil

    var body: some View {
        if let lod { far(lod) } else { near }
    }

    private func far(_ s: CGFloat) -> some View {
        let k = min(0.9 / s, 3)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 6 * k) {
            HStack {
                Text("#\(turn.id)").font(.system(size: 13 * k, weight: .bold)).monospacedDigit().foregroundStyle(Brand.accent)
                Spacer()
                if turn.errors > 0 { Circle().fill(Brand.err).frame(width: 8 * k, height: 8 * k) }
            }
            Text(turn.isContinuation ? "Ish davom etdi" : turn.prompt)
                .font(.system(size: 13 * k, weight: .semibold)).lineLimit(k > 2 ? 2 : 3)
                .foregroundStyle(turn.isContinuation ? Brand.warn : .primary)
        }
        .padding(14)
        .frame(width: M.cardW, height: M.cardH, alignment: .topLeading)
        .modifier(Surface(shape: shape, tint: turn.active ? Brand.ok : nil, interactive: true,
                          stroke: selected ? Brand.accent : (turn.active ? Brand.ok : nil)))
        .contentShape(shape)
    }

    private var near: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 8) {
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
            if followUps > 0 {
                EmptyView()
            } else if let n = expandedSteps {
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

/// Bo'lim sarlavhasi: ochiq — ramka tepasidagi yupqa qator; yig'ilgan — bitta bosiladigan chiziq (xulosa bilan)
private struct MapSectionHeader: View {
    let section: MapSection
    let open: Bool
    let mode: CountMode
    let lod: CGFloat?

    private var k: CGFloat { lod.map { min(0.9 / $0, 3) } ?? 1 }

    var body: some View {
        let time = Fmt.hourMinute.string(from: section.start) + "–" + Fmt.hourMinute.string(from: section.end)
        let dur = Alerts.duration(section.end.timeIntervalSince(section.start))
        Group {
            if open {
                HStack(spacing: 8 * k) {
                    Image(systemName: "chevron.down").font(.system(size: 10 * k, weight: .bold)).foregroundStyle(.tertiary)
                    if let r = section.reason { reason(r) }
                    Text(time).font(.system(size: 12 * k).monospacedDigit()).foregroundStyle(.secondary)
                    Text(section.topic).font(.system(size: 13 * k, weight: .semibold)).lineLimit(1)
                    Spacer(minLength: 8)
                    if lod == nil {
                        Text("\(section.turnCount) so'rov · \(dur) · \(Fmt.tokens(section.tokens))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 6)
            } else {
                HStack(spacing: 12 * k) {
                    Image(systemName: "chevron.right").font(.system(size: 11 * k, weight: .bold)).foregroundStyle(.tertiary)
                    status
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.topic).font(.system(size: 13 * k, weight: .semibold)).lineLimit(1)
                        if lod == nil {
                            Text("\(time) · \(section.turnCount) so'rov · \(dur) · \(Fmt.tokens(section.tokens)) · \(section.steps) qadam")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 8)
                    if let r = section.reason { reason(r) }
                    if lod == nil {
                        Text("Ochish").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .surface(radius: 14, tint: section.active ? Brand.ok : nil, interactive: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .help(open ? "Bosing — bo'limni yig'ish" : "Bosing — bo'limni ochish: \(section.turnCount) so'rov")
    }

    @ViewBuilder
    private var status: some View {
        if section.active {
            Circle().fill(Brand.ok).frame(width: 8 * k, height: 8 * k)
        } else if section.errors > 0 {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11 * k)).foregroundStyle(Brand.warn)
        } else {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 12 * k)).foregroundStyle(.tertiary)
        }
    }

    private func reason(_ r: String) -> some View {
        Label(r, systemImage: r == "Yangi sessiya" ? "plus.circle" : "arrow.triangle.2.circlepath")
            .font(.system(size: 11 * k, weight: .semibold)).foregroundStyle(Brand.warn)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Brand.warn.opacity(0.12)))
            .fixedSize()
    }
}

/// Oldingi kartaga ilingan qisqa javob-so'rov: «↳ ha boshla · 3 daq · 28 qadam»
private struct FollowUpChip: View {
    let turn: TurnSnap
    let mode: CountMode
    let selected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.accent)
            Text(turn.prompt).font(.caption.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            if turn.active { ProgressView().controlSize(.mini) }
            if turn.errors > 0 { Text("\(turn.errors) xato").font(.caption2.weight(.semibold)).foregroundStyle(Brand.err) }
            Text("\(Alerts.duration(turn.duration)) · \(turn.steps) qadam")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(width: M.cardW - 24, height: M.chipH)
        .modifier(Surface(shape: Capsule(), tint: turn.active ? Brand.ok : nil, interactive: true,
                          stroke: selected ? Brand.accent : nil))
        .overlay { if turn.active { LiveBorder(shape: Capsule(), color: Brand.ok, lineWidth: 1.5) } }
        .contentShape(Capsule())
        .help(turn.prompt + " — bosing, qadamlar shu yerda ochiladi")
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
        // Butun xarita kichraytirib: bo'lim ramkalari, kartalar va ko'rinib turgan qism
        let w: CGFloat = 180
        let k = min(w / max(layout.size.width, 1), 120 / max(layout.size.height, 1))
        let h = max(40, layout.size.height * k)
        Canvas { g, _ in
            func r(_ x: CGRect) -> CGRect { CGRect(x: x.minX * k, y: x.minY * k, width: max(2, x.width * k), height: max(2, x.height * k)) }
            for f in layout.frames {
                g.stroke(Path(roundedRect: r(f.rect), cornerRadius: 3), with: .color(Color.secondary.opacity(0.4)), lineWidth: 1)
            }
            for n in layout.nodes {
                switch n.kind {
                case .turn(let t, _, _, _, _):
                    g.fill(Path(roundedRect: r(n.rect), cornerRadius: 1.5), with: .color(t.active ? Brand.ok : Brand.accent.opacity(0.65)))
                case .header(let s, let open):
                    if !open { g.fill(Path(roundedRect: r(n.rect), cornerRadius: 2), with: .color(s.active ? Brand.ok.opacity(0.6) : Color.secondary.opacity(0.45))) }
                case .end:
                    g.fill(Path(ellipseIn: r(n.rect)), with: .color(Color.secondary))
                default:
                    break
                }
            }
            let v = CGRect(x: (-pan.width / scale) * k, y: (-pan.height / scale) * k,
                           width: viewport.width / scale * k, height: viewport.height / scale * k)
                .intersection(CGRect(x: 0, y: 0, width: w, height: h))
            if !v.isNull {
                g.fill(Path(roundedRect: v, cornerRadius: 3), with: .color(Brand.accent.opacity(0.12)))
                g.stroke(Path(roundedRect: v, cornerRadius: 3), with: .color(Brand.accent), lineWidth: 1.2)
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            jump(CGPoint(x: v.location.x / k, y: v.location.y / k))
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
