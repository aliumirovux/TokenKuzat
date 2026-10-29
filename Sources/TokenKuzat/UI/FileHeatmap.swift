import SwiftUI
import AppKit
import TokenKuzatCore

// Fayllar issiqlik xaritasi: har bir fayl — qator, vaqt o'qi bo'yicha katakchalar.
// Katakcha rangi: ko'k — o'qildi, to'q sariq — o'zgartirildi; to'qligi — shu oraliqdagi murojaatlar soni.
// Eng «issiq» (ko'p o'zgartirilgan, keyin ko'p o'qilgan) fayllar tepada.

struct HeatCell {
    var reads = 0
    var writes = 0
    var errors = 0
    var total: Int { reads + writes }
}

struct FileHeat: Identifiable {
    let id: String          // to'liq yo'l
    let name: String
    let dir: String
    var reads = 0
    var writes = 0
    var errors = 0
    var last = Date.distantPast
    var cells: [HeatCell]
    /// Agent id → murojaatlar soni
    var agents: [String: Int] = [:]
    var agentTitles: [String: String] = [:]

    var score: Int { writes * 3 + reads }
    var ownerId: String? { agents.max { $0.value < $1.value }?.key }
}

struct HeatmapModel {
    let start: Date
    let end: Date
    let buckets: Int
    let files: [FileHeat]
    let maxCell: Int
    let searches: Int
    let dirs: [(dir: String, score: Int, files: Int)]

    init(timeline: TimelineModel, buckets: Int = 48) {
        start = timeline.start
        end = timeline.end
        self.buckets = buckets
        let span = max(1, end.timeIntervalSince(start))
        var byPath: [String: FileHeat] = [:]
        var searches = 0

        for row in timeline.rows {
            for bar in row.bars where bar.step.category == .files {
                let s = bar.step
                guard s.targetKey.hasPrefix("files|"), !s.targetKey.hasPrefix("files|search|") else {
                    searches += 1
                    continue
                }
                let path = String(s.targetKey.dropFirst("files|".count))
                var f = byPath[path] ?? FileHeat(id: path, name: s.targetName, dir: s.targetDetail,
                                                 cells: Array(repeating: HeatCell(), count: buckets))
                let i = min(buckets - 1, max(0, Int(s.date.timeIntervalSince(start) / span * Double(buckets))))
                let failed = s.status == .failed
                if s.access == .write { f.writes += 1; f.cells[i].writes += 1 } else { f.reads += 1; f.cells[i].reads += 1 }
                if failed { f.errors += 1; f.cells[i].errors += 1 }
                f.last = max(f.last, s.date)
                f.agents[row.agent.id, default: 0] += 1
                f.agentTitles[row.agent.id] = row.agent.isMain ? tr("Asosiy agent", "Main agent") : row.agent.title
                byPath[path] = f
            }
        }
        files = byPath.values.sorted { $0.score != $1.score ? $0.score > $1.score : $0.last > $1.last }
        maxCell = max(1, files.flatMap(\.cells).map(\.total).max() ?? 1)
        self.searches = searches
        dirs = Dictionary(grouping: files, by: \.dir)
            .map { (dir: $0.key, score: $0.value.reduce(0) { $0 + $1.score }, files: $0.value.count) }
            .sorted { $0.score > $1.score }
    }

    var totalReads: Int { files.reduce(0) { $0 + $1.reads } }
    var totalWrites: Int { files.reduce(0) { $0 + $1.writes } }
    var totalErrors: Int { files.reduce(0) { $0 + $1.errors } }
}

// MARK: - Ko'rinish

struct FileHeatmapScreen: View {
    let model: HeatmapModel
    let onSelectFile: (FileHeat) -> Void
    @State private var query = ""
    @State private var onlyChanged = false

    private let nameW: CGFloat = 230
    private let statsW: CGFloat = 130

