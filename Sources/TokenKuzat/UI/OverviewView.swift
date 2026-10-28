import SwiftUI
import TokenKuzatCore

// «Bugun» — bir qarashda uchta savolga javob:
// 1) limit qancha qoldi va qachon tiklanadi (qahramon blok, 5 soatlik oyna soatma-soat);
// 2) hozir nima bo'lyapti («Hozir» qatori);
// 3) bugun nima ustida ishlandi (bento ko'rsatkichlar va sessiyalar).

struct OverviewView: View {
    @EnvironmentObject var store: Store
    @AppStorage(Pref.countMode) private var mode = CountMode.raw
    @AppStorage(Pref.budgetEnabled) private var budgetEnabled = false

    var body: some View {
        let s = store.snap
        ScrollView {
            if !s.initialScanDone {
                ProgressView("Yozuvlar o'qilmoqda…").padding(80)
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    if let l = s.limits, let w = l.sessionWindow {
                        LimitHero(window: w, week: l.sevenDay, forecast: s.fiveHourForecast, minutes: s.recentMinutes,
                                  days: s.days, weekForecast: s.weekForecast, plan: l.plan, stale: LimitText.staleNote(l, now: s.updatedAt))
                    } else {
                        ConnectHero(today: s.today, mode: mode)
                        if budgetEnabled, let b = BudgetStatus.current(s) { BudgetBar(status: b).card() }
                    }
                    NowRow(snap: s, mode: mode)
                    if let sess = s.sessions.first(where: { $0.state != .idle }) ?? s.sessions.first {
                        SavingsCard(session: sess)
                    }
                    TodayBento(snap: s, mode: mode)
                    sessions(s)
                }
                .padding(.horizontal, 24).padding(.top, 4).padding(.bottom, 28)
            }
        }
    }

    @ViewBuilder
    private func sessions(_ s: Snapshot) -> some View {
        let today = Calendar.current.startOfDay(for: s.updatedAt)
        let list = s.sessions.filter { ($0.lastActivity ?? .distantPast) >= today || $0.state != .idle }
        let shown = list.isEmpty ? Array(s.sessions.prefix(3)) : Array(list.prefix(6))
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.isEmpty ? "So'nggi sessiyalar" : "Bugun nima ustida ishlandi")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                Button("Barcha sessiyalar") { WindowManager.shared.show(.sessions) }
                    .buttonStyle(.link).font(.callout.weight(.medium)).tint(Brand.accent)
            }
            if shown.isEmpty {
                EmptyStateView(symbol: "moon.zzz", title: "Hali sessiya yo'q",
                               text: "Claude Code yoki Cowork'da ish boshlansa, shu yerda jonli ko'rinadi.")
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { i, sess in
                        if i > 0 { Divider().padding(.leading, 66) }
                        SessionLine(session: sess, mode: mode, now: s.updatedAt)
                    }
                }
                .card(padding: 4)
            }
        }
    }
}

// MARK: - Limit qahramoni

