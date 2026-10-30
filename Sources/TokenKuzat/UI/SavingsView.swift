import SwiftUI
import AppKit
import TokenKuzatCore

// Tejash maslahatlari: model va sifat o'zgarmaydi — qayerda token behuda ketayotgani va nima qilish kerakligi.

extension SavingsTip {
    var symbol: String { kind.symbol }

    var color: Color {
        switch level {
        case .high: return Brand.warn
        case .notable: return Brand.accent
        case .info: return .secondary
        }
    }

    /// «har javobda ~460K» yoki «~1,2M token ketgan»
    var amount: String? {
        guard tokens > 0 else { return nil }
        return perCall ? tr("har javobda ~\(Fmt.tokens(tokens)) tejaladi", "saves ~\(Fmt.tokens(tokens)) per response") : tr("~\(Fmt.tokens(tokens)) token ketgan", "~\(Fmt.tokens(tokens)) tokens spent")
    }
}

extension SavingsTip.Kind {
    var symbol: String {
        switch self {
        case .bigContext: return "text.alignleft"
        case .cacheRebuilds: return "clock.arrow.circlepath"
        case .repeatedReads: return "doc.on.doc"
        case .screenshots: return "camera.viewfinder"
        case .errorLoop: return "arrow.triangle.2.circlepath"
        case .bigResults: return "shippingbox"
        case .heavyStart: return "powerplug"
        }
    }
}

/// «Yangi sessiyada davom ettirish»: xulosa saqlanadi, keyingi yangi Claude Code sessiyasi uni o'zi oladi
/// (SessionStart hook). Zaxira uchun nusxaga ham olinadi.
struct HandoffButton: View {
    let session: SessionSnap
    var prominent = true
    @State private var armed = false
    @State private var delivered = false
    @State private var failed = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 2)) { _ in
            HStack(spacing: 8) {
                if armed && HandoffStore.pending() != nil {
                    Label(tr("Tayyor — yangi sessiya oching, Claude xulosani o'zi oladi", "Ready — open a new session, Claude will pick up the summary itself"), systemImage: "arrow.right.circle.fill")
                        .font(.callout.weight(.semibold)).foregroundStyle(Brand.ok)
                    Button(tr("Bekor qilish", "Cancel")) { HandoffStore.cancel(); withAnimation(Motion.snappy) { armed = false } }
                        .buttonStyle(.link).font(.caption)
                } else if delivered || (armed && !FileManager.default.fileExists(atPath: HandoffStore.defaultURL.path)) {
                    Label(tr("Yangi sessiyaga berildi", "Handed to the new session"), systemImage: "checkmark.circle.fill")
                        .font(.callout.weight(.semibold)).foregroundStyle(Brand.ok)
                        .onAppear { armed = false; delivered = true }
                } else {
                    Button(action: arm) {
                        Label(failed ? tr("Ulab bo'lmadi — xulosa nusxalandi", "Couldn't connect — summary copied") : tr("Yangi sessiyada davom ettirish", "Continue in a new session"),
                              systemImage: failed ? "exclamationmark.triangle.fill" : "arrow.triangle.branch")
                            .font(.callout.weight(.semibold))
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .foregroundStyle(prominent ? Color.white : Brand.accent)
                            .background(Capsule().fill(prominent ? (failed ? Brand.warn : Brand.accent) : Brand.accentSoft))
                    }
                    .buttonStyle(.plain)
                    .help(tr("Nima qilingani, o'zgargan fayllar va oxirgi holat saqlanadi. Keyingi 2 soat ichida ochilgan yangi "
                          + "Claude Code sessiyasi uni avtomatik oladi — hech narsa qo'yish shart emas. Zaxira uchun nusxaga ham olinadi.",
                          "What was done, changed files and the latest state are saved. A new Claude Code session opened within "
                          + "the next 2 hours picks it up automatically — nothing to paste. It's also copied as a backup."))
                }
            }
        }
        .onAppear { armed = HandoffStore.pending()?.sourceSession == session.id }
    }

    private func arm() {
        let session = session
        AutoHandoff.summary(for: session) { summary in
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(summary, forType: .string)
            if AutoHandoff.arm(session, summary: summary) {
                withAnimation(Motion.snappy) { armed = true; delivered = false; failed = false }
            } else {
                withAnimation(Motion.snappy) { failed = true }
            }
        }
    }
}

