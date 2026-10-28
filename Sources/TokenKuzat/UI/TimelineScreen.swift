import SwiftUI
import AppKit
import TokenKuzatCore

// Vaqt chizig'i: har bir agent — qator, har bir qadam — boshlanishidan tugashigacha chiziq.
// Bir vaqtda bajarilgan qadamlar (parallel asbob chaqiruvlari) qator ichida ustma-ust qo'yiladi.
// Tepada — «vaqt qayerga ketdi»: asbob turlari bo'yicha va modelning o'zi (o'ylash/javob yozish).

struct TimelineBar: Identifiable {
    let id: String
    let start: Date
    let end: Date
    let step: StepSnap
    /// Qator ichidagi qavat (parallel qadamlar uchun)
    var level = 0
}

struct TimelineRow: Identifiable {
    var id: String { agent.id }
    let agent: AgentSnap
    let bars: [TimelineBar]
    let levels: Int
}

struct TimeShare: Identifiable {
    var id: String { title }
    let title: String
    let symbol: String
    let color: Color
    let seconds: TimeInterval
}

struct TimelineModel {
    let start: Date
    let end: Date
    let rows: [TimelineRow]
    let turnMarks: [TurnSnap]
    let active: Bool
    let shares: [TimeShare]

    var duration: TimeInterval { max(1, end.timeIntervalSince(start)) }

    init(flow: FlowModel, session: SessionSnap, turnId: Int?, now: Date) {
        let lanes = ([flow.main].compactMap { $0 } + flow.helpers).filter { !$0.steps.isEmpty || $0.agent.isMain }
        let turn = turnId.flatMap { id in session.turns.first { $0.id == id } }
        active = flow.result.active

        func interval(_ s: StepSnap) -> (Date, Date) {
            let d = s.duration ?? 1
            return (s.date, s.date.addingTimeInterval(max(d, 0.5)))
        }
        let all = lanes.flatMap(\.steps)
        let first = [turn?.start, all.map(\.date).min(), turnId == nil ? session.turns.first?.start : nil].compactMap { $0 }.min()
        start = first ?? now
        var last = all.map { interval($0).1 }.max() ?? start
        if let t = turn { last = max(last, t.end) } else if let la = session.lastActivity { last = max(last, la) }
        if active { last = max(last, now) }
        end = max(last, start.addingTimeInterval(5))

        rows = lanes.map { lane in
            var bars = lane.steps.map { s -> TimelineBar in
                let (a, b) = interval(s)
                return TimelineBar(id: s.id, start: a, end: b, step: s)
            }
            // Qavatlarga taqsimlash: ustma-ust tushgan qadam keyingi qavatga
            var levelEnds: [Date] = []
            for i in bars.indices {
                if let free = levelEnds.firstIndex(where: { $0 <= bars[i].start }) {
                    bars[i].level = free
                    levelEnds[free] = bars[i].end
                } else {
                    bars[i].level = levelEnds.count
                    levelEnds.append(bars[i].end)
                }
            }
            return TimelineRow(agent: lane.agent, bars: bars, levels: max(1, levelEnds.count))
        }
        turnMarks = turnId == nil ? session.turns : []

        // Vaqt qayerga ketdi: asosiy agent qatorida asboblar band bo'lgan vaqt (birlashma), qolgani — model
        var byCat: [ToolCategory: TimeInterval] = [:]
        for row in rows {
            for (cat, t) in TimelineModel.unionByCategory(row.bars) { byCat[cat, default: 0] += t }
        }
        let mainBars = rows.first(where: { $0.agent.isMain })?.bars ?? []
        let mainBusy = TimelineModel.union(mainBars.map { ($0.start, $0.end) })
        let total = end.timeIntervalSince(start)
        var shares = [TimeShare(title: "Model: o'ylash va javob", symbol: "sparkles", color: Palette.main,
                                seconds: max(0, total - mainBusy))]
        shares += byCat.sorted { $0.value > $1.value }.map {
            TimeShare(title: $0.key.title, symbol: $0.key.symbol, color: $0.key.color, seconds: $0.value)
        }
        self.shares = shares.filter { $0.seconds >= 0.5 }
    }

