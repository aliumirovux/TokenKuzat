import SwiftUI
import AppKit
import TokenKuzatCore

/// Menyu satri belgisini bosganda ochiladigan ixcham panel.
struct MenuPanel: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(Pref.budgetEnabled) private var budgetEnabled = false

    var body: some View {
        let s = store.snap
        VStack(spacing: 0) {
            header(s)
            Divider()
            if !s.initialScanDone {
                ProgressView("Yozuvlar o'qilmoqda…").controlSize(.small).padding(40)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        mini("Bugun", Fmt.tokens(s.today.value(mode)))
                        mini("5 soat", Fmt.tokens(s.lastFiveHours.value(mode)))
                        mini("Tezlik", "\(Fmt.tokens(s.rate(mode)))/daq")
                    }
                    if let l = s.limits, !l.isEmpty {
                        RealLimitsView(limits: l, forecast: s.fiveHourForecast, compact: true)
                    } else if budgetEnabled, let b = BudgetStatus.current(s) {
                        BudgetBar(status: b, compact: true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Oxirgi 60 daqiqa").font(.caption).foregroundStyle(.secondary)
                        MinuteChart(points: s.minutes, mode: mode, height: 70, showLegend: false)
                    }
                    sessions(s)
                }
                .padding(14)
            }
            Divider()
            footer
        }
        .frame(width: 380)
    }

    private func header(_ s: Snapshot) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 22, height: 22)
            Text("Token Kuzatuv").font(.headline)
            Spacer()
            StatusPill(running: s.runningAgents, active: s.activeSessions)
            CountModePicker().controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    private func mini(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText())
                .animation(Motion.smooth, value: value)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glass(radius: 12)
    }

    @ViewBuilder
    private func sessions(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sessiyalar").font(.caption).foregroundStyle(.secondary)
            if s.sessions.isEmpty {
                Text("Oxirgi 7 kunda Claude Code sessiyasi yo'q.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(s.sessions.prefix(4)) { sess in
                    Button {
                        WindowManager.shared.show(.graph)
                        UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
                    } label: {
                        HStack(spacing: 8) {
                            StateDot(state: sess.state, size: 7)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(sess.project).font(.callout.weight(.medium)).lineLimit(1)
                                Text(sess.main?.lastAction ?? sess.title).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer(minLength: 6)
                            VStack(alignment: .trailing, spacing: 1) {
                                Text(Fmt.tokens(sess.tokens.value(mode))).font(.callout).monospacedDigit()
                                Text(Fmt.ago(sess.lastActivity)).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 5).padding(.horizontal, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowButtonStyle())
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Button { WindowManager.shared.show() } label: {
                Label("Oynani ochish", systemImage: "macwindow")
            }
            Spacer()
            Button { WindowManager.shared.show(.settings) } label: { Image(systemName: "gearshape") }
                .help("Sozlamalar")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .help("Chiqish")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14).padding(.vertical, 9)
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