/// To'liq ro'yxat (sessiya sarlavhasidagi «Tejash» oynasi)
struct SavingsList: View {
    let session: SessionSnap
    let tips: [SavingsTip]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "leaf.fill").foregroundStyle(Brand.ok)
                Text(tr("Tokenni tejash", "Save tokens")).font(.headline)
                if !tips.isEmpty {
                    AccuracyBadge(accuracy: .estimated,
                                  help: tr("Kontekst hajmi transkriptdan o'lchangan. Tejash raqamlari — taxmin: ixcham sessiya ~40K deb, takroriy o'qish ~3K, skrinshot ~1,5K token deb olinadi.",
                                           "Context size is measured from the transcript. Savings figures are estimates: a lean session is taken as ~40K, a repeated read ~3K and a screenshot ~1.5K tokens."))
                }
                Spacer()
                Text(tr("Tejash uchun modelni yoki javob sifatini pasaytirish shart emas", "Saving doesn't mean a weaker model or worse answers")).font(.caption).foregroundStyle(.secondary)
            }
            if let left = SavingsAdvisor.cacheTimeLeft(for: session) {
                CacheBanner(until: Date().addingTimeInterval(left), context: session.contextTokens)
            }
            if tips.isEmpty {
                Text(tr("Hozircha isrof ko'rinmayapti — kontekst kichik va qadamlar takrorlanmayapti.", "No waste so far — the context is small and steps aren't repeating."))
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(tips) { TipRow(tip: $0) }
            Divider()
            HStack {
                HandoffButton(session: session)
                Spacer()
            }
            Text(tr("Tugmani bosing va yangi sessiya oching — Claude ishni qayerda to'xtaganini o'zi biladi, kontekst esa "
                 + "\(Fmt.tokens(session.contextTokens)) emas, ~\(Fmt.tokens(SavingsAdvisor.startContext(for: session) ?? SavingsAdvisor.baseline)) "
                 + "dan boshlanadi. Model va sifat o'zgarmaydi.",
                 "Click the button and open a new session — Claude knows where the work stopped, and the context starts at "
                 + "~\(Fmt.tokens(SavingsAdvisor.startContext(for: session) ?? SavingsAdvisor.baseline)) instead of "
                 + "\(Fmt.tokens(session.contextTokens)). Model and quality stay the same."))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: 440)
    }
}

private struct TipRow: View {
    let tip: SavingsTip

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ToolTile(symbol: tip.symbol, color: tip.level == .info ? Color(light: 0x8A8A93, dark: 0x6E6E76) : tip.color, size: 32)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(tip.title).font(.callout.weight(.semibold))
                    Spacer(minLength: 6)
                    if let a = tip.amount {
                        Text(a).font(.caption.weight(.semibold)).foregroundStyle(tip.level == .info ? .secondary : tip.color)
                            .lineLimit(1)
                    }
                }
                Text(tip.detail).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Kesh hali saqlanib turibdi: shu vaqt ichida davom etsangiz arzonroq
private struct CacheBanner: View {
    let until: Date
    let context: Int

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            let rem = max(0, until.timeIntervalSince(ctx.date))
            HStack(spacing: 8) {
                Image(systemName: "timer")
                Text(tr("Kesh yana ~\(Alerts.duration(rem)) saqlanadi — shu vaqt ichida davom etsangiz, \(Fmt.tokens(context)) "
                     + "kontekst qayta yozilmaydi.",
                     "Cache is kept for ~\(Alerts.duration(rem)) more — continue within that time and \(Fmt.tokens(context)) "
                     + "of context won't be rewritten."))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.caption.weight(.medium)).foregroundStyle(Brand.ok)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Brand.ok.opacity(0.1)))
        }
    }
}

/// Sessiya sarlavhasidagi belgi: bosilsa — maslahatlar oynasi
struct SavingsChip: View {
    let session: SessionSnap
    @State private var open = false

    var body: some View {
        let tips = SavingsAdvisor.tips(for: session)
        let top = tips.first
        Button { open.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: "leaf.fill")
                Text(top.flatMap { $0.perCall ? tr("Har javobda ~\(Fmt.tokens($0.tokens)) tejash mumkin", "Save ~\(Fmt.tokens($0.tokens)) per reply") : nil } ?? tr("Tejash · \(tips.count)", "Savings · \(tips.count)"))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(top?.level == .high ? Brand.warn : Brand.ok)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill((top?.level == .high ? Brand.warn : Brand.ok).opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help(tr("Tokenni qayerda tejash mumkin — bosing", "Where you can save tokens — click"))
        .popover(isPresented: $open, arrowEdge: .bottom) { SavingsList(session: session, tips: tips) }
        .opacity(tips.isEmpty ? 0 : 1)
        .disabled(tips.isEmpty)
    }
}

/// «Bugun» sahifasidagi qisqa karta: eng muhim 2 ta maslahat va nusxalash
struct SavingsCard: View {
    let session: SessionSnap

    var body: some View {
        let tips = SavingsAdvisor.tips(for: session).filter { $0.level >= .notable }
        if !tips.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "leaf.fill").foregroundStyle(Brand.ok)
                    Text(tr("TOKENNI TEJASH · \(session.project.uppercased())", "SAVE TOKENS · \(session.project.uppercased())")).eyebrow(Brand.ok)
                    Spacer()
                    Text(tr("Tejash uchun modelni yoki javob sifatini pasaytirish shart emas", "Saving doesn't mean a weaker model or worse answers")).font(.caption).foregroundStyle(.secondary)
                }
                ForEach(tips.prefix(2)) { TipRow(tip: $0) }
                HStack {
                    HandoffButton(session: session, prominent: false)
                    Spacer()
                }
            }
            .padding(16)
            .card(padding: 0)
        }
    }
}
