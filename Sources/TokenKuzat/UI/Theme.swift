import SwiftUI
import AppKit
import TokenKuzatCore

// MARK: - Ranglar (bitta palitra: hamma rang Brand / Hue tokenlaridan)

enum Palette {
    static let main = Brand.accent
    /// Token turlari: tartibi va qiymatlari rang ko'rmaslik validatoridan ikkala rejimda o'tgan (design/a1-palette.html)
    static let cacheRead = Color(light: 0x6C5CE7, dark: 0x7F72F5)
    static let fresh = Color(light: 0x0E9F8E, dark: 0x139C8C)
    static let input = Color(light: 0xB04FD8, dark: 0xAE62D8)
    static let output = Color(light: 0xE0731C, dark: 0xDA7426)
    static let agents = Color(light: 0x2F7BE5, dark: 0x3F85EC)
    static let surface = Brand.surface
    static let canvas = Brand.canvas
    static let stroke = Brand.line

    static func state(_ s: AgentState) -> Color {
        switch s {
        case .running: return Brand.ok
        case .waiting: return Brand.warn
        case .idle: return Color.secondary.opacity(0.5)
        }
    }

    static func budget(_ l: BudgetStatus.Level) -> Color {
        switch l {
        case .ok: return Brand.accent
        case .warning: return Brand.warn
        case .over: return Brand.err
        }
    }

    /// Limit qoidasi hamma joyda bitta: 75% gacha urg'u, 75–89% ogohlantirish, 90%+ xato. Limit — o'lchov, holat emas,
    /// shuning uchun yashil yo'q. `onInk` — to'q siyoh blok ustidagi yorqinroq qadamlar.
    static func limit(_ pct: Double, onInk: Bool = false) -> Color {
        if pct >= 90 { return onInk ? Brand.onInkErr : Brand.err }
        if pct >= 75 { return onInk ? Brand.onInkWarn : Brand.warn }
        return onInk ? Brand.inkFill : Brand.accent
    }

    /// Butun shkala bitta gradientda: chiziq foizgacha ochadi, uchidagi rang `limit(pct)` bilan mos keladi
    static func limitScale(onInk: Bool = false) -> Gradient {
        let a = limit(0, onInk: onInk), w = limit(80, onInk: onInk), e = limit(95, onInk: onInk)
        return Gradient(stops: [.init(color: a, location: 0), .init(color: a, location: 0.73),
                                .init(color: w, location: 0.77), .init(color: w, location: 0.88),
                                .init(color: e, location: 0.92), .init(color: e, location: 1)])
    }
}

// MARK: - Limit shkalasi

/// Limit chizig'i: ostida butun shkala xira ko'rinadi (75 va 90 chegaralari chiziqning o'zida), ustida foizgacha ochilgan qismi
struct LimitTrack: View {
    let pct: Double
    var height: CGFloat = 6
    var onInk = false

    var body: some View {
        let scale = LinearGradient(gradient: Palette.limitScale(onInk: onInk), startPoint: .leading, endPoint: .trailing)
        GeometryReader { g in
            let w = g.size.width
            ZStack(alignment: .leading) {
                Capsule().fill(onInk ? Color.white.opacity(0.08) : Color.primary.opacity(0.06))
                Capsule().fill(scale).opacity(onInk ? 0.22 : 0.18)
                Capsule().fill(scale).frame(width: w)
                    .mask(alignment: .leading) { Capsule().frame(width: max(height, w * CGFloat(min(max(pct, 0), 100) / 100))) }
            }
        }
        .frame(height: height)
        .animation(Motion.smooth, value: pct)
    }
}

/// Limit halqasi: xira shkala izi va foizgacha ochilgan gradient yoy. Uchlari alohida doira — yumaloq uch gradientning
/// qarama-qarshi chetidan rang olmasin.
struct LimitRingStroke: View {
    let pct: Double
    let lineWidth: CGFloat
    var onInk = true

