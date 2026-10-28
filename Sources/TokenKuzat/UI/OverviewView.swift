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
                    metrics(s)
                    if let l = s.limits, !l.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "Claude limiti", subtitle: "Claude Code'ning o'zidan · \(Fmt.ago(l.updatedAt))")
                            RealLimitsView(limits: l, forecast: s.fiveHourForecast)
                        }
                        .card()
                    } else if !StatusLine.isInstalled {
                        ConnectLimitsHint().card()
                    }
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
