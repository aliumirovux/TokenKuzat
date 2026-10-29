import SwiftUI
import Charts
import TokenKuzatCore

// MARK: - Kunlik grafik

struct DailyChart: View {
    let days: [DayPoint]
    let mode: CountMode
    var height: CGFloat = 200
    @Binding var selected: Date?

    var body: some View {
        Chart {
            ForEach(days) { d in
                BarMark(x: .value(tr("Kun", "Day"), d.date, unit: .day),
                        y: .value("Token", d.tokens.value(mode)))
                    .foregroundStyle(Calendar.current.isDateInToday(d.date) ? Palette.main.gradient : Palette.main.opacity(0.55).gradient)
                    .cornerRadius(3)
                    .opacity(selected == nil || Calendar.current.isDate(selected!, inSameDayAs: d.date) ? 1 : 0.4)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
                AxisValueLabel { if let d = v.as(Double.self) { Text(Fmt.tokens(d)) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: days.count > 14 ? 5 : 1)) { v in
                AxisValueLabel {
                    if let d = v.as(Date.self) { Text(Fmt.shortDay.string(from: d)) }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onTapGesture { loc in
                        let x = loc.x - geo[proxy.plotAreaFrame].origin.x
                        if let d: Date = proxy.value(atX: x) {
                            let day = Calendar.current.startOfDay(for: d)
                            selected = selected.map { Calendar.current.isDate($0, inSameDayAs: day) } == true ? nil : day
                        }
                    }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Token tarkibi

struct Slice: Identifiable {
    let id: String
    let label: String
    let value: Double
    let color: Color
    var hint: String? = nil
}

enum Composition {
    /// Token turlarining yagona nomlari — texnik «kesh o'qish» o'rniga oddiy so'zlar
    enum Label {
        static var read: String { tr("Qayta o'qilgan kontekst", "Re-read context") }
        static var write: String { tr("Kontekstni eslab qolish", "Saving context") }
        static var input: String { tr("Yangi kiritilgan matn", "New input") }
        static var output: String { tr("Claude javobi va fikrlashi", "Claude's replies and thinking") }
    }

    /// Token turlari bo'yicha bo'laklar (vaznli rejimda — narx koeffitsiyentlari bilan)
    static func slices(_ t: TokenCounts, _ mode: CountMode) -> [Slice] {
        func v(_ raw: Int, _ w: Double) -> Double { mode == .weighted ? w : Double(raw) }
        let readW = Double(t.cacheRead) * Pricing.cacheRead
        let outW = Double(t.output) * Pricing.output
        let inW = Double(t.input)
        let writeW = max(0, t.weighted - readW - outW - inW)
        return [
            Slice(id: "read", label: Label.read, value: v(t.cacheRead, readW), color: Palette.cacheRead,
                  hint: tr("Har javobda butun suhbat qayta o'qiladi — arzon (narxi ×0,1), lekin ko'p", "The whole conversation is re-read on every reply — cheap (price ×0.1), but a lot of it")),
            Slice(id: "write", label: Label.write, value: v(t.cacheWrite, writeW), color: Palette.fresh,
                  hint: tr("Yangi matn va fayllar keyingi javoblar uchun saqlanadi (narxi ×1,25–2)", "New text and files saved for the next replies (price ×1.25–2)")),
            Slice(id: "in", label: Label.input, value: v(t.input, inW), color: Palette.input,
                  hint: tr("Saqlanmasdan yuborilgan matn", "Text sent without being saved")),
            Slice(id: "out", label: Label.output, value: v(t.output, outW), color: Palette.output,
                  hint: t.thinking > 0 ? tr("Shundan fikrlash: \(Fmt.tokens(t.thinking))", "Of which thinking: \(Fmt.tokens(t.thinking))") : tr("Eng qimmat qism (narxi ×5)", "Most expensive part (price ×5)")),
        ]
    }

    /// Sessiya: yordamchi agentlar alohida, asosiy agent tarkibi bo'yicha
    static func session(_ s: SessionSnap, _ mode: CountMode) -> [Slice] {
        [Slice(id: "agents", label: tr("Yordamchi agentlar", "Subagents"), value: s.agentTokens.value(mode), color: Palette.agents)]
            + slices(s.mainTokens, mode)
    }

    /// Birinchi marta ko'rgan odam uchun: texnik nomlar o'rniga oddiy so'zlar, izoh qatorning o'zida
    static func plain(_ slices: [Slice]) -> [Slice] {
        slices.map { sl in
            let hint: String? = switch sl.id {
            case "agents": tr("Claude ishni bo'lib bergan alohida agentlar", "Separate agents Claude handed parts of the work to")
            case "read": tr("Har javobda butun suhbat qayta o'qiladi — arzon, lekin suhbat uzaygan sari ko'payadi", "The whole conversation is re-read on every reply — cheap, but it grows with the conversation")
            case "write": tr("Yangi matn va fayllar keyingi javoblar uchun saqlanadi", "New text and files are saved for the next replies")
            case "in": tr("Saqlanmasdan yuborilgan matn", "Text sent without being saved")
            case "out": tr("Eng qimmat qism", "The most expensive part")
            default: sl.hint
            }
            return Slice(id: sl.id, label: sl.label, value: sl.value, color: sl.color, hint: hint)
        }
    }
}

struct BreakdownBar: View {
    let slices: [Slice]
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            let parts = slices.filter { $0.value > 0 }
            let sum = parts.reduce(0) { $0 + $1.value }
            let gap: CGFloat = 2
            let avail = max(0, geo.size.width - gap * CGFloat(max(0, parts.count - 1)))
            HStack(spacing: gap) {
                if sum == 0 {
                    Capsule().fill(Color.primary.opacity(0.08))
                } else {
                    ForEach(parts) { p in
                        RoundedRectangle(cornerRadius: height / 3, style: .continuous).fill(p.color)
                            .frame(width: max(3, avail * CGFloat(p.value / sum)))
                            .help("\(p.label): \(Fmt.tokens(p.value))")
                    }
                }
            }
        }
        .frame(height: height)
    }
}

struct BreakdownLegend: View {
    let slices: [Slice]
    let total: Double
    /// Izohni (i) belgisi ichida emas, nom ostida ko'rsatish
    var inlineHints = false

    var body: some View {
        VStack(spacing: 6) {
            ForEach(slices) { sl in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(sl.color).frame(width: 9, height: 9)
                    if inlineHints {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(sl.label).font(.caption)
                            if let hint = sl.hint { Text(hint).font(.caption2).foregroundStyle(.secondary).lineLimit(2) }
                        }
                    } else {
                        Text(sl.label).font(.caption)
                        if let hint = sl.hint {
                            Image(systemName: "info.circle").font(.caption2).foregroundStyle(.tertiary).help(hint)
                        }
                    }
                    Spacer()
                    Text(Fmt.tokens(sl.value)).font(.caption).monospacedDigit()
                    Text(Fmt.percent(sl.value, of: total)).font(.caption).foregroundStyle(.secondary)
                        .monospacedDigit().frame(width: 38, alignment: .trailing)
                }
            }
        }
    }
}