    /// Ustma-ust intervallar birlashmasining uzunligi
    static func union(_ intervals: [(Date, Date)]) -> TimeInterval {
        let sorted = intervals.sorted { $0.0 < $1.0 }
        var total: TimeInterval = 0
        var cur: (Date, Date)?
        for iv in sorted {
            if let c = cur, iv.0 <= c.1 {
                cur = (c.0, max(c.1, iv.1))
            } else {
                if let c = cur { total += c.1.timeIntervalSince(c.0) }
                cur = iv
            }
        }
        if let c = cur { total += c.1.timeIntervalSince(c.0) }
        return total
    }

    static func unionByCategory(_ bars: [TimelineBar]) -> [ToolCategory: TimeInterval] {
        Dictionary(grouping: bars, by: { $0.step.category }).mapValues { union($0.map { ($0.start, $0.end) }) }
    }
}

// MARK: - Ko'rinish

struct TimelineScreen: View {
    let model: TimelineModel
    let selectedAgent: String?
    let onSelectAgent: (String) -> Void
    let onSelectStep: (AgentSnap, StepSnap) -> Void
    @State private var zoom: CGFloat = 1

    private let labelW: CGFloat = 190
    private let levelH: CGFloat = 22
    private let rowPad: CGFloat = 10

    var body: some View {
        VStack(spacing: 0) {
            SharesBar(shares: model.shares, total: model.duration).padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            GeometryReader { geo in
                let plotW = max(200, (geo.size.width - labelW - 24) * zoom)
                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 0) {
                        axis(plotW).padding(.leading, labelW)
                        ForEach(model.rows) { row in
                            HStack(spacing: 0) {
                                rowLabel(row).frame(width: labelW, alignment: .leading)
                                rowPlot(row, plotW)
                            }
                            .frame(height: CGFloat(row.levels) * levelH + rowPad * 2)
                            .background(selectedAgent == row.agent.id ? Color.accentColor.opacity(0.08) : .clear)
                            Divider()
                        }
                    }
                    .overlay(alignment: .topLeading) { marks(plotW).padding(.leading, labelW).allowsHitTesting(false) }
                    .padding(.trailing, 24)
                }
            }
            .overlay(alignment: .bottomTrailing) { zoomControls.padding(12) }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    // MARK: Qismlar

    private func x(_ d: Date, _ w: CGFloat) -> CGFloat {
        CGFloat(d.timeIntervalSince(model.start) / model.duration) * w
    }

    private func axis(_ w: CGFloat) -> some View {
        let step = Self.tickStep(model.duration, width: w)
        let count = Int(model.duration / step)
        return ZStack(alignment: .topLeading) {
            ForEach(0...max(0, count), id: \.self) { i in
                let t = TimeInterval(i) * step
                Text(Self.tickLabel(t, start: model.start, step: step))
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    .fixedSize()
                    .offset(x: CGFloat(t / model.duration) * w - 2)
            }
        }
        .frame(width: w, height: 24, alignment: .topLeading)
        .padding(.top, 6)
    }