    var body: some View {
        let p = min(max(pct, 0), 100) / 100
        let scale = AngularGradient(gradient: Palette.limitScale(onInk: onInk), center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360))
        GeometryReader { g in
            let r = (min(g.size.width, g.size.height) - lineWidth) / 2
            let c = CGPoint(x: g.size.width / 2, y: g.size.height / 2)
            let end = CGFloat(p * 2 * .pi)
            ZStack {
                Circle().inset(by: lineWidth / 2).stroke(Color.white.opacity(0.06), lineWidth: lineWidth)
                Circle().inset(by: lineWidth / 2).stroke(scale, lineWidth: lineWidth).opacity(0.22)
                if p > 0 {
                    Circle().inset(by: lineWidth / 2).trim(from: 0, to: p).stroke(scale, lineWidth: lineWidth)
                    Circle().fill(Palette.limit(0, onInk: onInk)).frame(width: lineWidth, height: lineWidth)
                        .position(x: c.x + r, y: c.y)
                    Circle().fill(Palette.limit(pct, onInk: onInk)).frame(width: lineWidth, height: lineWidth)
                        .position(x: c.x + r * cos(end), y: c.y + r * sin(end))
                }
            }
            .rotationEffect(.degrees(-90))
        }
        .animation(Motion.smooth, value: pct)
    }
}

// MARK: - Karta

struct CardModifier: ViewModifier {
    var padding: CGFloat = 14
    var highlight: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(radius: 20, tint: highlight, stroke: highlight?.opacity(0.45))
    }
}

extension View {
    func card(padding: CGFloat = 14, highlight: Color? = nil) -> some View {
        modifier(CardModifier(padding: padding, highlight: highlight))
    }
}

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.headline, design: .rounded))
            if let subtitle {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            trailing
        }
    }
}

// MARK: - Holat belgilari

/// Yengil «ishlayapti» belgisi: 8 ta chiziqcha, soniyasiga 10 qadam. Tizim ProgressView'i har kadrda butun oynani
/// qayta chizdiradi — bu esa faqat o'zini. Yengil rejimda — qimirlamaydi.
struct Spinner: View {
    var size: CGFloat = 10
    var color: Color = .secondary
    @AppStorage(Pref.lightMode) private var lightMode = false

    var body: some View {
        let calm = lightMode || Power.saving
        TimelineView(.periodic(from: .now, by: calm ? 3600 : 0.1)) { ctx in
            let step = calm ? 0 : Int(ctx.date.timeIntervalSinceReferenceDate * 10) % 8
            Canvas { g, sz in
                let c = CGPoint(x: sz.width / 2, y: sz.height / 2), r = min(sz.width, sz.height) / 2
                for i in 0..<8 {
                    let a = Double(i) / 8 * 2 * .pi - .pi / 2
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + cos(a) * r * 0.45, y: c.y + sin(a) * r * 0.45))
                    p.addLine(to: CGPoint(x: c.x + cos(a) * r * 0.95, y: c.y + sin(a) * r * 0.95))
                    let age = (step - i + 8) % 8
                    g.stroke(p, with: .color(color.opacity(1 - Double(age) * 0.11)),
                             style: StrokeStyle(lineWidth: max(1.2, r * 0.22), lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(tr("Ishlayapti", "Working"))
    }
}

struct StateDot: View {
    let state: AgentState
    var size: CGFloat = 8

    @AppStorage(Pref.lightMode) private var lightMode = false

    var body: some View {
        Group {
            if state == .running && !lightMode && !Power.saving {
                TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    let p = CGFloat((sin(t * 2.4) + 1) / 2)
                    ZStack {
                        Circle().fill(Palette.state(state).opacity(0.35 * (1 - p)))
                            .scaleEffect(1 + 1.2 * p)
                        Circle().fill(Palette.state(state))
                            .shadow(color: Palette.state(state).opacity(0.6), radius: 3)
                    }
                }
            } else {
                Circle().fill(Palette.state(state))
            }
        }
        .frame(width: size, height: size)
        .help(state.title)
        .accessibilityLabel(state.title)
    }
}

struct StatusPill: View {
    /// Ishlayotgan sessiyalar
    let running: Int
    let active: Int
    /// Ishlayotgan agentlar (yordamchilar bilan) — faqat maslahatda
    var agents = 0
    /// Maslahatga qo'shiladigan izoh (masalan, bosilsa nima bo'lishi)
    var hint: String? = nil

    private var state: AgentState { running > 0 ? .running : (active > 0 ? .waiting : .idle) }
    private var text: String {
        if running > 0 { return tr("Jonli · \(running) sessiya", running == 1 ? "Live · 1 session" : "Live · \(running) sessions") }
        if active > 0 { return tr("Kutyapti", "Waiting") }
        return tr("Tinch", "Idle")
    }

    var body: some View {
        HStack(spacing: 6) {
            StateDot(state: state, size: 7)
            Text(text).font(.caption.weight(.medium))
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 10).padding(.vertical, 5)
        .surfaceCapsule(tint: state == .idle ? nil : Palette.state(state))
        .animation(Motion.spring, value: running)
        .help([tooltip, hint].compactMap { $0 }.joined(separator: " · "))
    }

    private var tooltip: String {
        running > 0 ? tr("\(running) sessiyada \(max(agents, running)) agent ishlayapti",
                         "\(max(agents, running)) \(max(agents, running) == 1 ? "agent" : "agents") working in \(running) \(running == 1 ? "session" : "sessions")")
            : (active > 0 ? tr("Agent asbob natijasini kutyapti (masalan, terminal buyrug'i)", "Agent is waiting for a tool result (e.g. a terminal command)") : tr("Hech qanday agent ishlamayapti", "No agents are working"))
    }
}

struct Chip: View {
    let text: String
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.06)))
        .lineLimit(1)
    }
}

