import SwiftUI
import TokenKuzatCore

// 5 soatlik oyna qayerga ketdi: Mac'dagi ishlar va Mac'dan tashqari (claude.ai / desktop chat, bulut, telefon).
// Chat Mac diskiga yozilmaydi — uning ulushi haqiqiy limit o'sishidan Mac sarfini ayirib topiladi (OutsideUsage).
// To'q (ink) fon ustida ishlatiladi.

enum SplitColor {
    static let mac = Brand.inkFill
    static let outside = Color(light: 0x5CC8FF, dark: 0x5CC8FF)
    static let uncertain = Color.white.opacity(0.38)
    static let unobserved = Color.white.opacity(0.16)
}

struct OutsideSplitRow: View {
    let outside: OutsideUsage
    var compact = false

    private struct Part: Identifiable {
        let id: String
        let label: String
        let pct: Double
        let color: Color
        let help: String
    }

    private var parts: [Part] {
        var p: [Part] = [
            .init(id: "mac", label: tr("Mac'da", "On this Mac"), pct: outside.macPct, color: SplitColor.mac,
                  help: tr("Shu Mac'dagi Claude Code va Cowork ishlari", "Claude Code and Cowork work on this Mac")),
            .init(id: "out", label: tr("Chat va bulut", "Chat & cloud"), pct: outside.outsidePct, color: SplitColor.outside,
                  help: tr("claude.ai va desktop chatlar, bulutdagi sessiyalar, telefon — Mac'ga yozilmaydi, limit o'sishidan hisoblandi", "claude.ai and desktop chats, cloud sessions, phone — not written to this Mac, estimated from limit growth")),
        ]
        if outside.uncertainPct >= 0.5 {
            p.append(.init(id: "unc", label: tr("Aniqlanmoqda", "Detecting"), pct: outside.uncertainPct, color: SplitColor.uncertain,
                           help: tr("Mac va chat bir vaqtda ishlagan; ulushlar bir necha o'lchovdan keyin ajratiladi", "Mac and chat were active at the same time; shares are split after a few measurements")))
        }
        if outside.unobservedPct >= 0.5 {
            p.append(.init(id: "pre", label: tr("Kuzatuvdan oldin", "Before tracking"), pct: outside.unobservedPct, color: SplitColor.unobserved,
                           help: tr("Ilova yopiq yoki Mac uxlab turgan paytda ishlatilgan qism", "Used while the app was closed or the Mac was asleep")))
        }
        return p
    }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 9) {
            if !compact {
                HStack(alignment: .firstTextBaseline) {
                    Text(tr("5 SOATLIK LIMIT QAYERGA KETDI", "WHERE THE 5-HOUR LIMIT WENT")).eyebrow(Brand.inkDim)
                    Spacer(minLength: 8)
                    if let today = todayText {
                        Text(today).font(.caption.weight(.medium)).foregroundStyle(Brand.inkDim).lineLimit(1)
                    }
                }
            }
            bar.frame(height: compact ? 6 : 8)
            legend
        }
        .help(tr("Chat va bulutdagi ishlar Mac diskiga yozilmaydi. Ularning ulushi Claude hisobidagi haqiqiy limit o'sishidan Mac'dagi sarfni ayirib taxminan hisoblanadi.", "Chat and cloud work isn't written to this Mac's disk. Its share is estimated by subtracting this Mac's usage from the real limit growth on your Claude account."))
    }

    private var bar: some View {
        GeometryReader { g in
            HStack(spacing: 2) {
                ForEach(parts.filter { $0.pct > 0.05 }) { p in
                    Capsule().fill(p.color).frame(width: max(3, g.size.width * min(1, p.pct / 100)))
                }
                Spacer(minLength: 0)
            }
            .frame(width: g.size.width, alignment: .leading)
            .background(Capsule().fill(.white.opacity(0.07)))
            .clipShape(Capsule())
        }
    }

    private var legend: some View {
        // Tor joyda — ikki qatorga o'tadi
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendItems }
            VStack(alignment: .leading, spacing: 4) { legendItems }
        }
    }

    @ViewBuilder
    private var legendItems: some View {
        ForEach(parts) { p in
            HStack(spacing: 5) {
                Circle().fill(p.color).frame(width: 7, height: 7)
                Text(p.label).foregroundStyle(Brand.inkDim)
                Text("\(Int(p.pct.rounded()))%").foregroundStyle(.white).monospacedDigit()
            }
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .fixedSize()
            .help(p.help)
        }
    }

    /// «Bugun chat va bulutda ~1,2M token»
    private var todayText: String? {
        guard outside.outsideTodayPct >= 0.5 else { return nil }
        if let t = outside.outsideTodayTokens {
            return tr("Bugun chat va bulutda ~\(Fmt.tokens(t)) token (narx bo'yicha)", "Today in chat & cloud: ~\(Fmt.tokens(t)) tokens (by price)")
        }
        return tr("Bugun chat va bulutda limitning \(Int(outside.outsideTodayPct.rounded()))%", "Today in chat & cloud: \(Int(outside.outsideTodayPct.rounded()))% of the limit")
    }
}
