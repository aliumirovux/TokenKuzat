import SwiftUI
import TokenKuzatCore

struct MainWindow: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.section) private var section = Section.overview
    @AppStorage(Pref.mapOnly) private var mapOnly = false
    @AppStorage("flowStyle") private var flowStyle = "map"
    @AppStorage("graphMode") private var graphMode = "flow"
    @State private var columns = NavigationSplitViewVisibility.all
    /// Foydalanuvchi yon menyuni yopgan (eslab qolinadi)
    @AppStorage("sidebarCollapsed") private var collapsed = false

    /// «Faqat xarita» faqat sessiya sahifasining Xarita tabida amal qiladi
    private var mapFocus: Bool { mapOnly && section == .graph && graphMode == "flow" && flowStyle != "summary" }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns) {
            Sidebar(section: $section, onCollapse: { setCollapsed(true) })
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
            .overlay(alignment: .topLeading) {
                // Yon menyu yopiq — oyna tugmalari yonida ochish tugmasi
                if columns == .detailOnly && !mapFocus {
                    PaneToggle(symbol: "sidebar.left", help: "Yon menyuni ochish (⌃⌘S)") { setCollapsed(false) }
                        .padding(.leading, 76).padding(.top, 2)
                        .ignoresSafeArea(.container, edges: .top)
                        .transition(.opacity)
                }
            }
            .frame(minWidth: 520, minHeight: 520)
        }
        .onAppear { columns = (mapFocus || collapsed) ? .detailOnly : .all }
        .onChange(of: mapFocus) { on in withAnimation(Motion.spring) { columns = (on || collapsed) ? .detailOnly : .all } }
        // Yon menyu tortib yopilsa/ochilsa ham eslab qolinadi
        .onChange(of: columns) { c in if !mapFocus { collapsed = c == .detailOnly } }
        .background {
            Button("") { setCollapsed(columns != .detailOnly) }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .hidden()
        }
    }

    private func setCollapsed(_ on: Bool) {
        collapsed = on
        withAnimation(Motion.spring) { columns = (on || mapFocus) ? .detailOnly : .all }
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

/// Yon menyu: brend, bo'limlar, loyihalar (jonli nuqta va vaqt), pastda ixcham limitlar va Sozlamalar
private struct Sidebar: View {
    @EnvironmentObject var store: Store
    @Binding var section: Section
    var onCollapse: () -> Void = {}
    @AppStorage(GraphScreen.selectedSessionKey) private var sessionId = ""

    var body: some View {
        let snap = store.snap
        VStack(alignment: .leading, spacing: 0) {
            brand(snap).padding(.horizontal, 8).padding(.bottom, 18)

            VStack(spacing: 1) {
                navItem(.overview, "Bugun", "sun.max", key: "1")
                navItem(.sessions, "Sessiyalar", "rectangle.stack", key: "2",
                        live: snap.runningAgents > 0 ? snap.activeSessions : 0)
                navItem(.history, "Tarix", "chart.bar", key: "3")
            }

            Text("Loyihalar")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                .padding(.horizontal, 10).padding(.top, 22).padding(.bottom, 6)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 1) {
                    ForEach(projects, id: \.id) { projectRow($0, waiting: snap.permissionWaits[$0.id] != nil, now: snap.updatedAt) }
                }
            }

            Spacer(minLength: 10)
            limits(snap)
            navItem(.settings, "Sozlamalar", "gearshape", key: ",")
        }
        .padding(.horizontal, 10).padding(.top, 14).padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .top)
        // Oyna tugmalari qatorida, o'ng burchakda — yon menyuni yopish
        .overlay(alignment: .topTrailing) {
            PaneToggle(symbol: "sidebar.left", help: "Yon menyuni yopish (⌃⌘S)", action: onCollapse).padding(.top, 2).padding(.trailing, 8)
                .ignoresSafeArea(.container, edges: .top)
        }
    }

    // MARK: Brend

    private func brand(_ snap: Snapshot) -> some View {
        let waiting = !snap.permissionWaits.isEmpty, running = snap.runningAgents > 0
        let color: Color = waiting ? Brand.warn : (running ? Brand.ok : .secondary)
        return HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text("Token Kuzatuv").font(.system(size: 13.5, weight: .semibold, design: .rounded))
                HStack(spacing: 5) {
                    if running && !waiting { StateDot(state: .running, size: 6) }
                    else { Circle().fill(color.opacity(waiting ? 1 : 0.6)).frame(width: 6, height: 6) }
                    Text(waiting ? "Ruxsat kutyapti" : (running ? "\(snap.activeSessions) sessiya ishlayapti" : "Tinch"))
                }
                .font(.system(size: 11, weight: .medium)).foregroundStyle(color)
            }
        }
        .help("Yangilandi \(Fmt.ago(snap.updatedAt)) · \(snap.filesWatched) fayl kuzatilyapti")
    }

    // MARK: Bo'limlar

    private func navItem(_ s: Section, _ title: String, _ symbol: String, key: KeyEquivalent, live: Int = 0) -> some View {
        let on = section == s
        return Button { withAnimation(Motion.snappy) { section = s } } label: {
            HStack(spacing: 9) {
                Image(systemName: on ? symbol + ".fill" : symbol)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(on ? Brand.accent : .secondary)
                    .frame(width: 18)
                Text(title).font(.system(size: 13, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Color.primary : Color.primary.opacity(0.75))
                Spacer(minLength: 4)
                if live > 0 {
                    HStack(spacing: 4) { StateDot(state: .running, size: 5); Text("\(live)") }
                        .font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Brand.ok)
                }
            }
            .padding(.horizontal, 8).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.accent.opacity(on ? 0.18 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .noFocusRing()
        .keyboardShortcut(key, modifiers: .command)
        .help("\(title) (⌘\(key.character))")
    }

    // MARK: Loyihalar

    /// Har loyihadan eng so'nggi sessiya, ishlayotgani tepada
    private var projects: [SessionSnap] {
        var seen = Set<String>()
        return store.snap.sessions
            .sorted { ($0.state != .idle ? 1 : 0, $0.lastActivity ?? .distantPast) > ($1.state != .idle ? 1 : 0, $1.lastActivity ?? .distantPast) }
            .filter { seen.insert($0.project).inserted }
            .prefix(8).map { $0 }
    }

    private func projectRow(_ sess: SessionSnap, waiting: Bool, now: Date) -> some View {
        let on = section == .graph && sessionId == sess.id
        let running = sess.state != .idle
        return Button {
            sessionId = sess.id
            withAnimation(Motion.snappy) { section = .graph }
        } label: {
            HStack(spacing: 9) {
                ProjectAvatar(name: sess.project, size: 20)
                    .overlay(alignment: .bottomTrailing) {
                        if running || waiting {
                            Circle().fill(waiting ? Brand.warn : Brand.ok)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(Brand.canvas, lineWidth: 2))
                                .offset(x: 3, y: 3)
                        }
                    }
                Text(sess.project).font(.system(size: 13, weight: on ? .semibold : .regular))
                    .foregroundStyle(on ? Color.primary : Color.primary.opacity(0.75)).lineLimit(1)
                Spacer(minLength: 4)
                // Ishlayotganini avatar nuqtasi ko'rsatadi — bu yerda faqat tinch loyihaning vaqti
                if waiting {
                    Text("ruxsat").font(.system(size: 11, weight: .medium)).foregroundStyle(Brand.warn)
                } else if !running {
                    Text(Self.short(sess.lastActivity, now: now))
                        .font(.system(size: 11)).monospacedDigit().foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            .padding(.horizontal, 8).frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Brand.accent.opacity(on ? 0.18 : 0)))
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .noFocusRing()
        .help(running ? (sess.main?.lastAction ?? sess.title) : sess.title)
    }

    /// «5 daq», «3 soat», «2 kun»
    static func short(_ d: Date?, now: Date) -> String {
        guard let d else { return "" }
        let t = max(0, now.timeIntervalSince(d))
        if t < 60 { return "hozir" }
        if t < 3600 { return "\(Int(t / 60)) daq" }
        if t < 86_400 { return "\(Int(t / 3600)) soat" }
        return "\(Int(t / 86_400)) kun"
    }

    // MARK: Limitlar

    @ViewBuilder
    private func limits(_ snap: Snapshot) -> some View {
        let five = snap.limits?.fiveHour, week = snap.limits?.sevenDay
        if five != nil || week != nil {
            VStack(alignment: .leading, spacing: 9) {
                Text("Claude limiti").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                if let five { limitRow("5 soat", five) }
                if let week { limitRow("Hafta", week) }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
            .padding(.bottom, 8)
        }
    }

    private func limitRow(_ title: String, _ w: LimitWindow) -> some View {
        let pct = min(100, max(0, w.usedPercentage))
        let color = pct >= 90 ? Brand.err : (pct >= 70 ? Brand.warn : Brand.accent)
        return HStack(spacing: 8) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 42, alignment: .leading)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color).frame(width: max(3, g.size.width * pct / 100))
                }
            }
            .frame(height: 4)
            Text("\(Int(pct.rounded()))%").font(.system(size: 11, weight: .semibold)).monospacedDigit()
                .foregroundStyle(pct >= 70 ? color : .secondary)
                .frame(width: 32, alignment: .trailing)
        }
        .help("\(title == "Hafta" ? "Haftalik" : "5 soatlik") limit: \(Int(pct.rounded()))% · tiklanadi \(Self.until(w.resetsAt)) dan keyin")
    }

    /// «2 soat 49 daq», bir kundan ko'p bo'lsa — «6 kun 0 soat»
    static func until(_ date: Date) -> String {
        let sec = max(0, date.timeIntervalSinceNow)
        guard sec >= 86_400 else { return Alerts.duration(sec) }
        let days = Int(sec / 86_400), hours = Int(sec.truncatingRemainder(dividingBy: 86_400) / 3600)
        return hours > 0 ? "\(days) kun \(hours) soat" : "\(days) kun"
    }
}


