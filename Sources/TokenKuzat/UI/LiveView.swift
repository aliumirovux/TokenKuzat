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
                    .init(id: "cards", title: "Kartalar", symbol: "rectangle.grid.2x2"),
                    .init(id: "lanes", title: "Chiziqlar", symbol: "chart.bar.xaxis"),
                ])
                if style == "lanes" {
                    PillSegments(selection: $window, items: LaneWindow.allCases.map { .init(id: $0, title: $0.title) },
                                 compact: true)
                        .help("Ko'rinadigan vaqt oralig'i")
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
        if shown.isEmpty {
            VStack {
                Spacer()
                EmptyStateView(symbol: "square.grid.2x2", title: "Hozir hech qaysi agent ishlamayapti",
                               text: "Claude Code sessiyalari ishga tushsa — har biri shu yerda alohida kartada jonli ko'rinadi.")
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14, alignment: .top)], spacing: 14) {
                    ForEach(shown, id: \.id) { s in
                        LiveCard(session: s, waiting: snap.permissionWaits[s.id], now: snap.updatedAt) { open(s) }
                    }
                }
                .padding(.horizontal, 24).padding(.bottom, 24)
            }
        }
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
                Divider()
                footer(turn: turn)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .surface(radius: 16, tint: waiting != nil ? Brand.warn : nil,
                     interactive: true, stroke: waiting != nil ? Brand.warn.opacity(0.6) : nil)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .help("Bosing — \(session.project) xaritasini ochish")
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
        if waiting != nil { return "Ruxsat kutyapti" }
        if running { return "Ishlayapti · \(Fmt.model(session.model))" }
        return "Tugadi · \(Fmt.ago(session.lastActivity, now: now))"
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

/// Zamonaviy segment tanlagich: yumaloq trek ichida tanlangan bo'lak — urg'u rangidagi pill, bosganda siljib o'tadi
struct PillSegments<ID: Hashable>: View {
    struct Item: Identifiable {
        let id: ID
        let title: String
        var symbol: String? = nil
    }

    @Binding var selection: ID
    let items: [Item]
    /// Ixcham: kichikroq shrift va oraliq (ikkinchi darajali tanlagichlar uchun)
    var compact = false
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let on = item.id == selection
                Button {
                    withAnimation(Motion.spring) { selection = item.id }
                } label: {
                    HStack(spacing: 6) {
                        if let s = item.symbol { Image(systemName: s).font(.system(size: compact ? 10.5 : 11.5, weight: .semibold)) }
                        Text(item.title)
                    }
                    .font(.system(size: compact ? 12 : 13, weight: on ? .semibold : .medium))
                    .foregroundStyle(on ? Brand.accent : Color.secondary)
                    .padding(.horizontal, compact ? 10 : 12).frame(height: compact ? 26 : 30)
                    .background {
                        if on {
                            RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                                .fill(Brand.accent.opacity(0.18))
                                .overlay(RoundedRectangle(cornerRadius: compact ? 7 : 8, style: .continuous)
                                    .stroke(Brand.accent.opacity(0.35), lineWidth: 1))
                                .matchedGeometryEffect(id: "pill", in: pill)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .noFocusRing()
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: compact ? 10 : 11, style: .continuous).fill(Brand.surface.opacity(0.7)))
        .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 11, style: .continuous).stroke(Brand.line))
        .fixedSize()
    }
}