// MARK: - Ko'rsatkich plitasi

struct MetricTile: View {
    let title: String
    let value: String
    var unit: String? = nil
    var footnote: String? = nil
    var symbol: String
    var tint: Color = Brand.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(tint.opacity(0.16)))
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .animation(Motion.smooth, value: value)
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .card(padding: 14)
        .hoverLift(1.01)
    }
}

// MARK: - Limit

struct BudgetBar: View {
    let status: BudgetStatus
    var compact = false

    var body: some View {
        let color = Palette.budget(status.level)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Label(tr("Limit · \(status.period.title.lowercased())", "Limit · \(status.period.title.lowercased())"), systemImage: "gauge.with.dots.needle.50percent")
                    .font(.caption.weight(.medium))
                Spacer()
                Text("\(Fmt.tokens(status.used)) / \(Fmt.tokens(status.limit))")
                    .font(.caption).monospacedDigit().foregroundStyle(.secondary)
                Text(Fmt.percent(status.used, of: status.limit))
                    .font(.caption.weight(.semibold)).monospacedDigit().foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color.gradient)
                        .frame(width: max(4, geo.size.width * CGFloat(min(status.fraction, 1))))
                }
            }
            .frame(height: compact ? 6 : 8)
        }
    }
}

// MARK: - Bo'sh holat

struct EmptyStateView: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 28, weight: .light)).foregroundStyle(.secondary)
            Text(title).font(.headline)
            Text(text).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36).padding(.horizontal, 16)
    }
}

struct CountModePicker: View {
    @AppStorage(Pref.countMode) private var mode = CountMode.weighted

    var body: some View {
        PillSegments(selection: $mode, items: CountMode.allCases.map { .init(id: $0, title: $0.title) }, compact: true)
        .help(tr("Token soni — hamma token teng. Narx bo'yicha — limitni nima ko'proq yeyishi: javob ×5, qayta o'qilgan kontekst ×0,1, kontekstni eslab qolish ×1,25–2.", "Token count — every token counts the same. By cost — what really eats your limit: replies ×5, re-read context ×0.1, saving context ×1.25–2."))
    }
}

// MARK: - Agent belgisi

func agentSymbol(_ a: AgentSnap) -> String {
    if a.isMain { return "brain" }
    switch a.kind.lowercased() {
    case "explore": return "binoculars.fill"
    case "plan": return "list.bullet.rectangle"
    case "general-purpose", "claude": return "person.fill"
    case "claude-code-guide": return "book.fill"
    case "fork": return "arrow.triangle.branch"
    default: return "cpu"
    }
}

struct IconTile: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).fill(tint.opacity(0.15)))
    }
}

// MARK: - Haqiqiy limit (Claude Code status line)