/// To'q siyoh blok: qolgan foiz (katta), tiklanish vaqti, bashorat, hafta va 5 soatlik oyna soatma-soat
struct LimitHero: View {
    let window: LimitWindow
    let week: LimitWindow?
    let forecast: LimitForecast.Outcome
    let minutes: [MinutePoint]
    var days: [DayPoint] = []
    var weekForecast: LimitForecast.Outcome = .unknown
    var plan: String? = nil
    /// Ma'lumot eskirgan bo'lsa — ogohlantirish matni
    var stale: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tor oynada — sarlavha va bashorat ustma-ust, kartalar ham ustma-ust (kesilib qolmasin)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    Text("CLAUDE LIMITI" + (plan.map { " · " + $0.uppercased() } ?? "")).eyebrow(Brand.inkDim)
                    Spacer(minLength: 12)
                    paceLine
                }
                VStack(alignment: .leading, spacing: 10) {
                    Text("CLAUDE LIMITI" + (plan.map { " · " + $0.uppercased() } ?? "")).eyebrow(Brand.inkDim)
                    paceLine
                }
            }
            // Asosiy: ikki katta karta — ikkalasi ham «ishlatildi», Claude sahifasidagidek
            AdaptiveStack(spacing: 16) {
                LimitCard(title: "Joriy sessiya", subtitle: "5 soatlik oyna", window: window,
                          columns: hourColumns, columnsTitle: "soatlar bo'yicha")
                if let week {
                    LimitCard(title: "Bu hafta", subtitle: "7 kunlik oyna", window: week,
                              columns: dayColumns(week), columnsTitle: "kunlar bo'yicha")
                }
            }
        }
        .padding(22)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Brand.ink))
    }

    /// Bitta xulosa: sessiya yoki hafta shu sur'atda tugaydimi
    private var paceLine: some View {
        let warn = Color(light: 0xFFC46B, dark: 0xFFC46B), ok = Color(light: 0x7CF0B6, dark: 0x7CF0B6)
        let (symbol, text, color): (String, String, Color) = {
            if case .runsOut(let at) = forecast {
                return ("exclamationmark.triangle.fill", "Sessiya ~\(Fmt.hourMinute.string(from: at)) da tugaydi — tiklanishidan oldin", warn)
            }
            if let week, let w = LimitText.weekWarning(weekForecast, week: week) { return ("exclamationmark.triangle.fill", w, warn) }
            if let stale { return ("clock.arrow.circlepath", stale, Brand.inkDim) }
            return ("checkmark.circle.fill", "Sur'at me'yorida — limit tiklanguncha yetadi", ok)
        }()
        return HStack(spacing: 7) {
            Image(systemName: symbol)
            Text(text).lineLimit(1).minimumScaleFactor(0.85)
        }
        .font(.callout.weight(.semibold)).foregroundStyle(color)
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(Capsule().fill(color.opacity(0.13)))
    }

    /// Sessiya oynasining 5 soati: har soatda limitdan ulush (token vaznlari bo'yicha taqsimlangan)
    private var hourColumns: [LimitCard.Column] {
        guard !window.isNotStarted else { return [] }
        let start = window.resetsAt.addingTimeInterval(-5 * 3600)
        let now = Date()
        var w = Array(repeating: 0.0, count: 5)
        for m in minutes where m.date >= start && m.date < window.resetsAt {
            w[min(4, Int(m.date.timeIntervalSince(start) / 3600))] += m.main.weighted + m.agents.weighted
        }
        let total = w.reduce(0, +)
        return (0..<5).map { i in
            let a = start.addingTimeInterval(Double(i) * 3600)
            let state: LimitCard.Column.State = now >= a.addingTimeInterval(3600) ? .past : (now >= a ? .now : .future)
            let pct = total > 0 ? w[i] / total * window.usedPercentage : 0
            return .init(id: i, value: w[i], label: Fmt.hourMinute.string(from: a), state: state,
                         help: state == .future ? "Hali kelmagan soat" : "\(Fmt.hourMinute.string(from: a)) — limitning ~\(Int(pct.rounded()))%")
        }
    }

    /// Hafta oynasining kunlari: har kungi token (kunlik tarixdan)
    private func dayColumns(_ wk: LimitWindow) -> [LimitCard.Column] {
        let cal = Calendar.current
        // Oyna kechqurun boshlansa — birinchi to'liq kundan; jami 7 kun
        let start = cal.startOfDay(for: wk.resetsAt.addingTimeInterval(-WeeklyForecast.window + 12 * 3600))
        let today = cal.startOfDay(for: Date())
        let byDay = Dictionary(days.map { (cal.startOfDay(for: $0.date), $0.tokens.weighted) }, uniquingKeysWith: +)
        let short = ["Ya", "Du", "Se", "Ch", "Pa", "Ju", "Sh"]
        return (0..<7).compactMap { i -> LimitCard.Column? in
            guard let d = cal.date(byAdding: .day, value: i, to: start), d <= wk.resetsAt else { return nil }
            let state: LimitCard.Column.State = d < today ? .past : (d == today ? .now : .future)
            return .init(id: i, value: byDay[d] ?? 0, label: short[cal.component(.weekday, from: d) - 1], state: state,
                         help: state == .future ? "Hali kelmagan kun" : LimitText.date(d))
        }
    }
}

