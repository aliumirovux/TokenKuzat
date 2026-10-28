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
    /// Yuqoriga shoxlar (mahalliy ishlar) uchun satr tepasida qoldiriladigan joy
    static let upReserve: CGFloat = 132
    /// Yig'ilgan bo'lim kartasi kengligi
    static let barW: CGFloat = 240
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
    static let framePad: CGFloat = 30
    /// Satrdan satrga o'tuvchi chiziq kartadan shuncha chetga chiqadi — doim ramka ichida (framePad dan kichik)
    static let wrapOut: CGFloat = 16
    static let sectionGap: CGFloat = 40
    /// Ekran pastida boshqaruv paneli egallaydigan joy (pt) — ergashganda kontent uning ustida to'xtaydi
    static let barReserve: CGFloat = 56
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

    /// «Faqat shu so'rov» rejimi: tanlangan (yoki eng so'nggi) karta o'z bo'limida yolg'iz qoladi, qolganlari yashiriladi
    static func focused(_ secs: [MapSection], on key: String?, mode: CountMode) -> [MapSection] {
        guard let si = secs.lastIndex(where: { $0.contains(key) }) ?? (secs.isEmpty ? nil : secs.count - 1),
              let card = secs[si].cards.last(where: { $0.contains(key) }) ?? secs[si].cards.last else { return secs }
        let turns = [card.turn] + card.followUps
        var sec = MapSection(id: secs[si].id, topic: card.turn.prompt, reason: secs[si].reason,
                             start: card.turn.start, end: turns.map(\.end).max() ?? card.turn.end)
        sec.cards = [card]
        sec.turnCount = turns.count
        sec.tokens = turns.reduce(0) { $0 + $1.tokens.value(mode) }
        sec.steps = turns.reduce(0) { $0 + $1.steps }
        sec.errors = turns.reduce(0) { $0 + $1.errors }
        sec.active = turns.contains(where: \.active)
        return [sec]
    }
}

private struct MapNode: Identifiable {
    enum Kind {
        case header(MapSection, open: Bool)
        case turn(TurnSnap, sessionId: String, previousPrompt: String?, expanded: Int?, followUps: [TurnSnap])
        case tool(TurnTool, sessionId: String, turnId: Int, up: Bool)
        /// So'rovda yaratilgan/ko'rilgan rasm, HTML, PDF — yuqori shoxlar qatorining oxirida
        case outputs([OutputFile])
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
    /// Oqim chizig'i ulanadigan balandlik: kartada — asosiy qismining o'rtasi (ichidagi javoblar pastga cho'zsa ham)
    var anchorY: CGFloat {
        if case .turn = kind { return rect.minY + M.cardH / 2 }
        return center.y
    }
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
    /// Haqiqiy kontent chegarasi (ramkalar va tugunlar) — `size` dan tor bo'lishi mumkin
    var content = CGRect.zero
    /// Oxirgi so'rov kartasi — «Hozirgiga» va ergashish uchun
    var lastTurn: MapNode?
    /// Qadamlar zanjiri pastga qarab qayergacha boradi (ergashish uchun)
    var stepsBottom: CGFloat?

