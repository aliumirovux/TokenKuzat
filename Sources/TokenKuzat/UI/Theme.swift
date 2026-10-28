import SwiftUI
import AppKit
import TokenKuzatCore

// MARK: - Ranglar (tizim semantik ranglari — yorug' va qorong'i rejimda to'g'ri)

enum Palette {
    static let main = Brand.accent
    static let agents = Color(light: 0x2F7BE5, dark: 0x4A8FF0)
    static let cacheRead = Color.purple
    static let fresh = Color.teal
    static let output = Color.orange
    static let input = Color.mint
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
        case .ok: return .green
        case .warning: return .orange
        case .over: return .red
        }
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

struct StateDot: View {
    let state: AgentState
    var size: CGFloat = 8

    var body: some View {
        Group {
            if state == .running {
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
    let running: Int
    let active: Int

    private var state: AgentState { running > 0 ? .running : (active > 0 ? .waiting : .idle) }
    private var text: String {
        if running > 0 { return "Jonli · \(running) agent" }
        if active > 0 { return "Kutyapti" }
        return "Tinch"
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
        .help(running > 0 ? "\(running) ta agent hozir ishlayapti"
              : (active > 0 ? "Agent asbob natijasini kutyapti (masalan, terminal buyrug'i)" : "Hech qanday agent ishlamayapti"))
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
    var tint: Color = .accentColor

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
                Label("Limit · \(status.period.title.lowercased())", systemImage: "gauge.with.dots.needle.50percent")
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
    @AppStorage(Pref.countMode) private var mode = CountMode.raw

    var body: some View {
        Picker("Hisoblash", selection: $mode) {
            ForEach(CountMode.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .help("Xom — hamma token teng. Vaznli — taxminiy narx: javob ×5, kesh o'qish ×0,1, kesh yozish ×1,25–2.")
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
                row("5 soatlik oyna", w, note: forecastText(w))
            }
            if let w = limits.sevenDay {
                row("Haftalik", w, note: nil)
            }
            if limits.isEmpty {
                Text("Limit ma'lumoti hali kelmadi — Claude Code'da biror so'rov yuboring.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ title: String, _ w: LimitWindow, note: (String, Color)?) -> some View {
        let pct = w.usedPercentage
        let color: Color = pct >= 90 ? .red : (pct >= 70 ? .orange : .green)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(compact ? .caption.weight(.medium) : .callout.weight(.medium))
                Spacer()
                Text("↻ \(resetText(w.resetsAt))").font(.caption2).foregroundStyle(.secondary)
                Text("\(Int(pct.rounded()))%")
                    .font((compact ? Font.caption : .callout).weight(.semibold)).monospacedDigit().foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color.gradient).frame(width: max(4, geo.size.width * CGFloat(min(pct, 100) / 100)))
                }
            }
            .frame(height: compact ? 6 : 8)
            if let note {
                Text(note.0).font(.caption2).foregroundStyle(note.1)
            }
        }
    }

    private func forecastText(_ w: LimitWindow) -> (String, Color)? {
        switch forecast {
        case .runsOut(let at):
            return ("Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi (\(Alerts.duration(at.timeIntervalSinceNow)) qoldi)", .orange)
        case .lasts:
            return compact ? nil : ("Shu tezlikda tiklanguncha yetadi", .secondary)
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

    /// «bugun 18:30», «ertaga 09:00», «Seshanba 21:00»
    static func dayTime(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let hm = Fmt.hourMinute.string(from: d)
        if cal.isDate(d, inSameDayAs: now) { return "bugun " + hm }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return "ertaga " + hm }
        return weekdays[cal.component(.weekday, from: d) - 1] + " " + hm
    }

    /// «juma ertalab», «bugun kechqurun»
    static func dayPart(_ d: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: d)
        let part = h < 5 ? "tunda" : (h < 12 ? "ertalab" : (h < 17 ? "tushdan keyin" : (h < 22 ? "kechqurun" : "tunda")))
        if cal.isDate(d, inSameDayAs: now) { return "bugun " + part }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(d, inSameDayAs: t) { return "ertaga " + part }
        return weekdays[cal.component(.weekday, from: d) - 1].lowercased() + " " + part
    }

    /// «3-noyabr»
    static func date(_ d: Date) -> String {
        let c = Calendar.current.dateComponents([.day, .month], from: d)
        return "\(c.day ?? 0)-\(months[(c.month ?? 1) - 1])"
    }

    /// Haftalik bashorat jumlasi; tugamaydigan bo'lsa — nil
    static func weekWarning(_ f: LimitForecast.Outcome, week: LimitWindow) -> String? {
        guard case .runsOut(let at) = f else { return nil }
        return "Shu sur'atda \(dayPart(at)) tugaydi — \(date(week.resetsAt)) tiklanishidan oldin."
    }

    /// Ma'lumot eskirgan bo'lsa — ogohlantirish (status line faqat terminaldagi Claude Code'da yangilanadi)
    static func staleNote(_ l: RateLimits, now: Date = Date()) -> String? {
        let age = now.timeIntervalSince(l.updatedAt)
        guard !l.fromAccount, age > 10 * 60 else { return nil }
        return "\(Alerts.duration(age)) oldingi ma'lumot — terminalda Claude Code ishlaganda yangilanadi"
    }
}

/// Claude sahifasidagidek qator: nom, tiklanish vaqti, chiziq va «44% ishlatildi»
struct LimitBarRow: View {
    let title: String
    let window: LimitWindow
    var dark = false

    var body: some View {
        let pct = window.usedPercentage
        let fill: Color = pct >= 90 ? Brand.err : (pct >= 75 ? Brand.warn : (dark ? Brand.inkFill : Brand.accent))
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(dark ? Color.white : .primary)
                Text(window.isNotStarted ? "birinchi so'rov bilan boshlanadi" : "↻ " + LimitText.dayTime(window.resetsAt)).font(.caption2)
                    .foregroundStyle(dark ? Brand.inkDim : .secondary)
                Spacer()
                Text("\(Int(pct.rounded()))% ishlatildi").font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(dark ? Color.white : .primary)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(dark ? Color.white.opacity(0.1) : Color.primary.opacity(0.08))
                    Capsule().fill(fill).frame(width: max(4, g.size.width * CGFloat(min(pct, 100) / 100)))
                }
            }
            .frame(height: 6)
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
