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
                VStack(spacing: 12) {
                    process(s)
                    stats(s)
                }
                .padding(12)
                Divider()
                projects(s)
            }
            footer
        }
        .frame(width: 372)
        // Butun panel bir xil qattiq fonda — tagidagi oyna/rasm ko'rinmaydi
        .background(Brand.canvas)
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
                VStack(alignment: .leading, spacing: 10) {
                    LimitBarRow(title: "Joriy sessiya", window: w, dark: true)
                    if let wk = s.limits?.sevenDay {
                        LimitBarRow(title: "Bu hafta", window: wk, dark: true)
                        if let warn = LimitText.weekWarning(s.weekForecast, week: wk) {
                            Label(warn, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.weight(.medium)).foregroundStyle(Color(light: 0xFFC46B, dark: 0xFFC46B))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let l = s.limits, let stale = LimitText.staleNote(l, now: s.updatedAt) {
                        Label(stale, systemImage: "clock.arrow.circlepath")
                            .font(.caption2).foregroundStyle(Brand.inkDim)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, 12)
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

    /// Jarayon: hozir ishlayotgan (yoki eng so'nggi) sessiyaning joriy so'rovi — holat, matn, qadamlar izi va hozirgi qadam
    @ViewBuilder
    private func process(_ s: Snapshot) -> some View {
        let active = s.sessions.first { $0.state != .idle }
        if let sess = active ?? s.sessions.first, let turn = sess.turns.last {
            let waiting = s.permissionWaits[sess.id]
            let live = active != nil
            let steps = sess.agents.flatMap(\.steps).filter { $0.turn == turn.id }.sorted { $0.date < $1.date }
            let notes = sess.notes.filter { $0.turn == turn.id && !($0.kind == .thinking && $0.text.isEmpty) }
            let running = steps.last { $0.status == .running }
            let color: Color = waiting != nil ? Brand.warn : (live ? Brand.ok : .secondary)
            let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
            Button {
                UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
                WindowManager.shared.show(.graph)
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ProjectAvatar(name: sess.project, size: 20)
                        Text(sess.project).font(.caption.weight(.semibold))
                        Text("#\(turn.id)").font(.caption.weight(.bold)).monospacedDigit().foregroundStyle(Brand.accent)
                        Spacer()
                        HStack(spacing: 5) {
                            if waiting != nil { Image(systemName: "hand.raised.fill") }
                            else if live { StateDot(state: .running, size: 6) }
                            else { Image(systemName: "checkmark.circle.fill") }
                            Text(waiting != nil ? "Ruxsat kutyapti" : (live ? "Ishlayapti" : "Tugadi · " + Fmt.ago(sess.lastActivity)))
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(color)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(0.12)))
                    }
                    Text(turn.shownPrompt).font(.callout.weight(.semibold)).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    MiniTrace(steps: Array(steps.suffix(14)), notes: notes, live: live)
                        .frame(height: 46)
                    // Hozirgi qadam (yoki oxirgi harakat) — taymer bilan
                    HStack(spacing: 8) {
                        let cat = running?.category
                        Image(systemName: waiting != nil ? "hand.raised.fill" : (running?.symbol ?? (live ? "brain" : "text.bubble.fill")))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(waiting != nil ? Brand.warn : (cat?.iconColor ?? Brand.inkFill))
                            .frame(width: 24, height: 24)
                            .background(Circle().fill((cat?.color ?? Brand.inkFill).opacity(0.15)))
                        Text(waiting.map { Alerts.uz($0.message) } ?? running?.text ?? (live ? "O'ylayapti…" : (sess.main?.lastAction ?? "")))
                            .font(.caption).lineLimit(1)
                        Spacer(minLength: 6)
                        if let r = running {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text(Alerts.duration(ctx.date.timeIntervalSince(r.date)))
                                    .font(.system(size: 12, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        meta("list.bullet", "\(turn.steps) qadam")
                        meta("clock", Alerts.duration(turn.duration))
                        meta("circle.hexagongrid", Fmt.tokens(turn.tokens.value(mode)))
                        Spacer()
                        if sess.contextTokens > 0 {
                            let f = sess.contextFraction
                            meta("gauge.with.dots.needle.50percent", "\(Int((f * 100).rounded()))% kontekst")
                                .foregroundStyle(f >= 0.8 ? Brand.warn : .secondary)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(shape.fill(Brand.surface))
                .overlay(shape.stroke(Brand.line))
                .overlay { if live { LiveBorder(shape: shape, color: color, lineWidth: 1.6, period: 3.6) } }
                .contentShape(shape)
            }
            .buttonStyle(.plain)
            .help("Bosing — sessiya xaritada ochiladi")
        }
    }

    private func meta(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) { Image(systemName: symbol); Text(text) }
            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
    }

    /// Bugungi qisqa xulosa — uchta plitka
    private func stats(_ s: Snapshot) -> some View {
        let todaySessions = s.sessions.filter { Calendar.current.isDateInToday($0.lastActivity ?? .distantPast) }.count
        return HStack(spacing: 8) {
            tile("Bugun", Fmt.tokens(s.today.value(mode)), "token")
            tile("Faol vaqt", Alerts.duration(Double(s.activeMinutesToday) * 60), "bugun")
            tile("Sessiyalar", "\(todaySessions)", s.runningAgents > 0 ? "\(s.runningAgents) ishlayapti" : "tinch")
        }
    }

    private func tile(_ k: String, _ v: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(k).font(.caption2).foregroundStyle(.secondary)
            Text(v).font(.system(size: 16, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText()).animation(Motion.smooth, value: v)
            Text(sub).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(radius: 12)
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

/// Kichik jarayon izi (xaritadagi kabi): mahalliy ishlar (fayllar, terminal) — yuqorida, tashqilari — pastda,
/// model (o'ylash, javob) — o'rtada; hodisalar chapdan o'ngga silliq chiziq bilan ulanadi
private struct MiniTrace: View {
    let steps: [StepSnap]
    let notes: [NoteSnap]
    let live: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Item { case step(StepSnap), note(NoteSnap) }

    var body: some View {
        let items: [(Date, Item)] = (steps.map { ($0.date, Item.step($0)) } + notes.map { ($0.date, Item.note($0)) })
            .sorted { $0.0 < $1.0 }.suffix(16).map { $0 }
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { ctx in
            Canvas { g, size in
                guard !items.isEmpty else { return }
                let mid = size.height / 2, off = size.height / 2 - 9
                let dx = items.count > 1 ? min(26, (size.width - 20) / CGFloat(items.count - 1)) : 0
                func y(_ it: Item) -> CGFloat {
                    switch it {
                    case .note: return mid
                    case .step(let s):
                        switch s.category {
                        case .files, .shell, .other: return mid - off
                        default: return mid + off
                        }
                    }
                }
                let pts = items.enumerated().map { CGPoint(x: 10 + CGFloat($0.offset) * dx, y: y($0.element.1)) }
                // O'rta chiziq — model
                var base = Path(); base.move(to: CGPoint(x: 0, y: mid)); base.addLine(to: CGPoint(x: size.width, y: mid))
                g.stroke(base, with: .color(Color.primary.opacity(0.06)), lineWidth: 1)
                for i in 1..<max(1, pts.count) where pts.count > 1 {
                    let a = pts[i - 1], b = pts[i]
                    var p = Path(); p.move(to: a)
                    let mx = (a.x + b.x) / 2
                    p.addCurve(to: b, control1: CGPoint(x: mx, y: a.y), control2: CGPoint(x: mx, y: b.y))
                    if live && i == pts.count - 1 && !reduceMotion {
                        DataFlow.draw(&g, path: p, color: Brand.ok, t: ctx.date.timeIntervalSinceReferenceDate, seed: 0.2, width: 1.6, duplex: false)
                    } else {
                        g.stroke(p, with: .color(Color.primary.opacity(0.25)), lineWidth: 1.4)
                    }
                }
                for (i, (_, it)) in items.enumerated() {
                    let p = pts[i]
                    switch it {
                    case .note(let n):
                        let r: CGFloat = n.kind == .reply ? 5 : 4
                        let c = n.kind == .reply ? Brand.ok : Brand.inkFill
                        let e = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        if n.kind == .reply { g.fill(e, with: .color(c)) } else { g.stroke(e, with: .color(c), lineWidth: 1.4) }
                    case .step(let s):
                        let r: CGFloat = 7
                        let c = s.status == .failed ? Brand.err : s.category.color
                        let e = Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
                        g.fill(e, with: .color(Brand.surface))
                        g.fill(e, with: .color(c.opacity(0.2)))
                        g.stroke(e, with: .color(c), lineWidth: 1.2)
                        g.draw(Text(Image(systemName: s.status == .failed ? "xmark" : s.symbol))
                                .font(.system(size: 7, weight: .bold)).foregroundColor(s.category == .shell ? Color.secondary : c), at: p)
                        if s.status == .running && !reduceMotion {
                            let k = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.4) / 1.4
                            let rr = r + 2 + CGFloat(k) * 6
                            g.stroke(Path(ellipseIn: CGRect(x: p.x - rr, y: p.y - rr, width: rr * 2, height: rr * 2)),
                                     with: .color(c.opacity(0.6 * (1 - k))), lineWidth: 1.2)
                        }
                    }
                }
            }
        }
        .overlay(alignment: .leading) {
            if items.isEmpty {
                Text("Hali qadam yo'q").font(.caption2).foregroundStyle(.tertiary).padding(.leading, 4)
            }
        }
        .accessibilityLabel("So'nggi \(items.count) ta hodisa")
    }
}
