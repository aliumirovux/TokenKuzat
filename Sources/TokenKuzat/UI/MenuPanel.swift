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
                limits(s)
                VStack(spacing: 10) {
                    now(s)
                    today(s)
                }
                .padding(12)
                Divider()
                projects(s)
            }
            footer
        }
        .frame(width: 372)
        // Butun panel bir xil qattiq fonda, oyna chetlarigacha — tagidagi rasm ko'rinmaydi
        .background(Brand.canvas.ignoresSafeArea())
    }

    // MARK: Limit

    /// Asosiy qism: ikki halqa (sessiya va hafta) — ikkalasi ham «ishlatildi», Claude sahifasidagidek; ostida bitta xulosa
    @ViewBuilder
    private func limits(_ s: Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.dots.needle.67percent").foregroundStyle(Brand.inkFill)
                Text("Claude" + (s.limits?.plan.map { " · " + $0 } ?? "")).font(.callout.weight(.semibold)).foregroundStyle(.white)
                Spacer()
                if s.rate(mode) > 0 && s.runningAgents > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "bolt.fill")
                        Text("\(Fmt.tokens(s.rate(mode)))/daq").monospacedDigit()
                    }
                    .font(.caption.weight(.semibold)).foregroundStyle(Color(light: 0x7CF0B6, dark: 0x7CF0B6))
                }
            }
            if let l = s.limits, let w = l.fiveHour {
                HStack(spacing: 12) {
                    LimitRing(title: "Sessiya", window: w, caption: "5 soatlik oyna")
                    if let wk = l.sevenDay {
                        LimitRing(title: "Hafta", window: wk, caption: "7 kunlik oyna")
                    }
                }
                paceLine(s, l)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bugun \(Fmt.tokens(s.today.value(mode))) token").font(.title3.weight(.semibold)).foregroundStyle(.white)
                    Text("Haqiqiy limitni ko'rish uchun Claude hisobini ulang.").font(.caption).foregroundStyle(Brand.inkDim)
                    Button("Sozlamalarni ochish…") { WindowManager.shared.show(.settings) }
                        .buttonStyle(.link).tint(Brand.inkFill).font(.caption.weight(.semibold))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.ink)
    }

    /// Bitta jumla: shu sur'at bilan nima bo'ladi
    private func paceLine(_ s: Snapshot, _ l: RateLimits) -> some View {
        let warnColor = Color(light: 0xFFC46B, dark: 0xFFC46B)
        let okColor = Color(light: 0x7CF0B6, dark: 0x7CF0B6)
        let (symbol, text, color): (String, String, Color) = {
            if case .runsOut(let at) = s.fiveHourForecast {
                return ("exclamationmark.triangle.fill", "Sessiya ~\(Fmt.hourMinute.string(from: at)) da tugaydi — tiklanishidan oldin", warnColor)
            }
            if let wk = l.sevenDay, let w = LimitText.weekWarning(s.weekForecast, week: wk) {
                return ("exclamationmark.triangle.fill", w, warnColor)
            }
            if let stale = LimitText.staleNote(l, now: s.updatedAt) { return ("clock.arrow.circlepath", stale, Brand.inkDim) }
            return ("checkmark.circle.fill", "Sur'at me'yorida — limit tiklanguncha yetadi", okColor)
        }()
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).font(.caption)
            Text(text).font(.caption.weight(.medium)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(color.opacity(0.12)))
    }

    // MARK: Hozir

    /// Hozir nima bo'lyapti: loyiha va so'rov, katta harfda joriy harakat (taymer bilan), nomli jarayon izi
    @ViewBuilder
    private func now(_ s: Snapshot) -> some View {
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
                VStack(alignment: .leading, spacing: 12) {
                    // Sarlavha: holat — eng birinchi ko'rinadigan narsa
                    HStack(spacing: 6) {
                        if waiting != nil { Image(systemName: "hand.raised.fill") }
                        else if live { StateDot(state: .running, size: 7) }
                        else { Image(systemName: "checkmark.circle.fill") }
                        Text(waiting != nil ? "RUXSATINGIZNI KUTYAPTI" : (live ? "HOZIR ISHLAYAPTI" : "OXIRGI ISH · " + Fmt.ago(sess.lastActivity).uppercased()))
                            .eyebrow(color)
                        Spacer()
                        ProjectAvatar(name: sess.project, size: 16)
                        Text("\(sess.project) #\(turn.id)").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    // Joriy harakat — katta
                    HStack(spacing: 12) {
                        let cat = running?.category
                        ToolTile(symbol: waiting != nil ? "hand.raised.fill" : (running?.symbol ?? (live ? "brain" : "checkmark")),
                                 color: waiting != nil ? Brand.warn : (cat?.color ?? Brand.accent), size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(actionTitle(running: running, waiting: waiting, live: live))
                                .font(.body.weight(.semibold)).lineLimit(1)
                            Text(actionDetail(running: running, waiting: waiting, live: live, turn: turn))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        if let r = running {
                            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                                Text(Alerts.duration(ctx.date.timeIntervalSince(r.date)))
                                    .font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                        }
                    }
                    // Jarayon izi — yo'lak nomlari bilan
                    MiniTrace(steps: Array(steps.suffix(14)), notes: notes, live: live)
                        .frame(height: 58)
                    HStack(spacing: 12) {
                        meta("list.bullet", "\(turn.steps) qadam")
                        meta("clock", Alerts.duration(turn.duration))
                        meta("circle.hexagongrid", Fmt.tokens(turn.tokens.value(mode)))
                        Spacer()
                        if sess.contextTokens > 0 {
                            let f = sess.contextFraction
                            meta("text.alignleft", "kontekst \(Int((f * 100).rounded()))%")
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

    /// «Terminal», «Fayllar», «O'ylayapti…» — nima bo'lyapti, bir so'zda
    private func actionTitle(running: StepSnap?, waiting: HookNotice?, live: Bool) -> String {
        if waiting != nil { return "Ruxsat kerak" }
        if let r = running { return r.category.title }
        return live ? "O'ylayapti…" : "Javob berdi"
    }

    /// Batafsil: qaysi buyruq/fayl yoki so'rov matni
    private func actionDetail(running: StepSnap?, waiting: HookNotice?, live: Bool, turn: TurnSnap) -> String {
        if let w = waiting { return Alerts.uz(w.message) }
        if let r = running {
            let t = r.text
            if let range = t.range(of: " · ") { return String(t[range.upperBound...]) }
            return t
        }
        return turn.shownPrompt
    }

    private func meta(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 4) { Image(systemName: symbol); Text(text) }
            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
    }

    // MARK: Bugun

    /// Bitta ixcham qator: bugungi tokenlar, faol vaqt, sessiyalar
    private func today(_ s: Snapshot) -> some View {
        let todaySessions = s.sessions.filter { Calendar.current.isDateInToday($0.lastActivity ?? .distantPast) }.count
        return HStack(spacing: 0) {
            todayItem("Bugun", Fmt.tokens(s.today.value(mode)), "token")
            Divider().frame(height: 26)
            todayItem("Faol", Alerts.duration(Double(s.activeMinutesToday) * 60), "vaqt")
            Divider().frame(height: 26)
            todayItem("Sessiya", "\(todaySessions)", s.runningAgents > 0 ? "\(s.runningAgents) ishlayapti" : "bugun")
        }
        .padding(.vertical, 10)
        .surface(radius: 12)
    }

    private func todayItem(_ k: String, _ v: String, _ sub: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.system(size: 15, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText()).animation(Motion.smooth, value: v)
            Text("\(k) · \(sub)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
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
        HStack(spacing: 6) {
        // Yo'lak nomlari: chizmaning qaysi qatori nimani bildiradi
        VStack(alignment: .trailing, spacing: 0) {
            Text("Mahalliy").frame(maxHeight: .infinity)
            Text("Model").frame(maxHeight: .infinity)
            Text("Tashqi").frame(maxHeight: .infinity)
        }
        .font(.system(size: 8.5, weight: .medium)).foregroundStyle(.tertiary)
        .frame(width: 42, alignment: .trailing)
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live || reduceMotion)) { ctx in
            Canvas { g, size in
                guard !items.isEmpty else { return }
                // Uchta teng yo'lak: tepada mahalliy, o'rtada model, pastda tashqi
                let mid = size.height / 2, off = size.height / 3
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
        }
        .accessibilityLabel("So'nggi \(items.count) ta hodisa")
    }
}

/// Limit halqasi: markazda «46%» va «ishlatildi», ostida nomi va qachon tiklanishi
private struct LimitRing: View {
    let title: String
    let window: LimitWindow
    let caption: String

    /// «31 daq», «4 soat 10 daq», «6 kun 3 soat»
    static func left(_ t: TimeInterval) -> String {
        let t = max(0, t)
        if t >= 2 * 86400 { return "\(Int(t) / 86400) kun" }
        if t >= 86400 { return "1 kun \((Int(t) % 86400) / 3600) soat" }
        return Alerts.duration(t)
    }

    var body: some View {
        let pct = min(100, max(0, window.usedPercentage))
        let color: Color = pct >= 90 ? Brand.err : (pct >= 75 ? Color(light: 0xFFC46B, dark: 0xFFC46B) : Brand.inkFill)
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(.white.opacity(0.1), lineWidth: 8)
                Circle().trim(from: 0, to: pct / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: -2) {
                    Text("\(Int(pct.rounded()))%").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                    Text("ishlatildi").font(.system(size: 8.5, weight: .medium)).foregroundStyle(Brand.inkDim)
                }
            }
            .frame(width: 64, height: 64)
            .animation(Motion.smooth, value: pct)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.callout.weight(.semibold)).foregroundStyle(.white)
                Text("↻ " + LimitText.dayTime(window.resetsAt)).font(.caption).foregroundStyle(Brand.inkDim)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Text(Self.left(window.resetsAt.timeIntervalSinceNow) + " qoldi").font(.caption2)
                    .foregroundStyle(Brand.inkDim.opacity(0.8)).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help("\(title) (\(caption)): \(Int(pct.rounded()))% ishlatildi, \(LimitText.dayTime(window.resetsAt)) da tiklanadi")
    }
}
