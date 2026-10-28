import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TokenKuzatCore

struct HistoryView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @State private var range = 30
    @State private var selected: Date?

    var body: some View {
        let days = Array(store.snap.days.suffix(range))
        let total = days.reduce(TokenCounts()) { $0 + $1.tokens }
        let active = days.filter { !$0.tokens.isEmpty }
        let peak = days.max { $0.tokens.value(mode) < $1.tokens.value(mode) }
        let focus = selected.flatMap { d in days.first { Calendar.current.isDate($0.date, inSameDayAs: d) } }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Picker("Davr", selection: $range) {
                        Text("7 kun").tag(7)
                        Text("14 kun").tag(14)
                        Text("30 kun").tag(30)
                    }
                    .pickerStyle(.segmented).labelsHidden().fixedSize()
                    Spacer()
                    Button { exportCSV() } label: { Label("CSV eksport", systemImage: "square.and.arrow.up") }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    MetricTile(title: "\(range) kunda jami", value: Fmt.tokens(total.value(mode)), unit: "token",
                               footnote: "\(active.count) faol kun", symbol: "sum", tint: .blue)
                    MetricTile(title: "Faol kunda o'rtacha",
                               value: Fmt.tokens(active.isEmpty ? 0 : total.value(mode) / Double(active.count)), unit: "token",
                               footnote: "Bo'sh kunlar hisobga olinmaydi", symbol: "chart.line.flattrend.xyaxis", tint: .teal)
                    MetricTile(title: "Eng ko'p kun", value: Fmt.tokens(peak?.tokens.value(mode) ?? 0), unit: "token",
                               footnote: peak.map { Fmt.longDay.string(from: $0.date) } ?? "—", symbol: "flame.fill", tint: .orange)
                }

                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader(title: "Kunlar bo'yicha", subtitle: "kunni bosing — tarkibi chiqadi")
                    DailyChart(days: days, mode: mode, height: 220, selected: $selected)
                }
                .card()

                let detail = focus?.tokens ?? total
                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: focus.map { Fmt.longDay.string(from: $0.date) } ?? "\(range) kunlik tarkib",
                                  trailing: focus == nil ? nil : AnyView(
                                      Button("Tanlovni bekor qilish") { selected = nil }.buttonStyle(.link).font(.caption)))
                    let slices = Composition.slices(detail, mode)
                    BreakdownBar(slices: slices, height: 12)
                    BreakdownLegend(slices: slices, total: detail.value(mode))
                }
                .card()

                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(title: "Jadval")
                    DayTable(days: days.reversed(), mode: mode)
                }
                .card()

                Text("Kunlik jami ~/Library/Application Support/TokenKuzat/history.json da saqlanadi — Claude yozuvlari o'chsa ham tarix qoladi.")
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
            row(["Sana", "Jami", "Kesh o'qish", "Kesh yozish", "Kiritish", "Javob"], header: true)
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
                Text("Bu davrda ma'lumot yo'q").font(.caption).foregroundStyle(.secondary).padding(12)
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
