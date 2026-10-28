import SwiftUI
import TokenKuzatCore

struct OverviewView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(Pref.budgetEnabled) private var budgetEnabled = false

    var body: some View {
        let s = store.snap
        ScrollView {
            if !s.initialScanDone {
                ProgressView("Yozuvlar o'qilmoqda…").padding(80)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    // Eng muhimi tepada: hozir nima bo'lyapti va limit qancha qoldi
                    HStack(alignment: .top, spacing: 18) {
                        NowCard(snap: s, mode: mode).frame(maxWidth: .infinity)
                        if let l = s.limits, !l.isEmpty {
                            LimitRingsCard(limits: l, forecast: s.fiveHourForecast).frame(width: 340)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    if s.limits.map({ $0.isEmpty }) ?? true, !StatusLine.isInstalled {
                        ConnectLimitsHint().card()
                    }
                    metrics(s)
                    if budgetEnabled, let b = BudgetStatus.current(s) {
                        BudgetBar(status: b).card()
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: "Oxirgi 60 daqiqa", subtitle: "token / daqiqa")
                        MinuteChart(points: s.minutes, mode: mode, height: 170)
                    }
                    .card()

                    HStack(alignment: .top, spacing: 18) {
                        composition(s).frame(maxWidth: .infinity)
                        week(s).frame(maxWidth: .infinity)
                    }

                    recentSessions(s)
                    recentFeed(s)
                }
                .padding(20)
            }
        }
    }

    private func metrics(_ s: Snapshot) -> some View {
        let yesterday = s.days.dropLast().last?.tokens.value(mode) ?? 0
        let today = s.today.value(mode)
        let delta: String? = yesterday > 0 ? "Kecha: \(Fmt.tokens(yesterday)) · \(today >= yesterday ? "+" : "−")\(Fmt.percent(abs(today - yesterday), of: yesterday))" : nil
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
            MetricTile(title: "Bugun jami", value: Fmt.tokens(today), unit: "token",
                       footnote: delta ?? "Kecha ma'lumot yo'q", symbol: "sun.max.fill", tint: .orange)
            MetricTile(title: "Oxirgi 5 soat", value: Fmt.tokens(s.lastFiveHours.value(mode)), unit: "token",
                       footnote: "Obuna limiti shu oyna bo'yicha", symbol: "clock.fill", tint: .blue)
            MetricTile(title: "Hozirgi tezlik", value: Fmt.tokens(s.rate(mode)), unit: "/daq",
                       footnote: "Oxirgi 5 daqiqa o'rtachasi", symbol: "speedometer", tint: .green)
            MetricTile(title: "Faol sessiyalar", value: "\(s.activeSessions)",
                       footnote: "\(s.runningAgents) agent ishlayapti", symbol: "person.2.fill", tint: Palette.agents)
        }
    }

    private func composition(_ s: Snapshot) -> some View {
        let slices = Composition.slices(s.today, mode)
        let total = s.today.value(mode)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bugungi tarkib", subtitle: "tokenlar nimaga ketdi")
            BreakdownBar(slices: slices, height: 12)
            BreakdownLegend(slices: slices, total: total)
        }
        .card()
    }

    private func week(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Oxirgi 7 kun", trailing: AnyView(
                Button("Tarix") { WindowManager.shared.show(.history) }.buttonStyle(.link).font(.caption)))
            DailyChart(days: Array(s.days.suffix(7)), mode: mode, height: 150, selected: .constant(nil))
        }
        .card()
    }

    @ViewBuilder
    private func recentSessions(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "So'nggi sessiyalar", trailing: AnyView(
                Button("Hammasi") { WindowManager.shared.show(.sessions) }.buttonStyle(.link).font(.caption)))
            if s.sessions.isEmpty {
                EmptyStateView(symbol: "moon.zzz", title: "Oxirgi 7 kunda sessiya yo'q",
                               text: "Mac'dagi Claude Code yoki Cowork'da ish boshlansa, agentlar va tokenlar shu yerda jonli chiqadi.")
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(s.sessions.prefix(5).enumerated()), id: \.element.id) { i, sess in
                        if i > 0 { Divider().padding(.leading, 40) }
                        SessionRow(session: sess, mode: mode)
                    }
                }
                .card(padding: 6)
            }
        }
    }

    @ViewBuilder
    private func recentFeed(_ s: Snapshot) -> some View {
        if !s.feed.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(title: "So'nggi harakatlar", trailing: AnyView(
                    Button("Jonli lenta") { WindowManager.shared.show(.activity) }.buttonStyle(.link).font(.caption)))
                VStack(spacing: 8) {
                    ForEach(s.feed.prefix(8)) { FeedRow(event: $0) }
                }
                .card()
            }
        }
    }
}

/// Ro'yxatdagi bir qatorli sessiya; bosilsa sxemada ochiladi
struct SessionRow: View {
    let session: SessionSnap
    let mode: CountMode

    var body: some View {
        Button {
            UserDefaults.standard.set(session.id, forKey: GraphScreen.selectedSessionKey)
            WindowManager.shared.show(.graph)
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: "folder.fill", tint: session.state == .idle ? .secondary : Palette.state(session.state), size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(session.project).font(.callout.weight(.semibold)).lineLimit(1)
                        StateDot(state: session.state, size: 6)
                    }
                    Text(session.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                if !session.model.isEmpty { Chip(text: session.model) }
                if session.helperCount > 0 { Chip(text: "\(session.helperCount)", symbol: "person.2") }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Fmt.tokens(session.tokens.value(mode))).font(.callout.weight(.semibold)).monospacedDigit()
                    Text(Fmt.ago(session.lastActivity)).font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(minWidth: 70, alignment: .trailing)
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }
}

