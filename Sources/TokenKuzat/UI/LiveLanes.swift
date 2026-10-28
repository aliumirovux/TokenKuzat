import SwiftUI
import TokenKuzatCore

// Parallel chiziqlar: barcha sessiyalar bitta umumiy vaqt o'qida. Har sessiya — qator (ostida yordamchi
// agentlari), har qadam — boshlanishidan tugashigacha rangli chiziq. Qaysi agent qachon nima qilgani bir qarashda.

/// Ko'rinadigan vaqt oralig'i
enum LaneWindow: Int, CaseIterable, Identifiable {
    case m10 = 600, m30 = 1800, h1 = 3600, h3 = 10800
    var id: Int { rawValue }
    var title: String {
        switch self {
        case .m10: return tr("10 daq", "10 min")
        case .m30: return tr("30 daq", "30 min")
        case .h1: return tr("1 soat", "1 h")
        case .h3: return tr("3 soat", "3 h")
        }
    }
    var seconds: TimeInterval { TimeInterval(rawValue) }
}

private enum L {
    static let labelW: CGFloat = 190
    static let mainH: CGFloat = 30
    static let helperH: CGFloat = 20
    static let rulerH: CGFloat = 22
}

/// Bitta chiziq (agent) va undagi qadamlar
private struct Lane: Identifiable {
    let id: String
    let session: SessionSnap
    let agent: AgentSnap
    let steps: [StepSnap]
}

struct LiveLanes: View {
    let snap: Snapshot
    let window: LaneWindow
    let open: (SessionSnap) -> Void

    @State private var hover: (lane: String, step: StepSnap, x: CGFloat)?