/// 5 soatlik va haftalik oyna: foiz, tiklanish vaqti va «shu tezlikda qachon tugaydi»
struct RealLimitsView: View {
    let limits: RateLimits
    let forecast: LimitForecast.Outcome
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if let w = limits.fiveHour {
                row(tr("5 soatlik oyna", "5-hour window"), w, note: forecastText(w))
            }
            if let w = limits.sevenDay {
                row(tr("Haftalik", "Weekly"), w, note: nil)
            }
            if limits.isEmpty {
                Text(tr("Limit ma'lumoti hali kelmadi — Claude Code'da biror so'rov yuboring.", "No limit data yet — send a prompt in Claude Code."))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ w: LimitWindow, note: (String, Color)?) -> some View {
        let pct = w.usedPercentage
        let color = Palette.limit(pct)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
                Spacer()
                Text("↻ \(resetText(w.resetsAt))").font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(pct.rounded()))%")
                    .font((compact ? Font.caption : .callout).weight(.semibold)).monospacedDigit().foregroundStyle(color)
            }
            LimitTrack(pct: pct, height: compact ? 6 : 8)
            if let note {
                Text(note.0).font(.caption2).foregroundStyle(note.1)
            }
        }
    }

    private func forecastText(_ w: LimitWindow) -> (String, Color)? {
        switch forecast {
        case .runsOut(let at):
            return (tr("Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi (\(Alerts.duration(at.timeIntervalSinceNow)) qoldi)", "At this pace, runs out at ~\(Fmt.hourMinute.string(from: at)) (\(Alerts.duration(at.timeIntervalSinceNow)) left)"), Brand.warn)
        case .lasts:
            return compact ? nil : (tr("Shu tezlikda tiklanguncha yetadi", "At this pace, lasts until reset"), .secondary)
        case .unknown:
            return nil
        }
    }

    private func resetText(_ d: Date) -> String {
        let left = d.timeIntervalSinceNow
        let time = left > 86_400 ? Fmt.dayTime.string(from: d) : Fmt.hourMinute.string(from: d)
        return "\(time) (\(Alerts.duration(max(0, left))))"
    }
}


// MARK: - Limit matnlari

enum LimitText {
    private static let weekdays = ["Yakshanba", "Dushanba", "Seshanba", "Chorshanba", "Payshanba", "Juma", "Shanba"]
    private static let months = ["yanvar", "fevral", "mart", "aprel", "may", "iyun", "iyul", "avgust",
                                 "sentabr", "oktabr", "noyabr", "dekabr"]
    private static let weekdaysEn = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    private static let monthsEn = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static var wd: [String] { Lang.isEnglish ? weekdaysEn : weekdays }