    /// - Parameters:
    ///   - expanded: qadamlar zanjiri ochiladigan so'rov («sessiya#raqam»)
    ///   - rowWidth: satr kengligi; kartalar shunga sig'guncha teriladi, keyin keyingi satrga o'tadi
    /// - compact: uzoqdan ko'rinish — asboblar va zanjirga joy qoldirilmaydi, satrlar zich
    init(sections: [MapSection], expanded: String?, steps: [MapStep], rowWidth: CGFloat,
         isOpen: (MapSection) -> Bool, active: Bool, lastAt: Date?, compact: Bool = false,
         outputs: (MapCard) -> [OutputFile] = { _ in [] }) {
        let rowGap = compact ? M.rowGap * 0.55 : M.rowGap
        let left = M.pad, right = M.pad + rowWidth
        var y = M.pad
        var flow: MapNode?          // oqim chizig'ining oxirgi nuqtasi
        var flowMid: CGFloat?       // keyingi ulanish satrlar oralig'idan o'tadigan bo'lsa — o'sha y

        func connect(_ n: MapNode, live: Bool) {
            guard let p = flow else { return }
            let a = CGPoint(x: p.rect.maxX, y: p.anchorY), b = CGPoint(x: n.rect.minX, y: n.anchorY)
            if abs(a.y - b.y) < 1 && b.x > a.x {
                edges.append(MapEdge(id: p.id + ">" + n.id, from: a, to: b, route: .h, live: live, color: Brand.ok))
            } else {
                edges.append(MapEdge(id: p.id + ">" + n.id, from: a, to: b,
                                     route: .wrap(midY: flowMid ?? (n.rect.minY - M.rowGap / 2)), live: live, color: Brand.ok))
            }
        }

        // Bitta qator: hamma kartalar chapdan o'ngga ulanib boradi; bo'limlar — yonma-yon ramkalar.
        // Tepaga shox (mahalliy ishlar) bor bo'lsa — qator ustida joy qoldiriladi
        let anyUp = !compact && sections.contains { sec in
            isOpen(sec) && sec.cards.contains { c in
                MapLayout.mergedTools([c.turn] + c.followUps).contains { MapLayout.goesUp($0.category) } || !outputs(c).isEmpty
            }
        }
        let headTop = y
        let rowTop = headTop + M.headH + 16 + (anyUp ? M.upReserve : 0)
        var x = left
        var bottom = rowTop + M.cardH
        _ = right; _ = rowGap

        for (si, sec) in sections.enumerated() {
            let open = isOpen(sec)
            let isLast = si == sections.count - 1
            if !open {
                // Yig'ilgan bo'lim — qatordagi bitta ixcham karta
                let head = MapNode(id: "h" + sec.id, kind: .header(sec, open: false),
                                   center: CGPoint(x: x + M.barW / 2, y: rowTop + M.cardH / 2),
                                   size: CGSize(width: M.barW, height: M.cardH))
                nodes.append(head)
                connect(head, live: false)
                flow = head
                x = head.rect.maxX + M.gap
            } else {
                let x0 = x
                var secBottom = rowTop + M.cardH
                for card in sec.cards {
                    // Qisqa javob-so'rovlar kartaning ichida, pastki qatorlarda — karta shunga cho'ziladi
                    let h = compact ? M.cardH : M.cardH + TurnCard.followUpsHeight(card.followUps.count)
                    let n = MapNode(id: card.id, kind: .turn(card.turn, sessionId: card.sessionId, previousPrompt: card.previousPrompt,
                                                             expanded: card.contains(expanded) && !steps.isEmpty ? steps.count : nil,
                                                             followUps: card.followUps),
                                    center: CGPoint(x: x + M.cardW / 2, y: rowTop + h / 2), size: CGSize(width: M.cardW, height: h))
                    nodes.append(n)
                    connect(n, live: card.turn.active || card.followUps.contains(where: \.active))
                    flow = n
                    lastTurn = n

                    // Shoxlar: mahalliy ishlar (fayllar, terminal) — yuqoriga, tashqi (internet, xizmatlar, agentlar) — pastga.
                    // Tanlangan so'rovda pastga — butun jarayon zanjiri
                    var colY = n.rect.maxY
                    if !compact {
                        let tools = MapLayout.mergedTools([card.turn] + card.followUps)
                        let upTools = tools.filter { MapLayout.goesUp($0.category) }
                        let downTools = tools.filter { !MapLayout.goesUp($0.category) }
                        _ = placeTools(upTools, port: CGPoint(x: n.center.x, y: n.rect.minY), centerY: n.rect.minY - M.toolDrop + 10,
                                       up: true, idPrefix: card.id + "/u", sessionId: card.sessionId, turnId: card.turn.id,
                                       outputs: outputs(card))
                        let port = CGPoint(x: n.center.x, y: n.rect.maxY)
                        if card.contains(expanded) && !steps.isEmpty {
                            let tid = Int(expanded?.split(separator: "#").last ?? "") ?? card.turn.id
                            colY = placeSteps(steps, port: port, top: colY + M.stepTop,
                                              idPrefix: card.id, sessionId: card.sessionId, turnId: tid)
                            stepsBottom = colY
                        } else {
                            colY = placeTools(downTools, port: port, centerY: colY + M.toolDrop, up: false,
                                              idPrefix: card.id, sessionId: card.sessionId, turnId: card.turn.id) ?? colY
                        }
                    }
                    secBottom = max(secBottom, colY)
                    x += M.cardW + M.gap
                }
                let secW = max(M.cardW, x - M.gap - x0)
                // Bo'lim sarlavhasi — o'z kartalari ustida, ramka tepasida
                let head = MapNode(id: "h" + sec.id, kind: .header(sec, open: true),
                                   center: CGPoint(x: x0 + secW / 2, y: headTop + M.headH / 2),
                                   size: CGSize(width: secW, height: M.headH))
                nodes.append(head)
                frames.append(MapFrame(id: sec.id,
                                       rect: CGRect(x: x0 - M.framePad, y: headTop - 8,
                                                    width: secW + 2 * M.framePad, height: secBottom + M.framePad - headTop + 8),
                                       active: sec.active))
                bottom = max(bottom, secBottom)
                x += 2 * M.framePad
            }
            if isLast {
                let e = MapNode(id: "end", kind: .end(active: active, at: lastAt),
                                center: CGPoint(x: x + M.endD / 2, y: rowTop + M.cardH / 2), size: CGSize(width: M.endD, height: M.endD))
                nodes.append(e)
                connect(e, live: active)
                x = e.rect.maxX + M.gap
            }
        }
        y = bottom + M.framePad
        size = CGSize(width: x + M.pad, height: y + M.pad)
        content = (frames.map(\.rect) + nodes.map(\.rect)).reduce(CGRect.null) { $0.union($1) }
        if content.isNull { content = CGRect(origin: .zero, size: size) }
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

    /// Bir nechta so'rov asboblari tur bo'yicha qo'shiladi
    static func mergedTools(_ turns: [TurnSnap]) -> [TurnTool] {
        guard turns.count > 1 else { return turns.first?.tools ?? [] }
        var acc: [ToolCategory: (calls: Int, errors: Int, top: String, busy: Bool)] = [:]
        for t in turns {
            for tool in t.tools {
                var a = acc[tool.category] ?? (0, 0, tool.top, false)
                a.calls += tool.calls
                a.errors += tool.errors
                a.busy = a.busy || tool.busy
                acc[tool.category] = a
            }
        }
        return acc.map { TurnTool(category: $0.key, calls: $0.value.calls, errors: $0.value.errors, top: $0.value.top, busy: $0.value.busy) }
            .sorted { $0.calls > $1.calls }
    }

    /// Mahalliy ishlar yuqoriga shoxlanadi, tashqilari — pastga
    static func goesUp(_ c: ToolCategory) -> Bool { c == .files || c == .shell || c == .other }

    /// Asbob doiralari karta ostida (yoki `up` — ustida) bir qatorda. Pastki chegarani qaytaradi (asbob bo'lmasa — nil)
    private mutating func placeTools(_ tools: [TurnTool], port: CGPoint, centerY: CGFloat, up: Bool, idPrefix: String,
                                     sessionId: String, turnId: Int, outputs: [OutputFile] = []) -> CGFloat? {
        let shown = Array(tools.prefix(M.maxTools))
        let extra = tools.count - shown.count
        let n = shown.count + (extra > 0 ? 1 : 0) + (outputs.isEmpty ? 0 : 1)
        guard n > 0 else { return nil }
        let x0 = port.x - CGFloat(n - 1) * M.toolStep / 2
        for (i, tool) in shown.enumerated() {
            let c = CGPoint(x: x0 + CGFloat(i) * M.toolStep, y: centerY)
            let node = MapNode(id: idPrefix + "/" + tool.id, kind: .tool(tool, sessionId: sessionId, turnId: turnId, up: up),
                               center: c, size: CGSize(width: M.toolStep, height: M.toolD + 30))
            nodes.append(node)
            // Pastga: doiraning tepasiga; yuqoriga: doiraning pastiga (yozuv doira ustida)
            let end = up ? CGPoint(x: c.x, y: node.rect.maxY - 6) : CGPoint(x: c.x, y: c.y - M.toolD / 2)
            edges.append(MapEdge(id: node.id, from: port, to: end, route: .v, live: tool.busy, color: tool.category.color))
        }
        if extra > 0 {
            let c = CGPoint(x: x0 + CGFloat(shown.count) * M.toolStep, y: centerY)
            let more = MapNode(id: idPrefix + "/more", kind: .more(extra), center: c,
                               size: CGSize(width: M.toolStep, height: M.toolD + 30))
            nodes.append(more)
            edges.append(MapEdge(id: idPrefix + "/more", from: port,
                                 to: up ? CGPoint(x: c.x, y: more.rect.maxY - 6) : CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 route: .v, live: false, color: .secondary))
        }
        if !outputs.isEmpty {
            // Natijalar — qatorning oxirgi o'rni, alohida shox
            let c = CGPoint(x: x0 + CGFloat(n - 1) * M.toolStep, y: centerY)
            let node = MapNode(id: idPrefix + "/outputs", kind: .outputs(outputs), center: c,
                               size: CGSize(width: M.toolStep, height: M.toolD + 30))
            nodes.append(node)
            edges.append(MapEdge(id: node.id, from: port,
                                 to: up ? CGPoint(x: c.x, y: node.rect.maxY - 6) : CGPoint(x: c.x, y: c.y - M.toolD / 2),
                                 route: .v, live: false, color: Brand.accent))
        }
        return centerY + M.toolD / 2 + 30
    }
}

/// Oxirgi chizilgan joylashuv — zoom chegarasidan o'tganda karta joyini saqlash uchun (UI holati emas)
private final class LayoutCache: ObservableObject {
    var layout: MapLayout?
    var anchor: (String, CGPoint)?
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
    /// Bitta qadam bosildi — kirish / chiqish tafsiloti
    var onSelectStep: (_ sessionId: String, _ step: StepSnap) -> Void = { _, _ in }
    /// O'ylash yoki javob kartasi bosildi — to'liq matn o'ng panelda
    var onSelectNote: (_ sessionId: String, _ note: NoteSnap) -> Void = { _, _ in }
    /// Ishlab chiquvchi uchun (`--snapshot-map`): boshlang'ich masshtab
    var initialScale: CGFloat? = nil
    /// Jonli ko'rinish (replay va rasm emas): «Faqat xarita» tugmasi chiqadi
    var interactive = false

