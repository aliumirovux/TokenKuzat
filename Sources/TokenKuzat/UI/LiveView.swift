import SwiftUI
import TokenKuzatCore

/// «Jonli» — bir vaqtda ishlayotgan barcha sessiyalar yonma-yon kartalarda.
/// Ruxsat kutayotgani birinchi, keyin ishlayotganlari, oxirida yaqinda tugaganlari (10 daqiqa ichida).
/// Kartani bosish — o'sha sessiyaning to'liq xaritasi
struct LiveView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.section) private var section = Section.overview
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""

    /// «cards» — kartalar, «lanes» — umumiy vaqt o'qidagi parallel chiziqlar
    @AppStorage("live.style") private var style = "cards"
    @AppStorage("live.window") private var window = LaneWindow.m30

    /// Tugagan sessiya shuncha vaqt kartada qoladi
    static let keepFinished: TimeInterval = 10 * 60

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                PillSegments(selection: $style, items: [
                    .init(id: "cards", title: tr("Kartalar", "Cards"), symbol: "rectangle.grid.2x2"),
                    .init(id: "lanes", title: tr("Chiziqlar", "Lanes"), symbol: "chart.bar.xaxis"),
                ])
                if style == "lanes" {
                    PillSegments(selection: $window, items: LaneWindow.allCases.map { .init(id: $0, title: $0.title) },
                                 compact: true)
                        .help(tr("Ko'rinadigan vaqt oralig'i", "Visible time range"))
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                }
                Spacer()
            }
            .animation(Motion.spring, value: style)
            .padding(.horizontal, 24).padding(.bottom, 14)

            if style == "lanes" {
                LiveLanes(snap: store.snap, window: window) { open($0) }
            } else {
                cards
            }
        }
    }

    private func open(_ s: SessionSnap) {
        sessionId = s.id
        withAnimation(Motion.snappy) { section = .graph }
    }

    @ViewBuilder
    private var cards: some View {
        let snap = store.snap
        let shown = Self.sessions(snap)
        let other = snap.outside.flatMap { o in Self.showOther(o, now: snap.updatedAt) ? o : nil }
        if shown.isEmpty && other == nil {
            VStack {
                Spacer()
                EmptyStateView(symbol: "square.grid.2x2", title: tr("Hozir hech qaysi agent ishlamayapti", "No agents are working right now"),
                               text: tr("Claude Code sessiyalari ishga tushsa — har biri shu yerda alohida kartada jonli ko'rinadi.", "When Claude Code sessions start, each one shows up live here on its own card."))
                Spacer()
            }
        } else {
            let items: [LiveItem] = (other.map { [.other($0)] } ?? []) + shown.map { .session($0) }
            GeometryReader { geo in
                let cols = max(1, Int((geo.size.width - 48 + Self.gap) / (Self.minCard + Self.gap)))
                let rows = stride(from: 0, to: items.count, by: cols).map { Array(items[$0..<min($0 + cols, items.count)]) }
                ScrollView {
                    // Qatordagi kartalar bir xil balandlikda, pastki qatori (kontekst) bir chiziqda
                    VStack(spacing: Self.gap) {
                        ForEach(rows.indices, id: \.self) { r in
                            HStack(alignment: .top, spacing: Self.gap) {
                                ForEach(rows[r]) { card($0, snap: snap) }
                                ForEach(0..<(cols - rows[r].count), id: \.self) { _ in
                                    Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                                }
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }
            }
        }
    }

    private static let minCard: CGFloat = 300
    private static let gap: CGFloat = 14

    private enum LiveItem: Identifiable {
        case other(OutsideUsage)
        case session(SessionSnap)
        var id: String {
            switch self {
            case .other: return "outside"
            case .session(let s): return s.id
            }
        }
    }

    @ViewBuilder
    private func card(_ item: LiveItem, snap: Snapshot) -> some View {
        switch item {
        case .other(let o):
            OutsideUsageCard(usage: o, now: snap.updatedAt)
        case .session(let s):
            LiveCard(session: s, waiting: snap.permissionWaits[s.id], now: snap.updatedAt) { open(s) }
        }
    }

    /// Boshqa joydagi sarf kartasi: oxirgi bir soat ichida bo'lgan bo'lsa
    static func showOther(_ o: OutsideUsage, now: Date) -> Bool {
        o.lastActivity.map { now.timeIntervalSince($0) < 3600 } ?? false
    }

    /// Kartadagi sessiyalar tartibi: ruxsat kutyapti → ishlayapti → yaqinda tugagan
    static func sessions(_ snap: Snapshot) -> [SessionSnap] {
        let now = snap.updatedAt
        func rank(_ s: SessionSnap) -> Int {
            if snap.permissionWaits[s.id] != nil { return 2 }
            return s.state != .idle ? 1 : 0
        }
        return snap.sessions
            .filter { rank($0) > 0 || ($0.lastActivity.map { now.timeIntervalSince($0) < keepFinished } ?? false) }
            .sorted { (rank($0), $0.lastActivity ?? .distantPast) > (rank($1), $1.lastActivity ?? .distantPast) }
            .prefix(6).map { $0 }
    }
}

/// Bitta sessiya kartasi: holat, joriy so'rov, hozirgi ish, oxirgi qadamlar, yordamchi agentlar, kontekst
private struct LiveCard: View {
    let session: SessionSnap
    let waiting: HookNotice?
    let now: Date
    let open: () -> Void

    var body: some View {
        let running = session.state != .idle
        let color: Color = waiting != nil ? Brand.warn : (running ? Brand.ok : .secondary)
        let turn = session.turns.last
        Button(action: open) {
            VStack(alignment: .leading, spacing: 12) {
                header(color: color, running: running)
                if let turn {
                    Text(turn.prompt)
                        .font(.callout).foregroundStyle(.secondary).lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                current(running: running)
                steps
                helpers
                Spacer(minLength: 0)
                Divider()
                footer(turn: turn)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .surface(radius: 16, tint: waiting != nil ? Brand.warn : nil,
                     interactive: true, stroke: waiting != nil ? Brand.warn.opacity(0.6) : nil)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .help(tr("Bosing — \(session.project) xaritasini ochish", "Click to open the \(session.project) map"))
    }

    private func header(color: Color, running: Bool) -> some View {
        HStack(spacing: 10) {
            ProjectAvatar(name: session.project, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.project).font(.system(size: 15, weight: .semibold, design: .rounded)).lineLimit(1)
                HStack(spacing: 5) {
                    if waiting == nil && running { StateDot(state: .running, size: 6) }
                    else { Circle().fill(color).frame(width: 6, height: 6) }
                    Text(status(running: running))
                }
                .font(.caption.weight(.semibold)).foregroundStyle(color)
            }
            Spacer(minLength: 6)
            RobotView(action: RobotView.action(for: session, waiting: waiting != nil, now: now), size: 30)
                .frame(width: 64, height: 58, alignment: .bottom)
                .padding(.top, -14)
        }
    }

    private func status(running: Bool) -> String {
        if waiting != nil { return tr("Ruxsat kutyapti", "Waiting for permission") }
        if running { return tr("Ishlayapti · \(Fmt.model(session.model))", "Working · \(Fmt.model(session.model))") }
        return tr("Tugadi · \(Fmt.ago(session.lastActivity, now: now))", "Done · \(Fmt.ago(session.lastActivity, now: now))")
    }

    /// Asosiy agent hozir nima qilyapti
    @ViewBuilder
    private func current(running: Bool) -> some View {
        if running || waiting != nil, let action = session.main?.lastAction, !action.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill").font(.caption).foregroundStyle(Brand.accent)
                Text(action).font(.callout.weight(.medium)).lineLimit(1)
            }
            .padding(.horizontal, 10).frame(height: 30)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.accent.opacity(0.12)))
        }
    }

    /// Barcha agentlarning oxirgi 4 qadami, yangisi tepada
    private var steps: some View {
        let recent = session.agents
            .flatMap { a in a.steps.map { (step: $0, agent: a.isMain ? nil : a.title) } }
            .sorted { $0.step.date > $1.step.date }
            .prefix(4)
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(recent), id: \.step.id) { item in
                let st = item.step
                HStack(spacing: 8) {
                    Image(systemName: st.symbol)
                        .font(.caption).frame(width: 16)
                        .foregroundStyle(st.status == .failed ? Brand.err : st.category.color)
                    Text(st.text).font(.caption).lineLimit(1)
                    if let a = item.agent {
                        Text(a).font(.caption2.weight(.semibold)).foregroundStyle(Palette.agents).lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if st.status == .running {
                        StateDot(state: .running, size: 5)
                    } else {
                        Text(Fmt.ago(st.date, now: now)).font(.caption2).monospacedDigit().foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    /// Yordamchi agentlar (ishlayotgani birinchi)
    @ViewBuilder
    private var helpers: some View {
        let list = session.agents.filter { !$0.isMain }
            .sorted { ($0.state, $0.lastActivity ?? .distantPast) > ($1.state, $1.lastActivity ?? .distantPast) }
        if !list.isEmpty {
            FlowRow(spacing: 6, lineSpacing: 6) {
                ForEach(list.prefix(4), id: \.id) { a in
                    HStack(spacing: 5) {
                        StateDot(state: a.state, size: 5)
                        Text(a.title).lineLimit(1)
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(a.state != .idle ? Color.primary : Color.secondary)
                    .padding(.horizontal, 8).frame(height: 22)
                    .surfaceCapsule()
                    .help("\(a.subtitle) · \(a.lastAction)")
                }
                if list.count > 4 {
                    Text("+\(list.count - 4)").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).frame(height: 22).surfaceCapsule()
                }
            }
        }
    }

    private func footer(turn: TurnSnap?) -> some View {
        HStack(spacing: 14) {
            ContextGauge(session: session)
            Spacer(minLength: 6)
            if let turn {
                Label(Alerts.duration(turn.end.timeIntervalSince(turn.start)), systemImage: "clock")
                Label(Fmt.tokens(Double(turn.tokens.total)), systemImage: "circle.hexagongrid")
            }
        }
        .font(.caption).foregroundStyle(.secondary).labelStyle(.titleAndIcon)
    }
}

/// Chat va boshqa joylar: Claude desktop Chat, claude.ai, telefon yoki boshqa kompyuter.
/// Suhbat ichi ko'rinmaydi — faqat limit foizi qancha o'sgani (shu Mac'dagi sarf ayirilgan)
private struct OutsideUsageCard: View {
    let usage: OutsideUsage
    let now: Date

    var body: some View {
        let active = usage.isActive(now: now)
        let color: Color = active ? Brand.ok : .secondary
        let recent = usage.percent(within: 30 * 60, now: now)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Palette.agents))
                VStack(alignment: .leading, spacing: 2) {
                    Text(tr("Chat va boshqa joylar", "Chat & elsewhere")).font(.system(size: 15, weight: .semibold, design: .rounded)).lineLimit(1)
                    HStack(spacing: 5) {
                        if active { StateDot(state: .running, size: 6) } else { Circle().fill(color).frame(width: 6, height: 6) }
                        Text(active ? tr("Faol", "Active") : tr("Tinch · \(Fmt.ago(usage.lastActivity, now: now))", "Idle · \(Fmt.ago(usage.lastActivity, now: now))"))
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(color)
                }
                Spacer(minLength: 0)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("~\(Int(recent.rounded()))%").font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(tr("so'nggi 30 daqiqada 5 soatlik limitdan", "of the 5-hour limit in the last 30 min")).font(.callout).foregroundStyle(.secondary)
            }
            bars
            Spacer(minLength: 0)
            Divider()
            Text(tr("Claude desktop Chat, claude.ai yoki boshqa qurilma. Suhbat ichi ko'rinmaydi — limit o'zgarishidan taxmin (bir necha daqiqa kechikishi mumkin).", "Claude desktop Chat, claude.ai or another device. Conversation content isn't visible — estimated from limit changes (may lag a few minutes)."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .surface(radius: 16)
        .help(tr("Limit o'sgan, lekin shu Mac'dagi Claude Code sessiyalari buni tushuntirmagan qismi", "Limit growth not explained by Claude Code sessions on this Mac"))
    }

    /// Oxirgi 2 soat, 15 daqiqalik ustunlar
    private var bars: some View {
        let slots = 8, slot: TimeInterval = 15 * 60
        let values = (0..<slots).map { i -> Double in
            let end = now.addingTimeInterval(-Double(slots - 1 - i) * slot)
            return usage.percent(within: slot, now: end)
        }
        let top = max(values.max() ?? 0, 3)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(v > 0 ? Palette.agents : Brand.line)
                        .frame(height: max(3, 34 * v / top))
                        .frame(maxWidth: .infinity)
                        .help(v > 0 ? "~\(Int(v.rounded()))%" : "")
                }
            }
            .frame(height: 34, alignment: .bottom)
            HStack {
                Text(tr("2 soat oldin", "2 h ago")); Spacer(); Text(tr("hozir", "now"))
            }
            .font(.caption2).foregroundStyle(.tertiary)
        }
    }
}
