import SwiftUI
import TokenKuzatCore

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.section) private var section = Section.overview

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { section }, set: { if let s = $0 { section = s } })) {
                SwiftUI.Section {
                    ForEach([Section.overview, .graph, .sessions, .history, .activity]) { item in
                        row(item)
                    }
                }
                SwiftUI.Section {
                    row(.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
            .safeAreaInset(edge: .bottom) { sidebarFooter }
        } detail: {
            VStack(spacing: 0) {
                header
                detail
                    .id(section)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(Motion.spring, value: section)
            .background(AmbientBackground())
            .frame(minWidth: 640, minHeight: 520)
        }
    }

    private func row(_ item: Section) -> some View {
        Label(item.title, systemImage: item.symbol)
            .badge(item == .sessions && store.snap.activeSessions > 0 ? store.snap.activeSessions : 0)
            .tag(item)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .overview: OverviewView()
        case .graph: GraphScreen()
        case .sessions: SessionsView()
        case .history: HistoryView()
        case .activity: ActivityView()
        case .settings: SettingsView()
        }
    }

    /// Har bir sahifa tepasidagi sarlavha: nom, jonli holat va hisoblash usuli
    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: section.symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .glassCircle(tint: .accentColor)
            Text(section.title).font(.system(.title2, design: .rounded).weight(.semibold))
            Spacer()
            StatusPill(running: store.snap.runningAgents, active: store.snap.activeSessions)
            if section != .settings { CountModePicker() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 34)
        .padding(.bottom, 12)
    }

    private var sidebarFooter: some View {
        let s = store.snap
        return VStack(alignment: .leading, spacing: 2) {
            Text("\(s.filesWatched) ta fayl kuzatilyapti")
            Text("Yangilandi: \(Fmt.ago(s.updatedAt))")
        }
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}
