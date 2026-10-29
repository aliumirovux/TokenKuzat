import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TokenKuzatCore

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.weighted
    /// Foydalanuvchi tanlagan davr; tanlanmagan bo'lsa — yig'ilgan tarixga mos eng qisqa davr
    @State private var picked: Int?
    @State private var selected: Date?

    /// Tarix yozila boshlagan kun (birinchi sarfli kun)
    private var firstDay: Date? { store.snap.days.first { !$0.tokens.isEmpty }?.date }

    /// Birinchi sarfli kundan bugungacha necha kun
    private var collectedDays: Int? {
        guard let firstDay else { return nil }
        let cal = Calendar.current
        return (cal.dateComponents([.day], from: cal.startOfDay(for: firstDay), to: cal.startOfDay(for: store.snap.updatedAt)).day ?? 0) + 1
    }

    private var range: Int { picked ?? [7, 14, 30].first { $0 >= (collectedDays ?? 30) } ?? 30 }

    var body: some View {
        let range = self.range
        let days = Array(store.snap.days.suffix(range))
        let total = days.reduce(TokenCounts()) { $0 + $1.tokens }
        let active = days.filter { !$0.tokens.isEmpty }
        let peak = days.max { $0.tokens.value(mode) < $1.tokens.value(mode) }
        let focus = selected.flatMap { d in days.first { Calendar.current.isDate($0.date, inSameDayAs: d) } }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    PillSegments(selection: Binding(get: { range }, set: { picked = $0 }),
                                 items: [7, 14, 30].map { .init(id: $0, title: tr("\($0) kun", "\($0) days")) })
                    // Davr tarixdan uzun bo'lsa — bo'sh kunlar nega bo'shligi aytiladi
                    if let firstDay, let collectedDays, collectedDays < range {
                        Text(tr("Tarix \(Fmt.shortDay.string(from: firstDay)) dan yig'ilyapti", "History since \(Fmt.shortDay.string(from: firstDay))"))
                            .font(.caption).foregroundStyle(.secondary)
                            .padding(.leading, 6)
                    }
                    Spacer()
                    Button { exportCSV() } label: { Label(tr("CSV eksport", "Export CSV"), systemImage: "square.and.arrow.up") }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    MetricTile(title: tr("\(range) kunda jami", "Total, \(range) days"), value: Fmt.tokens(total.value(mode)), unit: tr("token", "tokens"),
                               footnote: tr("\(active.count) faol kun", active.count == 1 ? "1 active day" : "\(active.count) active days"), symbol: "sum", tint: .blue)
                    MetricTile(title: tr("Faol kunda o'rtacha", "Average per active day"),
                               value: Fmt.tokens(active.isEmpty ? 0 : total.value(mode) / Double(active.count)), unit: tr("token", "tokens"),
                               footnote: tr("Bo'sh kunlar hisobga olinmaydi", "Empty days aren't counted"), symbol: "chart.line.flattrend.xyaxis", tint: .teal)
                    MetricTile(title: tr("Eng ko'p kun", "Peak day"), value: Fmt.tokens(peak?.tokens.value(mode) ?? 0), unit: tr("token", "tokens"),
                               footnote: peak.map { Fmt.longDay.string(from: $0.date) } ?? "—", symbol: "flame.fill", tint: .orange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: tr("Kunlar bo'yicha", "By day"), subtitle: tr("kunni bosing — tarkibi chiqadi", "click a day to see its breakdown"))
                    DailyChart(days: days, mode: mode, height: 220, selected: $selected)
                }
                .card()

                let detail = focus?.tokens ?? total
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: focus.map { Fmt.longDay.string(from: $0.date) } ?? tr("\(range) kunlik tarkib", "\(range)-day breakdown"),
                                  trailing: focus == nil ? nil : AnyView(
                                      Button(tr("Tanlovni bekor qilish", "Clear selection")) { selected = nil }.buttonStyle(.link).font(.caption)))
                    let slices = Composition.slices(detail, mode)
                    BreakdownBar(slices: slices, height: 12)
                    BreakdownLegend(slices: slices, total: detail.value(mode))
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: tr("Jadval", "Table"))
                    DayTable(days: days.reversed(), mode: mode)
                }
                .card()

                Text(tr("Kunlik jami ~/Library/Application Support/TokenKuzat/history.json da saqlanadi — Claude yozuvlari o'chsa ham tarix qoladi.", "Daily totals are saved to ~/Library/Application Support/TokenKuzat/history.json — history stays even if Claude's logs are deleted."))
                    .font(.caption).foregroundStyle(.tertiary)
            }
            .padding(20)
        }
    }

    private func exportCSV() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "token-tarixi-\(HistoryStore.key(Date())).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var csv = "sana,jami,kiritish,javob,fikrlash,kesh_yozish,kesh_oqish,vaznli\n"
        for d in store.allHistory() {
            let t = d.tokens
            csv += "\(HistoryStore.key(d.date)),\(t.total),\(t.input),\(t.output),\(t.thinking),\(t.cacheWrite),\(t.cacheRead),\(Int(t.weighted.rounded()))\n"
        }
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
}

private struct DayTable: View {
    let days: [DayPoint]
    let mode: CountMode

    var body: some View {
        VStack(spacing: 0) {
            row([tr("Sana", "Date"), tr("Jami", "Total"), tr("Kesh o'qish", "Cache read"), tr("Kesh yozish", "Cache write"), tr("Kiritish", "Input"), tr("Javob", "Output")], header: true)
            Divider()
            ForEach(days.filter { !$0.tokens.isEmpty }) { d in
                let t = d.tokens
                let w = mode == .weighted
                row([Fmt.longDay.string(from: d.date),
                     Fmt.tokens(t.value(mode)),
                     Fmt.tokens(w ? Double(t.cacheRead) * Pricing.cacheRead : Double(t.cacheRead)),
                     Fmt.tokens(w ? max(0, t.weighted - Double(t.cacheRead) * Pricing.cacheRead - Double(t.output) * Pricing.output - Double(t.input)) : Double(t.cacheWrite)),
                     Fmt.tokens(t.input),
                     Fmt.tokens(w ? Double(t.output) * Pricing.output : Double(t.output))], header: false)
            }
            if days.allSatisfy({ $0.tokens.isEmpty }) {
                Text(tr("Bu davrda ma'lumot yo'q", "No data for this period")).font(.caption).foregroundStyle(.secondary).padding(12)
            }
        }
    }

    private func row(_ cells: [String], header: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(c)
                    .font(header ? .caption.weight(.semibold) : .callout)
                    .foregroundStyle(header ? .secondary : .primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .trailing)
                    .frame(minWidth: i == 0 ? 170 : 0)
            }
        }
        .padding(.vertical, 6)
    }
}