    var body: some View {
        let shown = model.files.filter {
            (!onlyChanged || $0.writes > 0) && (query.isEmpty || $0.id.localizedCaseInsensitiveContains(query))
        }
        VStack(spacing: 0) {
            summary.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            if model.files.isEmpty {
                EmptyStateView(symbol: "doc.on.doc", title: tr("Bu davrda fayllarga tegilmagan", "No files touched in this period"),
                               text: model.searches > 0
                                   ? tr("\(model.searches) ta qidiruv bo'ldi, lekin birorta fayl o'qilmadi yoki o'zgartirilmadi.", model.searches == 1 ? "1 search ran, but no files were read or changed." : "\(model.searches) searches ran, but no files were read or changed.")
                                   : tr("Agent fayl o'qisa yoki tahrir qilsa — shu yerda issiqlik xaritasi bo'lib chiqadi.", "When an agent reads or edits files, a heatmap shows up here."))
                Spacer()
            } else {
                GeometryReader { geo in
                    let gridW = max(160, geo.size.width - nameW - statsW - 40)
                    ScrollView {
                        VStack(spacing: 0) {
                            header(gridW)
                            ForEach(shown) { f in
                                row(f, gridW)
                                Divider().opacity(0.5)
                            }
                            if shown.isEmpty {
                                Text(tr("Hech narsa topilmadi", "Nothing found")).font(.caption).foregroundStyle(.secondary).padding(20)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(Color.clear)
    }

    // MARK: Qismlar

    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 18) {
                stat("\(model.files.count)", model.files.count == 1 ? tr("fayl", "file") : tr("fayl", "files"), "doc.on.doc.fill", Hue.read)
                stat("\(model.totalReads)", model.totalReads == 1 ? tr("o'qish", "read") : tr("o'qish", "reads"), "eye.fill", Hue.read)
                stat("\(model.totalWrites)", model.totalWrites == 1 ? tr("o'zgartirish", "change") : tr("o'zgartirish", "changes"), "pencil", Hue.write)
                if model.totalErrors > 0 { stat("\(model.totalErrors)", model.totalErrors == 1 ? tr("xato", "error") : tr("xato", "errors"), "exclamationmark.triangle.fill", Brand.err) }
                if model.searches > 0 { stat("\(model.searches)", model.searches == 1 ? tr("qidiruv", "search") : tr("qidiruv", "searches"), "magnifyingglass", .secondary) }
                Spacer()
                Toggle(tr("Faqat o'zgarganlar", "Changed only"), isOn: $onlyChanged).toggleStyle(.checkbox).font(.caption).fixedSize()
                TextField(tr("Fayl qidirish", "Search files"), text: $query).textFieldStyle(.roundedBorder).frame(minWidth: 100, maxWidth: 180)
            }
            if !model.dirs.isEmpty {
                HStack(spacing: 6) {
                    Text(tr("Eng issiq papkalar:", "Hottest folders:")).font(.caption).foregroundStyle(.secondary)
                    ForEach(model.dirs.prefix(4), id: \.dir) { d in
                        Button { query = d.dir } label: {
                            Chip(text: "\((d.dir as NSString).lastPathComponent) · \(d.files)", symbol: "folder.fill")
                        }
                        .buttonStyle(.plain)
                        .help(d.dir)
                    }
                }
            }
        }
    }

    private func stat(_ v: String, _ label: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol).font(.caption).foregroundStyle(color)
            Text(v).font(.system(.callout, design: .rounded).weight(.semibold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func header(_ gridW: CGFloat) -> some View {
        HStack(spacing: 12) {
            Text(tr("Fayl", "File")).frame(width: nameW, alignment: .leading)
            HStack {
                Text(Fmt.hourMinute.string(from: model.start))
                Spacer()
                Text(Fmt.hourMinute.string(from: model.start.addingTimeInterval(model.end.timeIntervalSince(model.start) / 2)))
                Spacer()
                Text(Fmt.hourMinute.string(from: model.end))
            }
            .frame(width: gridW)
            HStack(spacing: 10) {
                Image(systemName: "eye")
                Image(systemName: "pencil")
                Image(systemName: "person.2")
            }
            .frame(width: statsW, alignment: .trailing)
        }
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.vertical, 8)
    }

    private func row(_ f: FileHeat, _ gridW: CGFloat) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: f.writes > 0 ? "doc.badge.ellipsis" : "doc.text")
                        .font(.caption).foregroundStyle(f.writes > 0 ? Hue.write : Hue.read)
                    Text(f.name).font(.callout.weight(f.writes > 0 ? .semibold : .regular)).lineLimit(1).truncationMode(.middle)
                }
                Text(f.dir).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            }
            .frame(width: nameW, alignment: .leading)

            HeatStrip(cells: f.cells, maxCell: model.maxCell).frame(width: gridW, height: 18)

            HStack(spacing: 10) {
                Text("\(f.reads)").foregroundStyle(f.reads > 0 ? .primary : .tertiary)
                Text("\(f.writes)").foregroundStyle(f.writes > 0 ? Hue.write : Color.secondary.opacity(0.5))
                Text("\(f.agents.count)").foregroundStyle(.secondary)
                    .help(f.agentTitles.values.sorted().joined(separator: "\n"))
                if f.errors > 0 {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Brand.err).help("\(f.errors) ta xato")
                }
            }
            .font(.caption.monospacedDigit())
            .frame(width: statsW, alignment: .trailing)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { onSelectFile(f) }
        .contextMenu {
            Button(tr("Finder'da ko'rsatish", "Show in Finder")) {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: f.id)])
            }
            .disabled(!FileManager.default.fileExists(atPath: f.id))
            Button(tr("Yo'lni nusxalash", "Copy path")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(f.id, forType: .string)
            }
        }
        .help(tr("\(f.id)\nOxirgi marta: \(Fmt.clock.string(from: f.last)) · o'ng tugma — Finder", "\(f.id)\nLast: \(Fmt.clock.string(from: f.last)) · right-click — Finder"))
    }
}

/// Bir faylning vaqt bo'yicha katakchalari
private struct HeatStrip: View {
    let cells: [HeatCell]
    let maxCell: Int

    var body: some View {
        Canvas { g, size in
            let n = CGFloat(cells.count)
            let gap: CGFloat = 1.5
            let w = max(1, (size.width - gap * (n - 1)) / n)
            for (i, c) in cells.enumerated() {
                let rect = CGRect(x: CGFloat(i) * (w + gap), y: 0, width: w, height: size.height)
                let path = Path(roundedRect: rect, cornerRadius: 2.5)
                if c.total == 0 {
                    g.fill(path, with: .color(Color.primary.opacity(0.05)))
                    continue
                }
                // Kam murojaat ham ko'rinsin: 0.35 dan boshlanadi
                let k = 0.35 + 0.65 * sqrt(Double(c.total) / Double(maxCell))
                let color: Color = c.errors > 0 ? Brand.err : (c.writes > 0 ? Hue.write : Hue.read)
                g.fill(path, with: .color(color.opacity(k)))
            }
        }
    }
}
