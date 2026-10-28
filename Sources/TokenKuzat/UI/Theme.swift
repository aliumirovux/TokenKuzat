import SwiftUI
import AppKit
import TokenKuzatCore

// MARK: - Ranglar (tizim semantik ranglari — yorug' va qorong'i rejimda to'g'ri)

enum Palette {
    static let main = Color.accentColor
    static let agents = Color.indigo
    static let cacheRead = Color.purple
    static let fresh = Color.teal
    static let output = Color.orange
    static let input = Color.mint
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let stroke = Color.primary.opacity(0.08)

    static func state(_ s: AgentState) -> Color {
        switch s {
        case .running: return .green
        case .waiting: return .orange
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
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(highlight?.opacity(0.45) ?? Palette.stroke, lineWidth: 1))
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
            Text(title).font(.headline)
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
                TimelineView(.animation(minimumInterval: 1.0 / 15)) { ctx in
                    let t = ctx.date.timeIntervalSinceReferenceDate
                    ZStack {
                        Circle().fill(Palette.state(state).opacity(0.25))
                            .scaleEffect(1 + 0.8 * CGFloat((sin(t * 3) + 1) / 2))
                        Circle().fill(Palette.state(state))
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
        .padding(.horizontal, 9).padding(.vertical, 4)
        .background(Capsule().fill(Palette.state(state).opacity(state == .idle ? 0.12 : 0.16)))
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
                    .frame(width: 22, height: 22)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(tint.opacity(0.14)))
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let unit { Text(unit).font(.caption).foregroundStyle(.secondary) }
            }
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            }
        }
        .card(padding: 12)
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

/// Ulanmagan bo'lsa — taklif
struct ConnectLimitsHint: View {
    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "gauge.with.needle", tint: .blue, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude'ning haqiqiy limitini ko'rsatish").font(.callout.weight(.medium))
                Text("5 soatlik va haftalik limit foizi, tiklanish vaqti va «qachon tugaydi» bashorati — Claude Code'ning o'zidan.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Ulash…") { WindowManager.shared.show(.settings) }
        }
    }
}