    var body: some View {
        let now = snap.updatedAt
        let start = now.addingTimeInterval(-window.seconds)
        let groups = Self.sessions(snap, since: start)
        let other = Self.merged((snap.outside?.segments ?? []).filter { $0.end > start })
        if groups.isEmpty && other.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(symbol: "chart.bar.xaxis", title: tr("Bu oraliqda harakat yo'q", "No activity in this range"),
                               text: tr("Vaqt oralig'ini kattalashtiring yoki agentlar ishga tushishini kuting.", "Widen the time range or wait for agents to start."))
                Spacer()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ruler(start: start, now: now)
                    if !other.isEmpty { otherRow(other, start: start, now: now) }
                    ForEach(groups, id: \.id) { s in
                        group(s, start: start, now: now)
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
    }

    /// Oraliqda harakat qilgan sessiyalar: ruxsat kutayotgani va ishlayotgani tepada
    static func sessions(_ snap: Snapshot, since start: Date) -> [SessionSnap] {
        func rank(_ s: SessionSnap) -> Int { snap.permissionWaits[s.id] != nil ? 2 : (s.state != .idle ? 1 : 0) }
        return snap.sessions
            .filter { rank($0) > 0 || ($0.lastActivity ?? .distantPast) >= start }
            .sorted { (rank($0), $0.lastActivity ?? .distantPast) > (rank($1), $1.lastActivity ?? .distantPast) }
            .prefix(8).map { $0 }
    }

    // MARK: Vaqt o'qi

    private func ruler(start: Date, now: Date) -> some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: L.labelW)
            GeometryReader { geo in
                let w = geo.size.width
                let n = 6
                ZStack(alignment: .topLeading) {
                    ForEach(0...n, id: \.self) { i in
                        let t = start.addingTimeInterval(window.seconds * Double(i) / Double(n))
                        Text(i == n ? tr("hozir", "now") : Fmt.hourMinute.string(from: t))
                            .font(.caption2.weight(i == n ? .semibold : .regular)).monospacedDigit()
                            .foregroundStyle(i == n ? Brand.ok : Color.secondary)
                            .fixedSize()
                            .position(x: min(w - 14, max(14, w * CGFloat(i) / CGFloat(n))), y: L.rulerH / 2)
                    }
                }
            }
            .frame(height: L.rulerH)
        }
        .padding(.bottom, 6)
    }

    // MARK: Chat va boshqa joylar

    /// Yonma-yon bo'laklar bittaga (har o'sish — alohida qayd, 1–2 daqiqalik; chiziqda o'qib bo'lmaydi)
    static func merged(_ segs: [OutsideUsage.Segment], gap: TimeInterval = 5 * 60) -> [OutsideUsage.Segment] {
        var out: [OutsideUsage.Segment] = []
        for s in segs {
            if let l = out.last, s.start.timeIntervalSince(l.end) <= gap {
                out[out.count - 1] = .init(start: l.start, end: max(l.end, s.end), percent: l.percent + s.percent)
            } else {
                out.append(s)
            }
        }
        return out
    }

    /// Shu Mac'dan tashqaridagi sarf: suhbat ko'rinmaydi, faqat qaysi 15 daqiqalarda limit qancha o'sgani
    private func otherRow(_ segs: [OutsideUsage.Segment], start: Date, now: Date) -> some View {
        let active = snap.outside?.isActive(now: now) ?? false
        return HStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Palette.agents))
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("Chat va boshqa joylar", "Chat & elsewhere")).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text(active ? tr("faol · limitdan taxmin", "active · estimated from limit") : tr("limitdan taxmin", "estimated from limit"))
                        .font(.caption2.weight(.semibold)).foregroundStyle(active ? Brand.ok : .secondary)
                }
            }
            .padding(.trailing, 10)
            .frame(width: L.labelW, alignment: .leading)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height, span = window.seconds
                let x: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(start) / span) * w }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6).fill(Brand.surface.opacity(0.7))
                    ForEach(segs, id: \.start) { sg in
                        let a = max(0, x(sg.start)), b = min(w, x(sg.end))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Palette.agents.opacity(0.35))
                            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(Palette.agents.opacity(0.8), lineWidth: 1))
                            .overlay {
                                if b - a > 28 {
                                    Text("~\(Int(sg.percent.rounded()))%").font(.system(size: 10, weight: .bold)).foregroundStyle(Palette.agents)
                                }
                            }
                            .frame(width: max(3, b - a), height: h - 10)
                            .position(x: (a + b) / 2, y: h / 2)
                            .help(tr("\(Fmt.hourMinute.string(from: sg.start))–\(Fmt.hourMinute.string(from: sg.end)): 5 soatlik limitdan ~\(Int(sg.percent.rounded()))%", "\(Fmt.hourMinute.string(from: sg.start))–\(Fmt.hourMinute.string(from: sg.end)): ~\(Int(sg.percent.rounded()))% of the 5-hour limit"))
                    }
                }
            }
            .frame(height: L.mainH)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
        .help(tr("Claude desktop Chat, claude.ai yoki boshqa qurilma — suhbat ichi ko'rinmaydi, limit o'zgarishidan taxmin", "Claude desktop Chat, claude.ai or another device — conversation content isn't visible, estimated from limit changes"))
    }

    // MARK: Sessiya guruhi

    private func group(_ s: SessionSnap, start: Date, now: Date) -> some View {
        let waiting = snap.permissionWaits[s.id] != nil
        let running = s.state != .idle
        let color: Color = waiting ? Brand.warn : (running ? Brand.ok : .secondary)
        let lanes = s.agents
            .sorted { ($0.isMain ? 1 : 0, $0.lastActivity ?? .distantPast) > ($1.isMain ? 1 : 0, $1.lastActivity ?? .distantPast) }
            .map { a in Lane(id: "\(s.id)/\(a.id)", session: s, agent: a, steps: a.steps.filter { end($0, now) >= start }) }
            .filter { $0.agent.isMain || !$0.steps.isEmpty }
        let turns = s.turns.filter { $0.start >= start }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(lanes) { lane in
                HStack(spacing: 0) {
                    label(lane, color: color, waiting: waiting, running: running)
                        .frame(width: L.labelW, alignment: .leading)
                    track(lane, turns: lane.agent.isMain ? turns : [], start: start, now: now, live: running)
                        .frame(height: lane.agent.isMain ? L.mainH : L.helperH)
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Brand.line).frame(height: 1) }
        .contentShape(Rectangle())
        .onTapGesture { open(s) }
        .help(tr("Bosing — \(s.project) xaritasini ochish", "Click to open the \(s.project) map"))
    }

    @ViewBuilder
    private func label(_ lane: Lane, color: Color, waiting: Bool, running: Bool) -> some View {
        if lane.agent.isMain {
            HStack(spacing: 8) {
                ProjectAvatar(name: lane.session.project, size: 22)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(lane.session.project).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                        if let n = lane.session.turns.last?.id {
                            Text("#\(n)").font(.caption2.weight(.semibold)).monospacedDigit().foregroundStyle(.tertiary)
                        }
                    }
                    HStack(spacing: 4) {
                        if running && !waiting { StateDot(state: .running, size: 5) }
                        else { Circle().fill(color).frame(width: 5, height: 5) }
                        Text(waiting ? tr("ruxsat kutyapti", "waiting for permission") : (running ? tr("ishlayapti", "working") : Fmt.ago(lane.session.lastActivity, now: snap.updatedAt)))
                    }
                    .font(.caption2.weight(.semibold)).foregroundStyle(color)
                }
            }
            .padding(.trailing, 10)
            // Bir loyihada bir nechta sessiya bo'lishi mumkin — oxirgi so'rov matni farqlaydi
            .help(lane.session.turns.last?.prompt ?? lane.session.title)
        } else {
            HStack(spacing: 5) {
                Image(systemName: "arrow.turn.down.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                StateDot(state: lane.agent.state, size: 5)
                Text(lane.agent.title).font(.caption2.weight(.semibold)).foregroundStyle(Palette.agents).lineLimit(1)
            }
            .padding(.leading, 14).padding(.trailing, 10)
        }
    }

    // MARK: Chiziq

    private func end(_ st: StepSnap, _ now: Date) -> Date {
        if st.status == .running { return now }
        return st.date.addingTimeInterval(max(st.duration ?? 1, 0.5))
    }

    private func track(_ lane: Lane, turns: [TurnSnap], start: Date, now: Date, live: Bool) -> some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let span = window.seconds
            let x: (Date) -> CGFloat = { CGFloat($0.timeIntervalSince(start) / span) * w }
            ZStack(alignment: .topLeading) {
                Canvas { g, _ in
                    g.fill(Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h), cornerRadius: 6),
                           with: .color(Brand.surface.opacity(lane.agent.isMain ? 0.7 : 0.4)))
                    // So'rov boshlangan joylar
                    for t in turns {
                        let tx = x(t.start)
                        g.fill(Path(CGRect(x: tx, y: 0, width: 1.5, height: h)), with: .color(Brand.accent.opacity(0.8)))
                    }
                    let inset: CGFloat = lane.agent.isMain ? 7 : 5
                    for st in lane.steps {
                        let a = max(0, x(st.date)), b = min(w, x(end(st, now)))
                        guard b >= 0, a <= w else { continue }
                        let r = CGRect(x: a, y: inset, width: max(3, b - a), height: h - inset * 2)
                        let c = st.status == .failed ? Brand.err : st.category.color
                        g.fill(Path(roundedRect: r, cornerRadius: 2), with: .color(c.opacity(st.status == .running ? 1 : 0.85)))
                        if st.status == .running {
                            g.stroke(Path(roundedRect: r.insetBy(dx: -1.5, dy: -1.5), cornerRadius: 3), with: .color(c.opacity(0.5)), lineWidth: 1)
                        }
                    }
                    // «Hozir» chizig'i
                    if live {
                        g.stroke(Path { p in p.move(to: CGPoint(x: w - 1, y: 0)); p.addLine(to: CGPoint(x: w - 1, y: h)) },
                                 with: .color(Brand.ok.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
                    }
                }
                // Yaqin so'rov raqamlari ustma-ust tushmasin — oldingisidan kamida 28 pt keyin
                let labeled = turns.reduce(into: [TurnSnap]()) { acc, t in
                    if let p = acc.last, x(t.start) - x(p.start) < 28 { return }
                    acc.append(t)
                }
                ForEach(labeled, id: \.id) { t in
                    Text("#\(t.id)").font(.system(size: 9, weight: .bold)).foregroundStyle(Brand.accent)
                        .padding(.horizontal, 3).background(Brand.canvas.opacity(0.8), in: Capsule())
                        .fixedSize()
                        .position(x: min(w - 12, x(t.start) + 12), y: -5)
                        .help(t.prompt)
                }
                if let hv = hover, hv.lane == lane.id {
                    tooltip(hv.step, agent: lane.agent, now: now)
                        .fixedSize()
                        .position(x: min(w - 130, max(130, hv.x)), y: h + 18)
                        .allowsHitTesting(false)
                        .zIndex(1)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let p):
                    let t = start.addingTimeInterval(Double(p.x / max(w, 1)) * span)
                    let tol = span * 6 / Double(max(w, 1))
                    if let st = lane.steps.min(by: { dist($0, t, now) < dist($1, t, now) }), dist(st, t, now) <= tol {
                        hover = (lane.id, st, p.x)
                    } else if hover?.lane == lane.id { hover = nil }
                case .ended:
                    if hover?.lane == lane.id { hover = nil }
                }
            }
        }
        .zIndex(hover?.lane == lane.id ? 1 : 0)
    }

    /// Vaqt nuqtasidan qadamgacha masofa (qadam ichida bo'lsa — 0)
    private func dist(_ st: StepSnap, _ t: Date, _ now: Date) -> TimeInterval {
        let a = st.date, b = end(st, now)
        if t < a { return a.timeIntervalSince(t) }
        if t > b { return t.timeIntervalSince(b) }
        return 0
    }

    private func tooltip(_ st: StepSnap, agent: AgentSnap, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: st.symbol).foregroundStyle(st.status == .failed ? Brand.err : st.category.iconColor)
                Text(st.text).lineLimit(1)
            }
            .font(.caption.weight(.semibold))
            Text("\(agent.isMain ? tr("Asosiy agent", "Main agent") : agent.title) · \(Fmt.clock.string(from: st.date))"
                 + (st.status == .running ? tr(" · ishlayapti", " · working") : st.duration.map { " · \(Alerts.duration($0))" } ?? ""))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: 260, alignment: .leading)
        .surface(radius: 8)
    }
}
