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
                SettingsMenu(title: tr("Loyiha", "Project"), selection: $project,
                             options: [("", tr("Barcha loyihalar", "All projects"))] + projects.map { ($0, $0) })
                Toggle(tr("Faqat so'rovlarim", "Only my prompts"), isOn: $onlyPrompts)
                    .toggleStyle(.switch).controlSize(.mini).tint(Brand.accent)
                Spacer()
                Text(tr("Bugun · \(shown.count) ta harakat", shown.count == 1 ? "Today · 1 action" : "Today · \(shown.count) actions")).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            Divider()
            if shown.isEmpty {
                EmptyStateView(symbol: "waveform.path.ecg", title: tr("Hali harakat yo'q", "No activity yet"),
                               text: tr("Agentlar fayl o'qisa, tahrir qilsa yoki terminal ishlatsa — shu yerda jonli chiqadi.", "When agents read or edit files or use the terminal, it shows up here live."))
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
