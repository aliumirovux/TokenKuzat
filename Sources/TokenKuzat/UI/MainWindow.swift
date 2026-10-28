import SwiftUI
import TokenKuzatCore

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.section) private var section = Section.overview

    var body: some View {
        NavigationSplitView {
            Sidebar(section: $section)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if section != .graph { header }
                detail
                    .id(section)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .animation(Motion.spring, value: section)
            .background(Brand.canvas)
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

    /// Sahifa sarlavhasi: nom (yumaloq displey shrift), sana, jonli holat va hisoblash usuli
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(section == .overview ? "Bugun" : section.title)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
            if section == .overview {
                Text(Fmt.longDay.string(from: store.snap.updatedAt)).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(running: store.snap.runningAgents, active: store.snap.activeSessions)
            if section == .history || section == .sessions { CountModePicker() }
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 14)
    }

}

/// Yon menyu: brend, 3 ta bo'lim, loyihalar (jonli nuqta bilan) va pastda Sozlamalar
private struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var section: Section
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 26, height: 26)
                Text("Token Kuzatuv").font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 10).padding(.bottom, 14)

            item(.overview, "Bugun", "sun.max")
            item(.sessions, "Sessiyalar", "rectangle.stack", badge: store.snap.runningAgents > 0 ? store.snap.activeSessions : 0)
            item(.history, "Tarix", "chart.bar.xaxis")

            Text("LOYIHALAR").eyebrow().padding(.horizontal, 10).padding(.top, 18).padding(.bottom, 4)
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(projects, id: \.id) { sess in
                        projectRow(sess)
                    }
                }
            }

            Spacer(minLength: 8)
            item(.settings, "Sozlamalar", "gearshape")
            Text("Yangilandi: \(Fmt.ago(store.snap.updatedAt)) · \(store.snap.filesWatched) fayl")
                .font(.caption2).foregroundStyle(.tertiary).padding(.horizontal, 10).padding(.top, 4)
        }
        .padding(.horizontal, 8).padding(.top, 38).padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// Har loyihadan eng so'nggi sessiya, ishlayotgani tepada
    private var projects: [SessionSnap] {
        var seen = Set<String>()
        return store.snap.sessions
            .sorted { ($0.state != .idle ? 1 : 0, $0.lastActivity ?? .distantPast) > ($1.state != .idle ? 1 : 0, $1.lastActivity ?? .distantPast) }
            .filter { seen.insert($0.project).inserted }
            .prefix(8).map { $0 }
    }

    private func item(_ s: Section, _ title: String, _ symbol: String, badge: Int = 0) -> some View {
        let on = section == s
        return Button { withAnimation(Motion.spring) { section = s } } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(on ? Brand.accent : .secondary).frame(width: 18)
                Text(title).fontWeight(on ? .semibold : .regular)
                Spacer()
                if badge > 0 {
                    HStack(spacing: 4) { StateDot(state: .running, size: 6); Text("\(badge)") }
                        .font(.caption.weight(.semibold)).foregroundStyle(Brand.ok)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(on ? Brand.surface : .clear)
                .shadow(color: .black.opacity(on ? 0.06 : 0), radius: 2, y: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noFocusRing()
    }

    private func projectRow(_ sess: SessionSnap) -> some View {
        let on = section == .graph && sessionId == sess.id
        return Button {
            sessionId = sess.id
            withAnimation(Motion.spring) { section = .graph }
        } label: {
            HStack(spacing: 9) {
                ProjectAvatar(name: sess.project, size: 20)
                Text(sess.project).lineLimit(1).fontWeight(on ? .semibold : .regular)
                Spacer()
                if sess.state != .idle { StateDot(state: sess.state, size: 6) }
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(on ? Brand.surface : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .noFocusRing()
        .help(sess.title)
    }
}