// MARK: - «Hozir» kartasi

/// Bir qarashda: qaysi loyihada, qaysi agent, nima qilyapti va qancha vaqtdan beri
struct NowCard: View {
    let snap: Snapshot
    let mode: CountMode

    var body: some View {
        let active = snap.sessions.filter { $0.state != .idle }
        Group {
            if let sess = active.first {
                live(sess, others: active.count - 1)
            } else {
                idle
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 18, highlight: active.isEmpty ? nil : .green)
        .frame(maxHeight: .infinity)
        .animation(Motion.spring, value: active.first?.id)
    }

    private func live(_ sess: SessionSnap, others: Int) -> some View {
        let steps = sess.agents.flatMap(\.steps)
        let running = steps.filter { $0.status == .running }.max { $0.date < $1.date }
        let turn = sess.turns.last
        return Button {
            UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
            WindowManager.shared.show(.graph)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                LiveOrb(color: running?.category.color ?? .green)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("HOZIR").font(.caption2.weight(.bold)).foregroundStyle(.green).tracking(1.2)
                        Text(sess.project).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        if others > 0 { Chip(text: "+\(others) sessiya") }
                    }
                    Text(running?.text ?? sess.main?.lastAction ?? "Ishlayapti…")
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .lineLimit(2)
                        .contentTransition(.opacity)
                        .animation(Motion.smooth, value: running?.id)
                    HStack(spacing: 12) {
                        if let d = running?.duration {
                            Label(Alerts.duration(d), systemImage: "timer").monospacedDigit()
                        }
                        if let turn {
                            Label("#\(turn.id) · \(turn.steps) qadam", systemImage: "list.bullet")
                            Label(Fmt.tokens(turn.tokens.value(mode)), systemImage: "bolt.fill")
                        }
                        let helpers = sess.agents.filter { !$0.isMain && $0.state == .running }.count
                        if helpers > 0 { Label("\(helpers) yordamchi", systemImage: "person.2.fill") }
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    if let turn {
                        Text("So'rov: \(turn.prompt)").font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Agentlar sxemasida ochish")
    }

    private var idle: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 26)).foregroundStyle(.indigo)
                .frame(width: 56, height: 56)
                .glassCircle(tint: .indigo)
            VStack(alignment: .leading, spacing: 6) {
                Text("HOZIR").font(.caption2.weight(.bold)).foregroundStyle(.secondary).tracking(1.2)
                Text("Hammasi tinch").font(.system(.title3, design: .rounded).weight(.semibold))
                if let last = snap.sessions.first {
                    Text("Oxirgi ish: \(last.project) · \(Fmt.ago(last.lastActivity))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(last.title).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                } else {
                    Text("Claude Code'da ish boshlansa, shu yerda jonli ko'rinadi.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Jonli ish belgisi: yumshoq nafas oluvchi shar
private struct LiveOrb: View {
    let color: Color
    @State private var breathe = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.18)).scaleEffect(breathe ? 1.25 : 0.95).blur(radius: 6)
            Circle().fill(RadialGradient(colors: [color.opacity(0.95), color.opacity(0.45)], center: .topLeading,
                                         startRadius: 2, endRadius: 40))
                .frame(width: 36, height: 36)
                .shadow(color: color.opacity(0.55), radius: breathe ? 14 : 6)
            Image(systemName: "waveform").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                .symbolEffectIfAvailable()
        }
        .frame(width: 56, height: 56)
        .animation(Motion.spring, value: color)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}

private extension View {
    @ViewBuilder
    func symbolEffectIfAvailable() -> some View {
        if #available(macOS 14.0, *) { self.symbolEffect(.variableColor.iterative, options: .repeating) } else { self }
    }
}

// MARK: - Limit halqalari

struct LimitRingsCard: View {
    let limits: RateLimits
    let forecast: LimitForecast.Outcome

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Claude limiti").font(.system(.headline, design: .rounded))
                Spacer()
                Text(Fmt.ago(limits.updatedAt)).font(.caption2).foregroundStyle(.tertiary)
            }
            HStack(spacing: 18) {
                if let w = limits.fiveHour {
                    RingGauge(fraction: w.usedPercentage / 100, title: "5 soat", value: "\(Int(w.usedPercentage.rounded()))%",
                              caption: "↻ \(Fmt.hourMinute.string(from: w.resetsAt)) · \(Alerts.duration(max(0, w.resetsAt.timeIntervalSinceNow)))")
                }
                if let w = limits.sevenDay {
                    RingGauge(fraction: w.usedPercentage / 100, title: "hafta", value: "\(Int(w.usedPercentage.rounded()))%",
                              caption: "↻ \(Fmt.shortDay.string(from: w.resetsAt)) \(Fmt.hourMinute.string(from: w.resetsAt))")
                }
            }
            .frame(maxWidth: .infinity)
            switch forecast {
            case .runsOut(let at):
                Label("Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
            case .lasts:
                Label("Shu tezlikda tiklanguncha yetadi", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            case .unknown:
                EmptyView()
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .card(padding: 16)
        .frame(maxHeight: .infinity)
    }
}
