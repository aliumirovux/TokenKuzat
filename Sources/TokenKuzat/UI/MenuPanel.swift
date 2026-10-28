import SwiftUI
import AppKit
import TokenKuzatCore

/// Menyu satri paneli: tepada to'q blok — limit qancha qoldi (katta raqam) va 5 soatlik oyna;
/// ostida «Hozir», bugungi qisqa xulosa va so'nggi loyihalar.
struct MenuPanel: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw

    var body: some View {
        let s = store.snap
        VStack(spacing: 0) {
            if !s.initialScanDone {
                ProgressView("Yozuvlar o'qilmoqda…").controlSize(.small).padding(40)
            } else {
                hero(s)
                now(s)
                Divider()
                VStack(spacing: 6) {
                    line("Bugun", "\(Fmt.tokens(s.today.value(mode))) token" + (s.limits?.costBySession.isEmpty == false ? "" : ""))
                    line("Faol vaqt", Alerts.duration(Double(s.activeMinutesToday) * 60))
                    line("Sessiyalar", "\(s.sessions.filter { Calendar.current.isDateInToday($0.lastActivity ?? .distantPast) }.count)" + (s.runningAgents > 0 ? " · \(s.runningAgents) ishlayapti" : ""))
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                Divider()
                projects(s)
            }
            footer
        }
        .frame(width: 372)
    }

    // MARK: Qismlar

    @ViewBuilder
    private func hero(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let w = s.limits?.fiveHour {
                HStack {
                    Text("5 SOATLIK LIMIT").eyebrow(Brand.inkDim)
                    Spacer()
                    forecast(s.fiveHourForecast)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    DisplayNumber(value: max(0, 100 - Int(w.usedPercentage.rounded())), size: 50, color: .white)
                    Text("qoldi").foregroundStyle(Brand.inkDim)
                }
                (Text("↻ \(Fmt.hourMinute.string(from: w.resetsAt)) · ").foregroundColor(Brand.inkDim)
                 + Text(Alerts.duration(max(0, w.resetsAt.timeIntervalSinceNow))).foregroundColor(.white).bold()
                 + Text(s.limits?.sevenDay.map { " · hafta \(max(0, 100 - Int($0.usedPercentage.rounded())))%" } ?? "").foregroundColor(Brand.inkDim))
                    .font(.caption)
                MiniWindow(window: w, minutes: s.recentMinutes).frame(height: 34).padding(.top, 6)
            } else {
                Text("BUGUN").eyebrow(Brand.inkDim)
                Text(Fmt.tokens(s.today.value(mode)))
                    .font(.system(size: 44, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Button("Claude limitini ulash…") { WindowManager.shared.show(.settings) }
                    .buttonStyle(.link).tint(Brand.inkFill).font(.caption.weight(.semibold))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.ink)
    }

    private func forecast(_ f: LimitForecast.Outcome) -> some View {
        let (t, c): (String, Color) = {
            switch f {
            case .runsOut(let at): return ("~\(Fmt.hourMinute.string(from: at)) da tugaydi", Color(light: 0xFFC46B, dark: 0xFFC46B))
            case .lasts: return ("Yetadi", Color(light: 0x7CF0B6, dark: 0x7CF0B6))
            case .unknown: return ("", .clear)
            }
        }()
        return HStack(spacing: 5) {
            if !t.isEmpty { Circle().fill(c).frame(width: 6, height: 6) }
            Text(t)
        }
        .font(.caption.weight(.semibold)).foregroundStyle(c)
    }

    @ViewBuilder
    private func now(_ s: Snapshot) -> some View {
        if let sess = s.sessions.first(where: { $0.state != .idle }) {
            let running = sess.agents.flatMap(\.steps).filter { $0.status == .running }.max { $0.date < $1.date }
            Button {
                UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
                WindowManager.shared.show(.graph)
            } label: {
                HStack(spacing: 12) {
                    ToolTile(symbol: running?.category.symbol ?? "sparkles", color: running?.category.color ?? Brand.accent, size: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(running?.targetName.isEmpty == false ? running!.targetName : (sess.main?.lastAction ?? "Ishlayapti…"))
                            .font(.callout.weight(.semibold)).lineLimit(1)
                        Text("\(sess.project)" + (sess.turns.last.map { " · #\($0.id)" } ?? ""))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let d = running?.duration {
                        Text(Alerts.duration(d)).font(.system(size: 14, weight: .semibold, design: .monospaced))
                    } else {
                        StateDot(state: .running, size: 7)
                    }
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(RowButtonStyle())
        }
    }

    private func line(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(.secondary)
            Spacer()
            Text(v).fontWeight(.semibold).monospacedDigit()
                .contentTransition(.numericText()).animation(Motion.smooth, value: v)
        }
        .font(.callout)
    }

    private func projects(_ s: Snapshot) -> some View {
        var seen = Set<String>()
        let list = s.sessions.filter { seen.insert($0.project).inserted }.prefix(3)
        return VStack(spacing: 0) {
            ForEach(Array(list)) { sess in
                Button {
                    UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
                    WindowManager.shared.show(.graph)
                } label: {
                    HStack(spacing: 10) {
                        ProjectAvatar(name: sess.project, size: 22)
                        Text(sess.project).font(.callout).lineLimit(1)
                        if sess.state != .idle { StateDot(state: sess.state, size: 6) }
                        Spacer()
                        Text(Fmt.tokens(sess.tokens.value(mode))).font(.callout.weight(.medium)).monospacedDigit()
                        Text(Fmt.ago(sess.lastActivity)).font(.caption).foregroundStyle(.tertiary).frame(width: 74, alignment: .trailing)
                    }
                    .padding(.horizontal, 18).padding(.vertical, 7)
                    .contentShape(Rectangle())
                }
                .buttonStyle(RowButtonStyle())
            }
        }
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Button("Token Kuzatuv'ni ochish") { WindowManager.shared.show() }
                .buttonStyle(.link).tint(Brand.accent).font(.callout.weight(.semibold))
            Spacer()
            Button { WindowManager.shared.show(.settings) } label: { Image(systemName: "gearshape") }.help("Sozlamalar")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.help("Chiqish")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Brand.sunken)
    }
}

/// Menyu panelidagi 5 soatlik oyna — 5 ta kichik ustun (o'tgan / hozir / kelajak)
private struct MiniWindow: View {
    let window: LimitWindow
    let minutes: [MinutePoint]

    var body: some View {
        let start = window.resetsAt.addingTimeInterval(-5 * 3600)
        let now = Date()
        var w = Array(repeating: 0.0, count: 5)
        for m in minutes where m.date >= start && m.date < window.resetsAt {
            w[min(4, Int(m.date.timeIntervalSince(start) / 3600))] += m.main.weighted + m.agents.weighted
        }
        let mx = max(w.max() ?? 1, 1)
        return HStack(alignment: .bottom, spacing: 5) {
            ForEach(0..<5, id: \.self) { i in
                let a = start.addingTimeInterval(Double(i) * 3600)
                let cur = now >= a && now < a.addingTimeInterval(3600)
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(.white.opacity(now < a ? 0.04 : 0.08))
                    GeometryReader { g in
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Brand.inkFill)
                                .frame(height: w[i] > 0 ? max(3, g.size.height * CGFloat(w[i] / mx)) : 0)
                        }
                    }
                }
                .overlay { if cur { RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(.white.opacity(0.5), lineWidth: 1) } }
            }
        }
    }
}

/// Bosilganda va ustiga kelganda yengil fon beradigan qator tugmasi
struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowBody(configuration: configuration)
    }

    private struct RowBody: View {
        let configuration: Configuration
        @State private var hover = false
        var body: some View {
            configuration.label
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.10 : (hover ? 0.06 : 0))))
                .scaleEffect(configuration.isPressed ? 0.985 : 1)
                .animation(Motion.snappy, value: hover)
                .animation(Motion.snappy, value: configuration.isPressed)
                .onHover { hover = $0 }
        }
    }
}