    @State private var scale: CGFloat = 0.9
    @State private var pan = CGSize.zero
    @State private var follow = true
    @State private var placed = false
    @State private var dragStart: CGSize?
    @State private var pinchStart: CGFloat?
    @State private var cursor: CGPoint?
    @State private var viewport = CGSize.zero
    @State private var world = CGSize.zero
    /// Kontent chegarasi — xarita bo'sh joyga surib yuborilmasin
    @State private var bounds = CGRect.zero
    /// Foydalanuvchi qo'lda yig'gan/ochgan bo'limlar
    @State private var toggled: Set<String> = []
    /// Robot: patrul qadami va oxirgi bosilgan payt
    @State private var patrolTick = 0
    @State private var poke: Date?
    /// Faqat tanlangan (sukut bo'yicha — hozirgi) so'rovni ko'rsatish, qolganlarini yashirish
    @AppStorage("map.focusOne") private var focusOne = false
    /// «Faqat xarita» — boshqa hamma narsa yashiriladi (sessiya sahifasi va asosiy oyna shu qiymatga qaraydi)
    @AppStorage(Pref.mapOnly) private var mapOnly = false
    private let patrolTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    @StateObject private var wheel = WheelMonitor()
    @StateObject private var cache = LayoutCache()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let expandedId = selectedTurn ?? lastTurnId
        let all = MapSection.build(chain, mode: mode)
        let secs = focusOne ? MapSection.focused(all, on: expandedId, mode: mode) : all
        GeometryReader { geo in
            let vs = geo.size
            // Satr kengligi: odatdagi masshtabda oynaga to'liq sig'adi (kamida 3 karta)
            let rowWidth = max(3 * M.cardW + 2 * M.gap, vs.width / M.fitScale - 2 * M.pad)
            let byTurn = outputsByTurn
            let layout = MapLayout(sections: secs, expanded: expandedId, steps: steps, rowWidth: rowWidth,
                                   isOpen: { isOpen($0, last: secs.last?.id, expanded: expandedId) },
                                   active: chain.last.map { $0.state != .idle } ?? false,
                                   lastAt: chain.last?.turns.last?.end ?? chain.last?.lastActivity,
                                   compact: scale < M.lod,
                                   outputs: { card in
                                       ([card.turn] + card.followUps).flatMap { byTurn["\(card.sessionId)#\($0.id)"] ?? [] }
                                   })
            let _ = cache.layout = layout
            let visible = CGRect(x: -pan.width / scale, y: -pan.height / scale,
                                 width: vs.width / scale, height: vs.height / scale).insetBy(dx: -80, dy: -80)
            let detail = scale >= M.lod
            // Ekran markazi bo'sh va kontent deyarli ko'rinmaydi (sig'adigan qismining 25% dan kami) —
            // foydalanuvchi bo'sh joyga chiqib ketgan
            let lost: Bool = {
                let view = visible.insetBy(dx: 80, dy: 80)
                let middle = view.insetBy(dx: view.width / 4, dy: view.height / 4)
                if layout.nodes.contains(where: { $0.rect.intersects(middle) }) { return false }
                let shown = layout.nodes.reduce(CGFloat(0)) { acc, n in
                    let r = n.rect.intersection(view); return r.isNull ? acc : acc + r.width * r.height
                }
                let total = layout.nodes.reduce(CGFloat(0)) { $0 + $1.rect.width * $1.rect.height }
                return total > 0 && shown < 0.25 * min(total, view.width * view.height)
            }()
            ZStack(alignment: .topLeading) {
                MapGrid(scale: scale, pan: pan)
                ForEach(layout.frames.filter { $0.rect.intersects(visible) }) { f in
                    RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                        .fill(Brand.surface.opacity(0.28))
                        .overlay(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                            .stroke(Brand.line, lineWidth: 1))
                        .frame(width: f.rect.width * scale, height: f.rect.height * scale)
                        .position(screen(CGPoint(x: f.rect.midX, y: f.rect.midY)))
                        .allowsHitTesting(false)
                }
                // Ikki qatlam: qimirlamaydigan chiziqlar faqat joylashuv o'zgarganda chiziladi,
                // har kadrda — faqat jonlilari (aks holda butun chiziqlar to'plami 30 marta/s qayta chiziladi)
                let shownEdges = layout.edges.filter { detail || !$0.isBranch }
                MapEdges(edges: shownEdges.filter { !$0.live }, scale: scale, pan: pan, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                MapEdges(edges: shownEdges.filter(\.live), scale: scale, pan: pan, reduceMotion: reduceMotion)
                    .allowsHitTesting(false)
                ForEach(layout.nodes.filter { $0.rect.intersects(visible) && (detail || $0.isMainRow) }) { n in
                    node(n)
                        .frame(width: n.size.width, height: n.size.height)
                        .scaleEffect(scale)
                        .position(screen(n.center))
                }
                // Nazoratchi robot: ishlayotgan kartaning burchagida; tinch paytda kartalar bo'ylab patrul qiladi
                if detail, let robot = robotSpot(layout) {
                    ZStack { RobotView(action: robot.1, size: 50) }
                        .frame(width: 220, height: 110, alignment: .bottom)
                        .contentShape(Rectangle())
                        .onTapGesture { poke = Date() }
                        .help("Bosing — robot salom beradi")
                        .scaleEffect(scale)
                        .position(screen(robot.0))
                        .animation(.spring(response: 0.95, dampingFraction: 0.74), value: robot.0)
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
            .overlay(alignment: .bottom) {
                // Pastki fade: kartalar boshqaruv paneli ostiga keskin kirib qolmaydi
                LinearGradient(colors: [Brand.canvas.opacity(0), Brand.canvas.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                    .frame(height: M.barReserve + 24)
                    .allowsHitTesting(false)
            }
            .overlay {
                if lost {
                    Button {
                        follow = true
                        focusLast(layout, vs, animated: true)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "location.north.circle")
                            Text("Xarita bu yerda emas · Hozirgiga qaytish")
                        }
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(Brand.accent)
                        .padding(.horizontal, 14).frame(height: 36)
                        .surface(radius: 12, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) { controls(layout, vs).padding(12) }
            .overlay(alignment: .topTrailing) {
                // «Faqat xarita» — yuqori o'ng burchakda, faqat belgi
                if interactive {
                    Button {
                        withAnimation(Motion.spring) { mapOnly.toggle() }
                        follow = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                            if let l = cache.layout { focusLast(l, viewport, animated: true) }
                        }
                    } label: {
                        Image(systemName: mapOnly ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(mapOnly ? Brand.accent : Color.primary)
                            .frame(width: 32, height: 32)
                            .surface(radius: 10, interactive: true)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(mapOnly ? .cancelAction : KeyboardShortcut("f", modifiers: [.command, .shift]))
                    .help(mapOnly ? "Oddiy ko'rinishga qaytish (Esc)" : "Faqat xarita — qolgan hamma narsa yashiriladi (⇧⌘F)")
                    .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                // Tor xaritada minixarita yashiriladi — boshqaruv tugmalari bilan to'qnashmasin
                if vs.width >= 700 {
                MiniMap(layout: layout, scale: scale, pan: pan, viewport: vs) { center in
                    follow = false
                    pan = clamped(CGSize(width: vs.width / 2 - center.x * scale, height: vs.height / 2 - center.y * scale))
                }
                .padding(12)
                }
            }
            .onAppear {
                viewport = vs
                world = layout.size
                bounds = layout.content
                wheel.onWheel = { e in handleWheel(e) }
                wheel.start()
                if !placed {
                    placed = true
                    focusLast(layout, vs, animated: false, rescale: true)
                    // --zoom 0 — hammasini sig'dirish, aks holda shu masshtabda oxirgi so'rov
                    if let s0 = initialScale {
                        if s0 <= 0 { fit(layout, vs) } else { scale = s0; focusLast(layout, vs, animated: false) }
                    }
                }
            }
            .onDisappear { wheel.stop() }
            .onReceive(patrolTimer) { _ in patrolTick += 1 }
            .onChange(of: vs) { new in
                // Oyna o'lchami o'zgarsa: zoom va vertikal joylashuv yangi o'lchamga moslashadi
                let old = viewport
                viewport = new
                if follow { focusLast(layout, new, animated: false, rescale: true); return }
                let dy = (new.height - old.height) / 2
                pan = clamped(CGSize(width: pan.width, height: pan.height + dy))
            }
            .onChange(of: layout.size) { world = $0 }
            .onChange(of: layout.content) { bounds = $0 }
            .onChange(of: scale < M.lod) { _ in
                // Zich/to'liq joylashuv almashdi — markazdagi karta ekranda joyidan siljimasin
                guard let (id, screenPos) = cache.anchor, let n = layout.nodes.first(where: { $0.id == id }) else { return }
                pan = clamped(CGSize(width: screenPos.x - n.center.x * scale, height: screenPos.y - n.center.y * scale))
                cache.anchor = nil
            }
            .onChange(of: layout.lastTurn?.id) { _ in
                if follow { focusLast(layout, vs, animated: true) }
            }
            .onChange(of: steps.count) { _ in
                if follow { focusLast(layout, vs, animated: true) }
            }
        }
        .background(Brand.canvas)
    }

    /// Robot qayerda va nima qiladi. Ish ketayotganda — oxirgi kartaning chap-yuqori burchagida, vazifaga mos;
    /// tinch paytda — oxirgi kartalar bo'ylab navbat bilan uchib, durbin bilan «nazorat qiladi», goh-goh mudraydi
    private func robotSpot(_ l: MapLayout) -> (CGPoint, RobotView.Action)? {
        guard let session = chain.last else { return nil }
        let cards = l.nodes.filter { if case .turn = $0.kind { return true }; return false }
        guard let lastCard = l.lastTurn ?? cards.last else { return nil }
        var action = RobotView.action(for: session, waiting: waiting != nil)
        var card = lastCard
        if action == .sleeping, cards.count > 1 {
            // Oxirgi 5 karta bo'ylab borib-qaytadi; har uchinchi davrada biroz mudraydi
            let recent = Array(cards.suffix(5))
            let n = recent.count, period = max(1, 2 * n - 2)
            let k = patrolTick % period
            card = recent[k < n ? k : period - k]
            action = (patrolTick / (period * 2)) % 3 == 2 ? .sleeping : .watching
        }
        if let p = poke, Date().timeIntervalSince(p) < 2.5 { action = .hello }
        // Kartaning chap-yuqori burchagida o'tiradi — tepadagi shoxlar (o'rtada) bilan to'qnashmaydi
        return (CGPoint(x: card.rect.minX + 22, y: card.rect.minY - 46), action)
    }

    /// Sukut bo'yicha ochiq: oxirgi bo'lim, ishlayotgani va tanlangan so'rov turgani; bosish — almashtiradi
    private func isOpen(_ s: MapSection, last: String?, expanded: String?) -> Bool {
        let def = s.id == last || s.active || s.contains(expanded)
        return def != toggled.contains(s.id)
    }

    /// Natijalar so'rovlar bo'yicha («sessiya#so'rov»): fayl oxirgi marta tegilgan payt qaysi so'rov ichida bo'lsa
    private var outputsByTurn: [String: [OutputFile]] {
        var out: [String: [OutputFile]] = [:]
        for s in chain {
            let starts = s.turns.map(\.start)
            for f in SessionOutputs.collect(s) {
                guard let d = f.lastActivity, let i = starts.lastIndex(where: { $0 <= d }) else { continue }
                out["\(s.id)#\(s.turns[i].id)", default: []].append(f)
            }
        }
        return out
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
                     expandedSteps: expanded, followUps: followUps,
                     selectedFollowUp: followUps.first { selectedTurn == "\(sid)#\($0.id)" }?.id,
                     lod: scale < M.lod ? scale : nil,
                     onSelectFollowUp: { onSelectTurn(sid, $0) })
                .onTapGesture { onSelectTurn(sid, t.id) }
        case .tool(let tool, let sid, let tid, let up):
            MapToolNode(tool: tool, up: up)
                .onTapGesture { onSelectTool(sid, tid, tool.category) }
        case .step(let st, let sid, let tid):
            MapStepNode(item: st)
                .onTapGesture {
                    switch st.item {
                    case .step(let s): onSelectStep(sid, s)
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
        case .outputs(let files):
            MapOutputsNode(files: files)
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
        // Bitta yaxlit panel: masshtab | ergashish | faqat shu so'rov
        HStack(spacing: 0) {
            iconButton("minus", "Kichraytirish") { zoom(to: scale / 1.25, around: center(vs)) }
            Text("\(Int((scale * 100).rounded()))%")
                .font(.caption.weight(.semibold)).monospacedDigit().frame(width: 44)
            iconButton("plus", "Kattalashtirish") { zoom(to: scale * 1.25, around: center(vs)) }
            Divider().frame(height: 16)
            iconButton("viewfinder", "Hammasini sig'dirish (masshtabni moslash)") { fit(layout, vs) }
            Divider().frame(height: 16)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Oxirgi so'rovga o'tish va yangi so'rovlarga ergashish")
            Divider().frame(height: 16)

            Button {
                withAnimation(Motion.spring) { focusOne.toggle() }
                follow = true
                // Joylashuv yangilangach — kartaga markazlashadi
                DispatchQueue.main.async { if let l = cache.layout { focusLast(l, vs, animated: true, rescale: true) } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: focusOne ? "rectangle.on.rectangle" : "scope")
                    Text(focusOne ? "Hammasini ko'rsatish" : "Faqat shu so'rov")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(focusOne ? Brand.accent : Color.primary)
                .padding(.horizontal, 10).frame(height: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(focusOne ? "Barcha so'rovlarni qaytarish"
                           : "Faqat hozirgi (yoki tepada tanlangan) so'rovni ko'rsatish, qolganlarini yashirish")
        }
        .padding(.horizontal, 2)
        .surface(radius: 10, interactive: true)
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
        if (ns < M.lod) != (scale < M.lod), let l = cache.layout {
            // Joylashuv almashadi: ko'rsatkich ostidagi (yoki eng yaqin) karta eslab qolinadi
            let wp = CGPoint(x: (anchor.x - pan.width) / scale, y: (anchor.y - pan.height) / scale)
            if let n = l.nodes.filter(\.isMainRow).min(by: { hypot($0.center.x - wp.x, $0.center.y - wp.y) < hypot($1.center.x - wp.x, $1.center.y - wp.y) }) {
                let sx = anchor.x + (n.center.x - wp.x) * ns, sy = anchor.y + (n.center.y - wp.y) * ns
                cache.anchor = (n.id, CGPoint(x: sx, y: sy))
            }
        }
        let wx = (anchor.x - pan.width) / scale, wy = (anchor.y - pan.height) / scale
        scale = ns
        pan = clamped(CGSize(width: anchor.x - wx * ns, height: anchor.y - wy * ns))
    }

    private func fit(_ layout: MapLayout, _ vs: CGSize) {
        // Haqiqiy kontentni sig'diradi; pastki panel ostida qolmasin
        let c = layout.content.insetBy(dx: -M.pad / 2, dy: -M.pad / 2)
        let h = vs.height - M.barReserve
        let s = min(1, max(0.2, min(vs.width / c.width, h / c.height)))
        scale = s
        pan = CGSize(width: (vs.width - c.width * s) / 2 - c.minX * s, height: (h - c.height * s) / 2 - c.minY * s)
    }

    /// Oxirgi so'rov kartasini ko'rsatadi: satr boshi chapda; ostidagi zanjir uzun bo'lsa — eng so'nggi qadam ko'rinadigan qilib
    private func focusLast(_ layout: MapLayout, _ vs: CGSize, animated: Bool, rescale: Bool = false) {
        guard vs.width > 0, let card = layout.lastTurn?.rect else { return }
        if rescale { scale = M.fitScale }
        let end = layout.nodes.first { $0.id == "end" }?.rect
        let rightEdge = max(card.maxX, end?.maxX ?? 0)
        let bottom = max(card.maxY, layout.stepsBottom ?? 0)
        // «Faqat shu so'rov»da xarita oynaga sig'sa — gorizontal markazda
        let cw = layout.size.width * scale
        let x = focusOne && cw <= vs.width ? (vs.width - cw) / 2 : min(0, vs.width - (rightEdge + M.pad) * scale)
        // Bitta qator: tepasi (bo'lim sarlavhalari va yuqori shoxlar) ko'rinadi; zanjir uzun bo'lsa — uning oxiri
        let a = 16 - (M.pad - 16) * scale
        let b = vs.height - M.barReserve - (bottom + 16) * scale
        // Balandlikka sig'sa — vertikal markazda (pastki panel joyidan tashqari)
        let ch = layout.size.height * scale, free = vs.height - M.barReserve
        let ty = ch <= free ? (free - ch) / 2 : (b < a ? b : a)
        let target = clamped(CGSize(width: x, height: ty), vs: vs, world: layout.size, content: layout.content)
        if animated && !reduceMotion { withAnimation(Motion.spring) { pan = target } } else { pan = target }
    }

    /// Xarita ekrandan butunlay chiqib ketmasin: kontent ekranning kamida 40% ida ko'rinib turadi
    /// (bo'sh joy emas — haqiqiy kartalar); sig'sa — vertikal ichkarida qoladi
    private func clamped(_ p: CGSize, vs: CGSize? = nil, world: CGSize? = nil, content: CGRect? = nil) -> CGSize {
        let v = vs ?? viewport, w = world ?? self.world
        guard v.width > 0, w.width > 0 else { return p }
        let c = content ?? (bounds.isEmpty ? CGRect(origin: .zero, size: w) : bounds)
        let ch = w.height * scale
        // Kontent ekranning kamida ~40% ini egallab tursin — chetga surilganda bo'sh maydon qolmaydi
        let keepX = min(v.width * 0.4, c.width * scale / 2), keepY = min(v.height * 0.4, c.height * scale / 2)
        let x = min(v.width - keepX - c.minX * scale, max(keepX - c.maxX * scale, p.width))
        var y: CGFloat = ch <= v.height
            ? min(v.height - ch, max(0, p.height))
            : min(0, max(v.height - ch, p.height))
        // Baland xaritada ham kontent qatori ko'rinishda qolsin
        y = min(v.height - keepY - c.minY * scale, max(keepY - c.maxY * scale, y))
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
    @AppStorage(Pref.lightMode) private var lightMode = false

    var body: some View {
        let animated = edges.contains(where: \.live) && !reduceMotion && !lightMode
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animated)) { ctx in
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
        let o = M.wrapOut * scale, r = 10 * scale
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
        // Pastga ham, yuqoriga ham: boshqaruv nuqtalari yo'nalish bo'yicha
        let raw = (b.y - a.y) * 0.55
        let dy = abs(raw) < 16 ? (raw < 0 ? -16 : 16) : raw
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
    /// Kartaga ilingan qisqa javob-so'rovlar — pastki qatorlarda
    var followUps: [TurnSnap] = []
    var selectedFollowUp: Int? = nil
    /// Uzoqdan ko'rinish: masshtab (faqat raqam va qisqa nom, katta harfda)
    var lod: CGFloat? = nil
    var onSelectFollowUp: (Int) -> Void = { _ in }

    static let followUpRowH: CGFloat = 30
    static func followUpsHeight(_ n: Int) -> CGFloat { n == 0 ? 0 : CGFloat(n) * followUpRowH + 10 }

    /// Karta yoki unga ilingan javoblardan biri hozir ishlayapti
    private var isLive: Bool { turn.active || followUps.contains(where: \.active) }

    private var height: CGFloat { M.cardH + Self.followUpsHeight(followUps.count) }

    var body: some View {
        if let lod { far(lod) } else { near }
    }

    private func far(_ s: CGFloat) -> some View {
        let k = min(0.7 / s, 1.8)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 6 * k) {
            HStack {
                Text("#\(turn.id)").font(.system(size: 13 * k, weight: .bold)).monospacedDigit().foregroundStyle(Brand.accent)
                Spacer()
                if turn.errors > 0 { Circle().fill(Brand.err).frame(width: 8 * k, height: 8 * k) }
            }
            Text(turn.isContinuation ? "↻ Davom etdi" : turn.prompt)
                .font(.system(size: 12.5 * k, weight: .semibold)).lineLimit(3)
                .foregroundStyle(turn.isContinuation ? Brand.warn : .primary)
            Spacer(minLength: 0)
            if !followUps.isEmpty {
                Text("↳ +\(followUps.count)").font(.system(size: 11 * k, weight: .semibold)).foregroundStyle(Brand.accent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(Surface(shape: shape, tint: isLive ? Brand.ok : nil, interactive: true,
                          stroke: selected ? Brand.accent : (isLive ? Brand.ok : nil)))
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
            .frame(height: 16)
            if !followUps.isEmpty {
                VStack(spacing: 0) {
                    ForEach(followUps) { f in
                        Divider()
                        followUpRow(f)
                    }
                }
                .padding(.horizontal, -14)
            }
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, followUps.isEmpty ? 14 : 0)
        .frame(width: M.cardW, height: height, alignment: .topLeading)
        .modifier(Surface(shape: shape, tint: isLive ? Brand.ok : nil, interactive: true,
                          stroke: selected ? Brand.accent : nil))
        .overlay { if isLive { LiveBorder(shape: shape, color: Brand.ok, lineWidth: 2) } }
        .overlay(alignment: .bottom) {
            if let n = expandedSteps {
                portPill("Jarayon · \(n) qadam", Brand.accent).offset(y: 11)
            } else if (([turn] + followUps).flatMap(\.tools)).contains(where: { !MapLayout.goesUp($0.category) }) {
                // Faqat pastga shox bo'lsa (tashqi ishlar); mahalliylari tepadan chiqadi
                portPill("Asboblar", .secondary).offset(y: 11)
            }
        }
        .shadow(color: .black.opacity(0.16), radius: 4, y: 2)
        .contentShape(shape)
        .help(turn.isContinuation ? "Kontekst tugab, suhbat xulosa bilan davom ettirildi" : turn.prompt)
    }

    /// «↳ Bosdim · 20 s · 2 qadam» — bosilsa, qadamlari karta ostida ochiladi
    private func followUpRow(_ f: TurnSnap) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.turn.down.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(Brand.accent)
            Text(f.prompt).font(.caption.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            if f.active { Spinner(size: 10) }
            if f.errors > 0 { Text("\(f.errors) xato").font(.caption2.weight(.semibold)).foregroundStyle(Brand.err) }
            Text("\(Alerts.duration(f.duration)) · \(f.steps) qadam")
                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).fixedSize()
        }
        .padding(.horizontal, 14)
        .frame(height: Self.followUpRowH)
        .background(selectedFollowUp == f.id ? Brand.accentSoft : .clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelectFollowUp(f.id) }
        .help(f.prompt + " — bosing, qadamlari karta ostida ochiladi")
    }

    @ViewBuilder
    private var status: some View {
        if isLive {
            HStack(spacing: 4) { Spinner(size: 10); Text("ishlayapti") }
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

    private var k: CGFloat { lod.map { min(0.75 / $0, 2.2) } ?? 1 }

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
                // Yig'ilgan bo'lim — qatordagi ixcham karta: mavzu, vaqt va hajm
                VStack(alignment: .leading, spacing: 6 * k) {
                    HStack(spacing: 6 * k) {
                        status
                        Text("\(section.turnCount) so'rov").font(.system(size: 11 * k, weight: .semibold)).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        if let r = section.reason, lod == nil { reason(r) }
                    }
                    Text(section.topic).font(.system(size: 13 * k, weight: .semibold)).lineLimit(3)
                    Spacer(minLength: 0)
                    if lod == nil {
                        Text("\(time) · \(dur)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        HStack {
                            Text("\(Fmt.tokens(section.tokens)) · \(section.steps) qadam")
                                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            Spacer()
                            Label("Ochish", systemImage: "chevron.right").labelStyle(.titleAndIcon)
                                .font(.caption.weight(.semibold)).foregroundStyle(Brand.accent)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .surface(radius: 16, tint: section.active ? Brand.ok : nil, interactive: true)
                .overlay(alignment: .trailing) {
                    // Ichida kartalar borligini bildiruvchi qatlam izi
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Brand.line)
                        .offset(x: 5, y: 5).allowsHitTesting(false)
                }
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

/// «Natijalar» shoxi: eng so'nggi rasm/HTML kichik ko'rinishda; bosilsa — katta ko'rinish (Quick Look) oynachasi
private struct MapOutputsNode: View {
    let files: [OutputFile]
    @State private var open = false

    var body: some View {
        VStack(spacing: 6) {
            Text("Natijalar").font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
            ZStack(alignment: .topTrailing) {
                Thumbnail(path: files[0].path)
                    .frame(width: M.toolD + 8, height: M.toolD)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Brand.accent.opacity(0.8), lineWidth: 1.5))
                Text("\(files.count)")
                    .font(.system(size: 9, weight: .bold)).monospacedDigit()
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Brand.accent))
                    .foregroundStyle(.white)
                    .offset(x: 8, y: -3)
            }
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .contentShape(Rectangle())
        .onTapGesture { open = true }
        .help("Natijalar: " + files.prefix(3).map(\.name).joined(separator: ", ") + (files.count > 3 ? "…" : "") + " — bosing")
        .popover(isPresented: $open, arrowEdge: .top) { OutputsPopover(files: files) }
    }
}

/// Xaritadan ochiladigan katta ko'rinish: tepada natijalar qatori, ostida tanlangani
private struct OutputsPopover: View {
    let files: [OutputFile]
    @State private var selected: String?

    var body: some View {
        let current = files.first { $0.path == selected } ?? files[0]
        VStack(spacing: 0) {
            if files.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(files) { f in
                            Thumbnail(path: f.path)
                                .frame(width: 96, height: 60)
                                .background(Color.black.opacity(0.3))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(f.path == current.path ? Brand.accent : Brand.line, lineWidth: f.path == current.path ? 2 : 1))
                                .onTapGesture { selected = f.path }
                                .help(f.name)
                        }
                    }
                    .padding(10)
                }
                Divider()
            }
            OutputDetail(file: current)
        }
        .frame(width: 640, height: 480)
    }
}

private struct MapToolNode: View {
    let tool: TurnTool
    /// Yuqoriga shox: yozuv doira ustida, doira pastda (kartaga yaqin)
    var up = false

    var body: some View {
        VStack(spacing: 6) {
            if up { label }
            circle
            if !up { label }
        }
        .frame(maxHeight: .infinity, alignment: up ? .bottom : .top)
        .contentShape(Rectangle())
        .help("\(tool.category.title): \(tool.calls) chaqiruv\(tool.top.isEmpty ? "" : " · ko'pi: \(tool.top)")")
    }

    private var label: some View {
        Text(tool.category.title).font(.caption2.weight(.medium)).lineLimit(1).minimumScaleFactor(0.8)
    }

    private var circle: some View {
        let color = tool.category.color
        return ZStack(alignment: .topTrailing) {
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
                Spinner(size: 14)
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
        // Faqat kontent (bo'sh joysiz) kichraytirib: bo'lim ramkalari, kartalar va ko'rinib turgan qism
        let c = layout.content.insetBy(dx: -12, dy: -12)
        let k = min(160 / max(c.width, 1), 96 / max(c.height, 1))
        let w = max(40, c.width * k), h = max(28, c.height * k)
        Canvas { g, _ in
            func r(_ x: CGRect) -> CGRect { CGRect(x: (x.minX - c.minX) * k, y: (x.minY - c.minY) * k, width: max(2, x.width * k), height: max(2, x.height * k)) }
            for f in layout.frames {
                g.stroke(Path(roundedRect: r(f.rect), cornerRadius: 3), with: .color(Color.secondary.opacity(0.4)), lineWidth: 1)
            }
            for n in layout.nodes {
                switch n.kind {
                case .turn(let t, _, _, _, let fs):
                    g.fill(Path(roundedRect: r(n.rect), cornerRadius: 1.5),
                           with: .color(t.active || fs.contains(where: \.active) ? Brand.ok : Brand.accent.opacity(0.65)))
                case .header(let s, let open):
                    if !open { g.fill(Path(roundedRect: r(n.rect), cornerRadius: 2), with: .color(s.active ? Brand.ok.opacity(0.6) : Color.secondary.opacity(0.45))) }
                case .end:
                    g.fill(Path(ellipseIn: r(n.rect)), with: .color(Color.secondary))
                default:
                    break
                }
            }
            let v = r(CGRect(x: -pan.width / scale, y: -pan.height / scale,
                             width: viewport.width / scale, height: viewport.height / scale))
                .intersection(CGRect(x: 0, y: 0, width: w, height: h).insetBy(dx: 0.6, dy: 0.6))
            if !v.isNull {
                g.fill(Path(roundedRect: v, cornerRadius: 3), with: .color(Brand.accent.opacity(0.12)))
                g.stroke(Path(roundedRect: v, cornerRadius: 3), with: .color(Brand.accent), lineWidth: 1.2)
            }
        }
        .frame(width: w, height: h)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
            jump(CGPoint(x: v.location.x / k + c.minX, y: v.location.y / k + c.minY))
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
            if item.isLive { Spinner(size: 10) }
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
