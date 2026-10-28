import SwiftUI
import AppKit
import TokenKuzatCore

// Tejash maslahatlari: model va sifat o'zgarmaydi — qayerda token behuda ketayotgani va nima qilish kerakligi.

extension SavingsTip {
    var symbol: String {
        switch kind {
        case .bigContext: return "text.alignleft"
        case .cacheRebuilds: return "clock.arrow.circlepath"
        case .repeatedReads: return "doc.on.doc"
        case .screenshots: return "camera.viewfinder"
        case .errorLoop: return "arrow.triangle.2.circlepath"
        }
    }

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
        return perCall ? "har javobda ~\(Fmt.tokens(tokens)) tejaladi" : "~\(Fmt.tokens(tokens)) token ketgan"
    }
}

/// Davom etish xulosasini nusxalash tugmasi — bosilgach qisqa «Nusxalandi» belgisi
struct HandoffButton: View {
    let session: SessionSnap
    var prominent = true
    @State private var copied = false

    var body: some View {
        Button {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(SavingsAdvisor.handoff(for: session), forType: .string)
            withAnimation(Motion.snappy) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation(Motion.snappy) { copied = false } }
        } label: {
            Label(copied ? "Nusxalandi — yangi sessiyaga qo'ying" : "Davom etish xulosasini nusxalash",
                  systemImage: copied ? "checkmark.circle.fill" : "doc.on.clipboard")
                .font(.callout.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 7)
                .foregroundStyle(prominent ? Color.white : Brand.accent)
                .background(Capsule().fill(prominent ? (copied ? Brand.ok : Brand.accent) : Brand.accentSoft))
        }
        .buttonStyle(.plain)
        .help("Nima qilingani, o'zgargan fayllar va oxirgi holat nusxaga olinadi. Yangi Claude Code sessiyasiga qo'ying — "
              + "Claude kontekstni yo'qotmay, kichik kontekst bilan davom etadi.")
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
                Text("Tokenni tejash").font(.headline)
                Spacer()
                Text("model va sifat o'zgarmaydi").font(.caption).foregroundStyle(.secondary)
            }
            if let left = SavingsAdvisor.cacheTimeLeft(for: session) {
                CacheBanner(until: Date().addingTimeInterval(left), context: session.contextTokens)
            }
            if tips.isEmpty {
                Text("Hozircha isrof ko'rinmayapti — kontekst kichik va qadamlar takrorlanmayapti.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            ForEach(tips) { TipRow(tip: $0) }
            Divider()
            HStack {
                HandoffButton(session: session)
                Spacer()
            }
            Text("Yangi mavzuda yangi sessiya oching va shu xulosani birinchi xabar qilib qo'ying: Claude ishni qayerda "
                 + "to'xtaganini biladi, kontekst esa ~\(Fmt.tokens(SavingsAdvisor.baseline)) dan boshlanadi.")
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
                Text("Kesh yana ~\(Alerts.duration(rem)) saqlanadi — shu vaqt ichida davom etsangiz, \(Fmt.tokens(context)) "
                     + "kontekst qayta yozilmaydi.")
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
                Text(top.flatMap { $0.perCall ? "Tejash: ~\(Fmt.tokens($0.tokens))/javob" : nil } ?? "Tejash · \(tips.count)")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(top?.level == .high ? Brand.warn : Brand.ok)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background(Capsule().fill((top?.level == .high ? Brand.warn : Brand.ok).opacity(0.12)))
        }
        .buttonStyle(.plain)
        .help("Tokenni qayerda tejash mumkin — bosing")
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
                    Text("TOKENNI TEJASH · \(session.project.uppercased())").eyebrow(Brand.ok)
                    Spacer()
                    Text("model va sifat o'zgarmaydi").font(.caption).foregroundStyle(.secondary)
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