    /// Vertikal chiziqlar: belgilar, so'rov chegaralari va «hozir»
    private func marks(_ w: CGFloat) -> some View {
        let step = Self.tickStep(model.duration, width: w)
        let count = Int(model.duration / step)
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0...max(0, count), id: \.self) { i in
                    Rectangle().fill(Color.primary.opacity(0.06))
                        .frame(width: 1, height: geo.size.height - 30)
                        .offset(x: CGFloat(TimeInterval(i) * step / model.duration) * w, y: 30)
                }
                ForEach(model.turnMarks) { t in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("#\(t.id)").font(.system(size: 9, weight: .bold)).foregroundStyle(Palette.cacheRead)
                        Rectangle().fill(Palette.cacheRead.opacity(0.5)).frame(width: 1)
                    }
                    .frame(height: geo.size.height - 18)
                    .offset(x: x(t.start, w), y: 18)
                    .help("#\(t.id) · \(t.prompt)")
                }
                if model.active {
                    Rectangle().fill(Color.green.opacity(0.7)).frame(width: 1.5, height: geo.size.height - 30)
                        .offset(x: w - 1, y: 30)
                }
            }
        }
    }

    private func rowLabel(_ row: TimelineRow) -> some View {
        Button { onSelectAgent(row.agent.id) } label: {
            HStack(spacing: 8) {
                IconTile(symbol: agentSymbol(row.agent), tint: row.agent.isMain ? Palette.main : Palette.agents, size: 26)
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(row.agent.isMain ? "Asosiy agent" : row.agent.title).font(.caption.weight(.semibold)).lineLimit(1)
                        StateDot(state: row.agent.state, size: 6)
                    }
                    Text("\(row.bars.count) qadam").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func rowPlot(_ row: TimelineRow, _ w: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Agent faol bo'lgan oraliq — xira fon
            if let a = row.agent.firstActivity, let b = row.agent.lastActivity {
                let x0 = max(0, x(a, w)), x1 = min(w, x(b, w))
                if x1 > x0 {
                    Capsule().fill(Color.primary.opacity(0.05))
                        .frame(width: x1 - x0, height: CGFloat(row.levels) * levelH - 4)
                        .offset(x: x0, y: rowPad + 2)
                }
            }
            ForEach(row.bars) { bar in
                let x0 = x(bar.start, w)
                let bw = max(3, x(bar.end, w) - x0)
                StepBar(step: bar.step, width: bw)
                    .offset(x: x0, y: rowPad + CGFloat(bar.level) * levelH + 2)
                    .onTapGesture { onSelectStep(row.agent, bar.step) }
            }
        }
        .frame(width: w, alignment: .topLeading)
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            zoomButton("minus", "Kichraytirish") { zoom = max(1, zoom / 1.5) }
            Divider().frame(height: 16)
            zoomButton("arrow.left.and.right", "Kenglikka sig'dirish") { zoom = 1 }
            Divider().frame(height: 16)
            zoomButton("plus", "Kattalashtirish") { zoom = min(20, zoom * 1.5) }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func zoomButton(_ symbol: String, _ help: String, _ action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.15)) { action() } }) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).frame(width: 30, height: 26)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: O'q belgilari

    /// Taxminan 90 pt da bitta belgi bo'ladigan «yumaloq» qadam
    static func tickStep(_ duration: TimeInterval, width: CGFloat) -> TimeInterval {
        let target = duration / max(1, Double(width / 90))
        let steps: [TimeInterval] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600, 7200, 14400]
        return steps.first { $0 >= target } ?? 14400
    }

    static func tickLabel(_ t: TimeInterval, start: Date, step: TimeInterval) -> String {
        if step >= 600 { return Fmt.hourMinute.string(from: start.addingTimeInterval(t)) }
        let s = Int(t)
        return s >= 60 ? "\(s / 60)m\(s % 60 == 0 ? "" : " \(s % 60)s")" : "\(s)s"
    }
}

private struct StepBar: View {
    let step: StepSnap
    let width: CGFloat

    var body: some View {
        let color = step.status == .failed ? Color.red : step.category.color
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color.opacity(step.status == .running ? 0.45 : 0.8))
            .overlay {
                if step.status == .running {
                    TimelineView(.animation(minimumInterval: 1.0 / 15)) { ctx in
                        let t = ctx.date.timeIntervalSinceReferenceDate
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(color, lineWidth: 1.5).opacity(0.5 + 0.5 * sin(t * 4))
                    }
                }
            }
            .overlay(alignment: .leading) {
                if width > 70 {
                    Text(step.targetName).font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white).lineLimit(1).padding(.horizontal, 5)
                }
            }
            .frame(width: width, height: 18)
            .help("\(step.text)\n\(Fmt.clock.string(from: step.date)) · \(step.duration.map { Alerts.duration($0) } ?? "—")\(step.status == .failed ? " · xato" : step.status == .running ? " · bajarilmoqda" : "")")
    }
}

/// «Vaqt qayerga ketdi»: bitta chiziq va izoh
private struct SharesBar: View {
    let shares: [TimeShare]
    let total: TimeInterval

    var body: some View {
        let sum = max(1, shares.reduce(0) { $0 + $1.seconds })
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Vaqt qayerga ketdi").font(.callout.weight(.semibold))
                Spacer()
                Text("Jami \(Alerts.duration(total))").font(.caption).foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(shares) { s in
                        RoundedRectangle(cornerRadius: 3, style: .continuous).fill(s.color)
                            .frame(width: max(3, (geo.size.width - CGFloat(shares.count) * 2) * CGFloat(s.seconds / sum)))
                            .help("\(s.title): \(Alerts.duration(s.seconds))")
                    }
                }
            }
            .frame(height: 10)
            HStack(spacing: 14) {
                ForEach(shares) { s in
                    HStack(spacing: 4) {
                        Circle().fill(s.color).frame(width: 7, height: 7)
                        Text(s.title).font(.caption)
                        Text("\(Alerts.duration(s.seconds)) · \(Fmt.percent(s.seconds, of: sum))")
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
        }
    }
}
