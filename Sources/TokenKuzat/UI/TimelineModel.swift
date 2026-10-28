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
        var shares = [TimeShare(title: tr("Model: o'ylash va javob", "Model: thinking and output"), symbol: "sparkles", color: Palette.main,
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