/// Katta limit kartasi: katta halqa va foiz, tiklanish vaqti, qancha qolgani va ixcham ustunlar
private struct LimitCard: View {
    struct Column: Identifiable {
        enum State { case past, now, future }
        let id: Int
        let value: Double
        let label: String
        let state: State
        let help: String
    }

    let title: String
    let subtitle: String
    let window: LimitWindow
    let columns: [Column]
    let columnsTitle: String

    var body: some View {
        let pct = min(100, max(0, window.usedPercentage))
        let color: Color = pct >= 90 ? Brand.err : (pct >= 75 ? Color(light: 0xFFC46B, dark: 0xFFC46B) : Brand.inkFill)
        HStack(alignment: .center, spacing: 22) {
            ZStack {
                Circle().stroke(.white.opacity(0.09), lineWidth: 14)
                Circle().trim(from: 0, to: pct / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(pct.rounded()))%").font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText()).animation(Motion.smooth, value: pct)
                    Text("ishlatildi").font(.caption.weight(.medium)).foregroundStyle(Brand.inkDim)
                }
            }
            .frame(width: 136, height: 136)
            .animation(Motion.smooth, value: pct)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.title2.weight(.semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.caption).foregroundStyle(Brand.inkDim)
                }
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text(window.isNotStarted ? "Yangi oyna birinchi so'rov bilan boshlanadi" : LimitText.dayTime(window.resetsAt) + " da tiklanadi")
                }
                .font(.callout.weight(.medium)).foregroundStyle(.white.opacity(0.9))
                Text(window.isNotStarted ? "limit to'liq" : Self.left(window.resetsAt.timeIntervalSinceNow) + " qoldi")
                    .font(.callout).foregroundStyle(Brand.inkDim)
                Spacer(minLength: 8)
                MiniColumns(columns: columns).frame(height: 44)
                Text(columnsTitle).font(.caption2).foregroundStyle(Brand.inkDim.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.07)))
    }

    /// «25 daq», «4 soat 10 daq», «6 kun»
    static func left(_ t: TimeInterval) -> String {
        let t = max(0, t)
        if t >= 2 * 86400 { return "\(Int(t) / 86400) kun" }
        if t >= 86400 { return "1 kun \((Int(t) % 86400) / 3600) soat" }
        return Alerts.duration(t)
    }
}

/// Ixcham ustunlar (yozuvsiz): o'tganlari — och, hozirgisi — to'q, kelajakdagilari — bo'sh; ostida qisqa yorliq
private struct MiniColumns: View {
    let columns: [LimitCard.Column]

    var body: some View {
        let mx = max(columns.map(\.value).max() ?? 1, 1)
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(columns) { c in
                VStack(spacing: 3) {
                    GeometryReader { g in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(c.state == .future ? Color.white.opacity(0.08)
                                      : Brand.inkFill.opacity(c.state == .now ? 1 : 0.55))
                                .frame(height: c.state == .future ? 3 : max(3, g.size.height * CGFloat(c.value / mx)))
                        }
                    }
                    Text(c.label).font(.system(size: 9, weight: c.state == .now ? .bold : .regular).monospacedDigit())
                        .foregroundStyle(c.state == .now ? Color.white : Brand.inkDim.opacity(0.8))
                        .lineLimit(1).fixedSize()
                }
                .frame(maxWidth: .infinity)
                .help(c.help)
            }
        }
        .animation(Motion.smooth, value: columns.map(\.value))
    }
}

private struct UnevenTopRect: Shape {
    let radius: CGFloat
    func path(in r: CGRect) -> Path {
        let rr = min(radius, r.height / 2, r.width / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + rr))
        p.addQuadCurve(to: CGPoint(x: r.minX + rr, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - rr, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: r.minY + rr), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Kelajak soatlar uchun shtrix
private struct Hatch: View {
    var body: some View {
        Canvas { g, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: 0))
                g.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 5)
                x += 12
            }
        }
    }
}

