import SwiftUI
import TokenKuzatCore

struct ActivityView: View {
    @EnvironmentObject var store: Store
    @State private var project = ""
    @State private var onlyPrompts = false

    var body: some View {
        let feed = store.snap.feed
        let projects = Array(Set(feed.map(\.project))).sorted()
        let shown = feed.filter {
            (project.isEmpty || $0.project == project) && (!onlyPrompts || $0.symbol == "person.fill")
        }
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Loyiha", selection: $project) {
                    Text("Barcha loyihalar").tag("")
                    ForEach(projects, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 260)
                Toggle("Faqat so'rovlarim", isOn: $onlyPrompts)
                Spacer()
                Text("Bugun · \(shown.count) ta harakat").font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            if shown.isEmpty {
                EmptyStateView(symbol: "waveform.path.ecg", title: "Hali harakat yo'q",
                               text: "Agentlar fayl o'qisa, tahrir qilsa yoki terminal ishlatsa — shu yerda jonli chiqadi.")
                Spacer()
            } else {
                List(shown) { FeedRow(event: $0, showProject: project.isEmpty).padding(.vertical, 3) }
                    .listStyle(.inset)
            }
        }
    }
}

struct FeedRow: View {
    let event: FeedEvent
    var showProject = true

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(Fmt.clock.string(from: event.date))
                .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Image(systemName: event.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(event.symbol == "person.fill" ? Palette.cacheRead : (event.isMain ? Palette.main : Palette.agents))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.text).font(.callout).lineLimit(1)
                Text(showProject ? "\(event.project) · \(event.agentTitle)" : event.agentTitle)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
    }
}