    /// «bugun 18:30», «ertaga 09:00», «Seshanba 21:00»
    static func dayTime(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let hm = Fmt.hourMinute.string(from: d)
        if cal.isDate(d, inSameDayAs: now) { return tr("bugun ", "today ") + hm }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return tr("ertaga ", "tomorrow ") + hm }
        return wd[cal.component(.weekday, from: d) - 1] + " " + hm
    }

    /// «juma ertalab», «bugun kechqurun»
    static func dayPart(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: d)
        let part = h < 5 ? tr("tunda", "night") : (h < 12 ? tr("ertalab", "morning") : (h < 17 ? tr("tushdan keyin", "afternoon") : (h < 22 ? tr("kechqurun", "evening") : tr("tunda", "night"))))
        if cal.isDate(d, inSameDayAs: now) { return tr("bugun ", "this ") + part }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return tr("ertaga ", "tomorrow ") + part }
        return (Lang.isEnglish ? wd[cal.component(.weekday, from: d) - 1] : weekdays[cal.component(.weekday, from: d) - 1].lowercased()) + " " + part
    }

    /// «3-noyabr»
    static func date(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: d)
        return tr("\(c.day ?? 0)-\(months[(c.month ?? 1) - 1])", "\(monthsEn[(c.month ?? 1) - 1]) \(c.day ?? 0)")
    }

    /// Haftalik bashorat jumlasi; tugamaydigan bo'lsa — nil
    /// «Shu sur'atda 5 soatlik limit ~19:40 da tugaydi — tiklanish 20:50 da»
    static func fiveHourWarning(_ at: Date, reset: Date) -> String {
        tr("Shu sur'atda 5 soatlik limit ~\(Fmt.hourMinute.string(from: at)) da tugaydi — tiklanish \(Fmt.hourMinute.string(from: reset)) da",
           "At this pace the 5-hour limit runs out at ~\(Fmt.hourMinute.string(from: at)) — it resets at \(Fmt.hourMinute.string(from: reset))")
    }

    static func weekWarning(_ f: LimitForecast.Outcome, week: LimitWindow) -> String? {
        guard case .runsOut(let at) = f else { return nil }
        return tr("Shu sur'atda \(dayPart(at)) tugaydi — \(date(week.resetsAt)) tiklanishidan oldin.", "At this pace, runs out \(dayPart(at)) — before the \(date(week.resetsAt)) reset.")
    }

    /// Bashorat tinch, lekin limitning 75%+ qismi ishlatilgan — «me'yorida» emas, holatni aytamiz.
    /// Rangi uchun foiz ham qaytadi (`Palette.limit`).
    static func highUse(_ five: LimitWindow?, week: LimitWindow?) -> (text: String, pct: Double)? {
        let shown = [(five, true), (week, false)].compactMap { w, isFive in w.map { ($0, isFive) } }.filter { !$0.0.isNotStarted }
        guard let (w, isFive) = shown.max(by: { $0.0.usedPercentage < $1.0.usedPercentage }), w.usedPercentage >= 75 else { return nil }
        let p = Int(w.usedPercentage.rounded())
        if isFive {
            let at = Fmt.hourMinute.string(from: w.resetsAt)
            return (tr("5 soatlik limitning \(p)% ishlatildi — tiklanish \(at) da", "\(p)% of the 5-hour limit used — resets at \(at)"), w.usedPercentage)
        }
        return (tr("Haftalik limitning \(p)% ishlatildi — tiklanish \(date(w.resetsAt))", "\(p)% of the weekly limit used — resets \(date(w.resetsAt))"), w.usedPercentage)
    }

    /// Ma'lumot eskirgan bo'lsa — ogohlantirish (status line faqat terminaldagi Claude Code'da yangilanadi)
    static func staleNote(_ l: RateLimits, now: Date = Date()) -> String? {
        let age = now.timeIntervalSince(l.updatedAt)
        guard !l.fromAccount, age > 10 * 60 else { return nil }
        return tr("\(Alerts.duration(age)) oldingi ma'lumot — terminalda Claude Code ishlaganda yangilanadi", "Data from \(Alerts.duration(age)) ago — updates when Claude Code runs in the terminal")
    }
}

/// Claude sahifasidagidek qator: nom, tiklanish vaqti, chiziq va «44% ishlatildi»
struct LimitBarRow: View {
    let title: String
    let window: LimitWindow
    var dark = false

    var body: some View {
        let pct = window.usedPercentage
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(dark ? Color.white : .primary)
                Text(window.isNotStarted ? tr("birinchi so'rov bilan boshlanadi", "starts with your first prompt") : "↻ " + LimitText.dayTime(window.resetsAt)).font(.caption2)
                    .foregroundStyle(dark ? Brand.inkDim : .secondary)
                Spacer()
                Text(tr("\(Int(pct.rounded()))% ishlatildi", "\(Int(pct.rounded()))% used")).font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(dark ? Color.white : .primary)
            }
            LimitTrack(pct: pct, height: 6, onInk: dark)
        }
        .animation(Motion.smooth, value: pct)
    }
}

extension LimitWindow {
    /// 5 soatlik oyna tugab, yangisi hali boshlanmagan payt uchun: 0%, tiklanish vaqti noma'lum
    static let notStarted = LimitWindow(usedPercentage: 0, resetsAt: .distantFuture)
    var isNotStarted: Bool { resetsAt == .distantFuture }
}

extension RateLimits {
    /// Ko'rsatish uchun sessiya oynasi: tugagan bo'lsa, lekin haftalik bor — «boshlanmagan» oyna
    var sessionWindow: LimitWindow? { fiveHour ?? (sevenDay != nil ? .notStarted : nil) }
}