/// Limit ulanmagan bo'lsa: bugungi sarf qahramon, yonida ulash taklifi
private struct ConnectHero: View {
    let today: TokenCounts
    let mode: CountMode

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("BUGUN SARFLANDI").eyebrow(Brand.inkDim)
                Text(Fmt.tokens(today.value(mode)))
                    .font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    .contentTransition(.numericText()).animation(Motion.smooth, value: today.total)
                Text("token").foregroundStyle(Brand.inkDim)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude'ning haqiqiy limitini ko'ring").font(.headline).foregroundStyle(.white)
                Text("5 soatlik va haftalik limit qancha qolgani, qachon tiklanishi va «shu sur'atda qachon tugaydi».")
                    .font(.callout).foregroundStyle(Brand.inkDim).frame(maxWidth: 340, alignment: .leading)
                Button("Claude Code'ga ulash…") { WindowManager.shared.show(.settings) }
                    .buttonStyle(.borderedProminent).tint(Brand.inkFill).padding(.top, 4)
            }
        }
        .padding(26)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Brand.ink))
    }
}

// MARK: - Hozir

struct NowRow: View {
    let snap: Snapshot
    let mode: CountMode

    var body: some View {
        let active = snap.sessions.first { $0.state != .idle }
        Group {
            if let sess = active { live(sess) } else { idle }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .card(padding: 0)
        .overlay {
            if let a = active {
                LiveBorder(shape: RoundedRectangle(cornerRadius: 20, style: .continuous),
                           color: snap.permissionWaits[a.id] != nil ? Brand.warn : Brand.ok, period: 4)
            }
        }
        .animation(Motion.spring, value: active?.id)
    }

    private func live(_ sess: SessionSnap) -> some View {
        let steps = sess.agents.flatMap(\.steps).sorted { $0.date < $1.date }
        let running = steps.last { $0.status == .running }
        let turn = sess.turns.last
        return Button {
            UserDefaults.standard.set(sess.id, forKey: GraphScreen.selectedSessionKey)
            WindowManager.shared.show(.graph)
        } label: {
            HStack(spacing: 16) {
                ToolTile(symbol: running?.category.symbol ?? "sparkles",
                         color: running?.category.color ?? Brand.accent, size: 44)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let w = snap.permissionWaits[sess.id] {
                            Image(systemName: "hand.raised.fill").font(.system(size: 10)).foregroundStyle(Brand.warn)
                            Text("RUXSATINGIZNI KUTYAPTI · \(sess.project.uppercased())").eyebrow(Brand.warn)
                                .help(w.message)
                        } else {
                            StateDot(state: .running, size: 6)
                            Text("HOZIR · \(sess.project.uppercased())").eyebrow(Brand.ok)
                        }
                        if sess.contextFraction >= 0.8 {
                            Text("· KONTEKST \(Int((sess.contextFraction * 100).rounded()))%").eyebrow(Brand.warn)
                        }
                    }
                    Text(snap.permissionWaits[sess.id].map { Alerts.uz($0.message) } ?? running?.text ?? sess.main?.lastAction ?? "Ishlayapti…")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                        .id(running?.id ?? "idle")
                        .transition(.opacity.combined(with: .offset(y: 6)))
                    StepTrail(steps: Array(steps.suffix(10)))
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(running?.duration.map { clock($0) } ?? Fmt.ago(sess.lastActivity))
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .contentTransition(.numericText())
                    if let turn {
                        Text("#\(turn.id) · \(turn.steps) qadam").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Sessiyani ochish")
    }

    private var idle: some View {
        HStack(spacing: 16) {
            ToolTile(symbol: "moon.stars.fill", color: Color(light: 0x8A8A93, dark: 0x4A4A52), size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text("HOZIR").eyebrow()
                Text("Hammasi tinch").font(.system(size: 16, weight: .semibold, design: .rounded))
                if let last = snap.sessions.first {
                    Text("Oxirgi ish: \(last.project) · \(Fmt.ago(last.lastActivity))").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private func clock(_ s: TimeInterval) -> String {
        let t = Int(s)
        return t >= 3600 ? "\(t / 3600):\(String(format: "%02d", t / 60 % 60)):\(String(format: "%02d", t % 60))"
                         : "\(t / 60):\(String(format: "%02d", t % 60))"
    }
}

/// So'nggi qadamlar izi: tugagan — urg'u, xato — qizil, bajarilayotgan — yashil
struct StepTrail: View {
    let steps: [StepSnap]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(steps) { s in
                Capsule()
                    .fill(s.status == .failed ? Brand.err : (s.status == .running ? Brand.ok : Brand.accent))
                    .frame(width: 22, height: 4)
                    .opacity(s.status == .running ? 0.6 : 1)
                    .help(s.text)
            }
        }
        .animation(Motion.spring, value: steps.map(\.id))
    }
}

// MARK: - Bento

private struct TodayBento: View {
    let snap: Snapshot
    let mode: CountMode

    var body: some View {
        let today = snap.today.value(mode)
        let yesterday = snap.days.dropLast().last?.tokens.value(mode) ?? 0
        let nowHour = Calendar.current.component(.hour, from: snap.updatedAt)
        let start = Calendar.current.startOfDay(for: snap.updatedAt)
        let steps = snap.sessions.flatMap { $0.agents.flatMap(\.steps) }.filter { $0.date >= start }
        let turns = snap.sessions.flatMap(\.turns).filter { $0.start >= start }.count
        let errors = steps.filter { $0.status == .failed }.count
        let byCat = Dictionary(grouping: steps, by: \.category).mapValues(\.count).sorted { $0.value > $1.value }

        AdaptiveStack(spacing: 14) {
            tile("TOKENLAR", Fmt.tokens(today),
                 yesterday > 0 ? AnyView(HStack(spacing: 4) {
                     Text("kecha \(Fmt.tokens(yesterday)) ·")
                     Text(ratio(today, yesterday)).foregroundStyle(today > yesterday ? Brand.warn : Brand.ok).fontWeight(.semibold)
                 }) : AnyView(Text("kecha ma'lumot yo'q"))) {
                MiniBars(values: Array(snap.todayHours.prefix(nowHour + 1)).map { $0.value(mode) }, highlightLast: 3)
                    .frame(height: 44)
            }
            tile("FAOL VAQT", Alerts.duration(Double(snap.activeMinutesToday) * 60),
                 AnyView(Text(snap.firstActivityToday.map { "\(Fmt.hourMinute.string(from: $0)) dan beri" } ?? "bugun faollik yo'q"))) {
                DayStrip(hours: snap.todayHours.map { $0.total }, now: nowHour)
            }
            tile("QADAMLAR", "\(steps.count)", AnyView(Text("\(turns) so'rov · \(errors) xato"))) {
                VStack(alignment: .leading, spacing: 8) {
                    GeometryReader { g in
                        HStack(spacing: 2) {
                            ForEach(byCat, id: \.key) { cat, n in
                                Rectangle().fill(cat.color)
                                    .frame(width: max(2, (g.size.width - CGFloat(byCat.count) * 2) * CGFloat(n) / CGFloat(max(1, steps.count))))
                            }
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 8)
                    HStack(spacing: 10) {
                        ForEach(byCat.prefix(3), id: \.key) { cat, n in
                            HStack(spacing: 4) {
                                Circle().fill(cat.color).frame(width: 6, height: 6)
                                Text("\(cat.title) \(Fmt.percent(Double(n), of: Double(steps.count)))")
                            }
                            .fixedSize()
                        }
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func ratio(_ a: Double, _ b: Double) -> String {
        let r = a / b
        return r >= 1.5 ? String(format: "%.1f×", r).replacingOccurrences(of: ".", with: ",")
                        : (a >= b ? "+" : "−") + Fmt.percent(abs(a - b), of: b)
    }

    private func tile<V: View>(_ title: String, _ value: String, _ sub: AnyView, @ViewBuilder _ visual: () -> V) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).eyebrow()
            Text(value)
                .font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .contentTransition(.numericText()).animation(Motion.smooth, value: value)
                .padding(.top, 4)
            sub.font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 10)
            visual()
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        .card(padding: 16)
        .hoverLift()
    }
}

/// 24 soatlik faollik qatori: har soat — katakcha, to'qligi — sarf
private struct DayStrip: View {
    let hours: [Int]
    let now: Int

    var body: some View {
        let mx = max(hours.max() ?? 1, 1)
        VStack(spacing: 4) {
            HStack(spacing: 2) {
                ForEach(0..<24, id: \.self) { h in
                    let v = Double(hours[h]) / Double(mx)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(v > 0 ? Brand.accent.opacity(0.25 + 0.75 * v) : Brand.sunken)
                        .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(h == now ? Brand.accent : (v > 0 ? .clear : Brand.line), lineWidth: h == now ? 1.5 : 1))
                        .frame(height: 22)
                        .help("\(String(format: "%02d", h)):00 — \(Fmt.tokens(hours[h]))")
                }
            }
            HStack {
                ForEach(["00", "06", "12", "18", "23"], id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: .leading) }
            }
            .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Sessiya qatori

struct SessionLine: View {
    let session: SessionSnap
    let mode: CountMode
    let now: Date

    var body: some View {
        Button {
            UserDefaults.standard.set(session.id, forKey: GraphScreen.selectedSessionKey)
            WindowManager.shared.show(.graph)
        } label: {
            HStack(spacing: 14) {
                ProjectAvatar(name: session.project, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(session.project).font(.callout.weight(.semibold)).lineLimit(1)
                        if session.state != .idle {
                            HStack(spacing: 4) {
                                StateDot(state: session.state, size: 6)
                                Text(session.state == .running ? "Ishlayapti" : "Kutyapti")
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Palette.state(session.state))
                            .padding(.horizontal, 7).padding(.vertical, 2)
                            .background(Capsule().fill(Palette.state(session.state).opacity(0.12)))
                        }
                    }
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 12)
                HStack(spacing: -5) {
                    ForEach(topCategories, id: \.self) { c in
                        ToolTile(symbol: c.symbol, color: c.color, size: 22)
                            .overlay(RoundedRectangle(cornerRadius: 6.5, style: .continuous).stroke(Brand.surface, lineWidth: 2))
                            .help(c.title)
                    }
                }
                .frame(width: 70, alignment: .leading)
                MiniBars(values: activity, color: session.state == .idle ? .secondary : Brand.accent, highlightLast: 12, spacing: 1.5)
                    .frame(width: 90, height: 26)
                Text(Fmt.tokens(session.tokens.value(mode)))
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }

    private var subtitle: String {
        let prompt = session.turns.last.map { "#\($0.id) \($0.shownPrompt)" } ?? session.title
        return "\(prompt) · \(Fmt.ago(session.lastActivity, now: now))"
    }

    private var topCategories: [ToolCategory] {
        let steps = session.agents.flatMap(\.steps)
        return Dictionary(grouping: steps, by: \.category).sorted { $0.value.count > $1.value.count }.prefix(3).map(\.key)
    }

    /// Sessiya faolligi: 12 bo'lak, birinchi va oxirgi harakat orasida
    private var activity: [Double] {
        let usage = session.agents.flatMap(\.usage)
        guard let a = usage.map(\.date).min(), let b = usage.map(\.date).max(), b > a else {
            return Array(repeating: 0, count: 11) + [session.tokens.value(mode) > 0 ? 1 : 0]
        }
        var v = Array(repeating: 0.0, count: 12)
        let span = b.timeIntervalSince(a)
        for u in usage {
            let i = min(11, Int(u.date.timeIntervalSince(a) / span * 12))
            v[i] += u.tokens.value(mode)
        }
        return v
    }
}

/// Sig'sa — yonma-yon, sig'masa — ustma-ust (tor oynada kartalar kesilib qolmasin)
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: spacing, content: content)
            VStack(alignment: .leading, spacing: spacing, content: content)
        }
    }
}
