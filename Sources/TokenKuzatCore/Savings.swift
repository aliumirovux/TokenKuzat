import Foundation

// Tejash maslahatchisi: model va sifat o'zgarmaydi — faqat qayerda token behuda ketayotgani ko'rsatiladi.
// Asosiy sarf odatda javob emas, balki har javobdan oldin butun suhbatni (kontekstni) qayta o'qish:
// kontekst 500K bo'lsa, har chaqiruv 500K kesh o'qishi. Shuning uchun eng katta tejash — kontekstni kichik tutish.

public struct SavingsTip: Identifiable, Equatable, Sendable {
    public enum Kind: String, Sendable {
        /// Kontekst katta — yangi sessiya yoki /compact
        case bigContext
        /// Tanaffusdan keyin kesh o'chib, kontekst qaytadan yozilgan
        case cacheRebuilds
        /// Bir fayl qayta-qayta o'qilgan
        case repeatedReads
        /// Ko'p skrinshot — har biri kontekstda qoladi
        case screenshots
        /// Ketma-ket xatolar — bir joyda aylanib qolgan
        case errorLoop
        /// Katta asbob natijalari kontekstda qolib, har chaqiruvda qayta o'qilyapti
        case bigResults
        /// Sessiya ish boshlanmasdan katta kontekst bilan ochilgan (konnektorlar, pluginlar, skill'lar)
        case heavyStart
    }

    public enum Level: Int, Comparable, Sendable {
        case info = 0, notable = 1, high = 2
        public static func < (a: Level, b: Level) -> Bool { a.rawValue < b.rawValue }
    }

    public var id: String { kind.rawValue }
    public let kind: Kind
    public let level: Level
    public let title: String
    public let detail: String
    /// Taxminiy tejash yoki isrof (xom token)
    public let tokens: Int
    /// `tokens` nimaga nisbatan: «har javobda» yoki «jami»
    public let perCall: Bool
}

public enum SavingsAdvisor {
    /// Yangi sessiyaning boshlang'ich konteksti (tizim ko'rsatmalari, CLAUDE.md, asboblar) — taxminan
    public static let baseline = 40_000
    /// Shundan katta kontekst haqida maslahat beriladi
    public static let bigContext = 150_000
    /// Kesh saqlanish muddati: odatda 5 daqiqa, Claude ilovasi va ba'zi sozlamalarda — 1 soat
    public static let cacheTTL: TimeInterval = 5 * 60
    public static let longCacheTTL: TimeInterval = 60 * 60
    /// Terminal (CLI)dagi odatiy boshlang'ich kontekst — shundan kattasi «og'ir boshlanish»
    public static let heavyStart = 80_000

    /// Sessiya qaysi kesh muddatida ishlayapti — oxirgi kesh yozuvidan aniqlanadi
    public static func cacheTTL(for s: SessionSnap) -> TimeInterval {
        s.main?.usage.last(where: { $0.longCache != nil })?.longCache == true ? longCacheTTL : cacheTTL
    }

    /// Birinchi chaqiruvdagi kontekst: tizim ko'rsatmalari, asboblar, CLAUDE.md, ulangan xizmatlar
    public static func startContext(for s: SessionSnap) -> Int? {
        s.main?.usage.first.map(\.context).flatMap { $0 > 0 ? $0 : nil }
    }

    /// Natija keyingi nechta chaqiruvda qayta o'qilgani × hajmi. /compact (kontekst keskin kamaygan) da to'xtaydi.
    public static func carried(_ r: BigResult, usage: [UsagePoint]) -> Int {
        var n = 0, prev: Int?
        for u in usage where u.date > r.date {
            if let p = prev, u.context < p * 6 / 10 { break }
            prev = u.context
            n += 1
        }
        return r.tokens * n
    }

    /// MCP server identifikatori (UUID) olib tashlanadi: «c0f5…83: search_screens» → «search_screens»
    static func cleanLabel(_ label: String) -> String {
        label.replacingOccurrences(of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}:\s*"#,
                                   with: "", options: .regularExpression)
    }

    /// Oxirgi /compact dan keyingi katta natijalar — hozir kontekstda turganlari
    static func liveResults(_ results: [BigResult], usage: [UsagePoint]) -> [BigResult] {
        var lastCompact: Date?
        for (a, b) in zip(usage, usage.dropFirst()) where b.context < a.context * 6 / 10 { lastCompact = b.date }
        guard let c = lastCompact else { return results }
        return results.filter { $0.date > c }
    }

    public static func tips(for s: SessionSnap, now: Date = Date()) -> [SavingsTip] {
        var out: [SavingsTip] = []
        let main = s.main

        // 1) Katta kontekst: har keyingi chaqiruv shuncha ko'p kesh o'qiydi
        let start = startContext(for: s)
        if s.contextTokens >= bigContext {
            let extra = s.contextTokens - (start ?? baseline)
            let calls = Double(main?.calls ?? 0), turns = Double(max(1, s.turns.count))
            let perTurn = calls > 0 ? calls / turns : 6
            let pct = Int((s.contextFraction * 100).rounded())
            out.append(SavingsTip(
                kind: .bigContext, level: s.contextTokens >= 300_000 ? .high : .notable,
                title: tr("Kontekst \(Fmt.tokens(s.contextTokens)) (\(pct)%)", "Context \(Fmt.tokens(s.contextTokens)) (\(pct)%)"),
                detail: tr("Har javobdan oldin Claude butun suhbatni qayta o'qiydi. Yangi mavzu bo'lsa — yangi sessiya oching "
                    + "(«Davom etish xulosasi» bilan); shu mavzu bo'lsa — /compact. So'rov boshiga ~\(Int(perTurn.rounded())) chaqiruv "
                    + "≈ \(Fmt.tokens(Double(extra) * perTurn)) tejaladi.",
                    "Before every reply Claude re-reads the whole conversation. New topic — start a new session "
                    + "(with the «Handoff summary»); same topic — /compact. ~\(Int(perTurn.rounded())) calls per prompt "
                    + "≈ \(Fmt.tokens(Double(extra) * perTurn)) saved."),
                tokens: extra, perCall: true))
        }

        // 2) Kesh qayta yozilishi: kesh muddatidan uzoq tanaffusdan keyin kontekst qaytadan keshlanadi
        let ttl = cacheTTL(for: s)
        let ttlText = ttl >= longCacheTTL ? tr("1 soat", "1 hour") : tr("5 daqiqa", "5 minutes")
        if let usage = main?.usage, usage.count > 1 {
            var rebuilt = 0, count = 0
            for (a, b) in zip(usage, usage.dropFirst()) where b.date.timeIntervalSince(a.date) > ttl {
                if b.tokens.cacheWrite > 50_000 { rebuilt += b.tokens.cacheWrite; count += 1 }
            }
            if count > 0 {
                out.append(SavingsTip(
                    kind: .cacheRebuilds, level: rebuilt > 500_000 ? .notable : .info,
                    title: tr("Tanaffusdan keyin kesh \(count) marta qayta yozildi", count == 1 ? "Cache rewritten once after a break" : "Cache rewritten \(count) times after breaks"),
                    detail: tr("\(ttlText)dan uzoq jim tursangiz, kesh o'chadi va keyingi so'rovda butun kontekst qimmatroq narxda qayta yoziladi. "
                        + "Uzoq tanaffusdan oldin ishni yakunlang yoki qaytgach yangi sessiya oching.",
                        "If you stay idle longer than \(ttlText), the cache expires and the next prompt rewrites the whole context at a higher price. "
                        + "Wrap up before a long break, or start a new session when you're back."),
                    tokens: rebuilt, perCall: false))
            }
        }

        // 3) Bir faylni qayta-qayta o'qish (orada o'zgartirilmagan)
        let steps = s.agents.flatMap(\.steps).sorted { $0.date < $1.date }
        var readsSinceWrite: [String: Int] = [:]
        var extraReads: [String: Int] = [:]
        for st in steps where st.category == .files {
            if st.access == .write { readsSinceWrite[st.targetKey] = 0; continue }
            let n = (readsSinceWrite[st.targetKey] ?? 0) + 1
            readsSinceWrite[st.targetKey] = n
            if n > 1 { extraReads[st.targetName, default: 0] += 1 }
        }
        let extra = extraReads.values.reduce(0, +)
        if extra >= 4 {
            let top = extraReads.sorted { $0.value > $1.value }.prefix(3).map { "\($0.key) ×\($0.value + 1)" }.joined(separator: ", ")
            out.append(SavingsTip(
                kind: .repeatedReads, level: extra >= 12 ? .notable : .info,
                title: tr("\(extra) ta takroriy fayl o'qish", extra == 1 ? "1 repeated file read" : "\(extra) repeated file reads"),
                detail: tr("O'zgarmagan fayl qayta o'qilgan: \(top). Har o'qish fayl hajmicha kontekstni oshiradi. "
                    + "Claude'ga «faylni qayta o'qima, avvalgisidan foydalan» deb aytish yoki faylning kerakli qismini ko'rsatish mumkin.",
                    "Unchanged files were read again: \(top). Each read grows the context by the file's size. "
                    + "You can tell Claude «don't re-read the file, use the earlier copy» or point to the part you need."),
                tokens: extra * 3_000, perCall: false))
        }

        // 4) Skrinshotlar: har rasm kontekstda qoladi
        let shots = steps.filter { $0.category == .mcp && ($0.text.contains("screenshot") || $0.text.contains("zoom")) }.count
        if shots >= 15 {
            out.append(SavingsTip(
                kind: .screenshots, level: shots >= 40 ? .notable : .info,
                title: tr("\(shots) ta skrinshot", shots == 1 ? "1 screenshot" : "\(shots) screenshots"),
                detail: tr("Har bir skrinshot sessiya oxirigacha kontekstda qoladi. Kerakli joyni kichik (zoom) yoki pastroq "
                    + "masshtabda olish, natijani matn bilan tekshirish kontekstni sekinroq o'stiradi.",
                    "Every screenshot stays in context until the session ends. Capturing just the needed area (zoom) or at a lower "
                    + "scale, and checking results as text, grows the context more slowly."),
                tokens: shots * 1_500, perCall: false))
        }

        // 5) Ketma-ket xatolar
        var streak = 0, worst = 0
        for st in steps { streak = st.status == .failed ? streak + 1 : 0; worst = max(worst, streak) }
        if worst >= 3 {
            out.append(SavingsTip(
                kind: .errorLoop, level: .notable,
                title: tr("Ketma-ket \(worst) ta xato", "\(worst) errors in a row"),
                detail: tr("Claude bir joyda aylanib qolgan bo'lishi mumkin. To'xtatib, aniqroq ko'rsatma bersangiz — keyingi urinishlar tejaladi.", "Claude may be going in circles. Stop it and give clearer instructions to save further attempts."),
                tokens: 0, perCall: false))
        }

        // 6) Katta natijalar: har biri keyingi har chaqiruvda qayta o'qiladi
        if let main, !main.bigResults.isEmpty {
            let live = liveResults(main.bigResults, usage: main.usage)
            let inContext = live.reduce(0) { $0 + $1.tokens }
            let costs = main.bigResults.map { ($0, carried($0, usage: main.usage)) }
            let total = costs.reduce(0) { $0 + $1.1 }
            if inContext >= 20_000 || total >= 2_000_000 {
                // Bir xil asbob natijalari birlashtiriladi: «search_screens ×4 — 54,7K»
                var groups: [String: (count: Int, tokens: Int, cost: Int)] = [:]
                for (r, c) in costs {
                    let g = groups[cleanLabel(r.label)] ?? (0, 0, 0)
                    groups[cleanLabel(r.label)] = (g.count + 1, g.tokens + r.tokens, g.cost + c)
                }
                let top = groups.sorted { $0.value.cost > $1.value.cost }.prefix(3)
                    .map { "\($0.key)\($0.value.count > 1 ? " ×\($0.value.count)" : "") — \(Fmt.tokens($0.value.tokens))" }
                    .joined(separator: "; ")
                out.append(SavingsTip(
                    kind: .bigResults, level: total >= 10_000_000 ? .notable : .info,
                    title: tr("\(live.count) ta katta natija kontekstda (~\(Fmt.tokens(inContext)))", live.count == 1 ? "1 large result in context (~\(Fmt.tokens(inContext)))" : "\(live.count) large results in context (~\(Fmt.tokens(inContext)))"),
                    detail: tr("Eng qimmatlari: \(top). Har biri keyingi har javobda qayta o'qiladi. Kerakli qismini so'rang "
                        + "(«oxirgi 30 qator», faylning kerakli joyi) yoki keng qidiruvni yordamchi agentga bering — "
                        + "u ko'p o'qisa ham asosiy suhbatga faqat xulosa qaytadi.",
                        "Most expensive: \(top). Each is re-read on every following reply. Ask for just the part you need "
                        + "(«last 30 lines», the relevant part of a file) or hand broad searches to a subagent — "
                        + "it can read a lot, but only a summary comes back to the main conversation."),
                    tokens: total, perCall: false))
            }
        }

        // 7) Og'ir boshlanish: ish boshlanmasdan kontekst katta — har chaqiruvda takrorlanadi
        if let start, start >= heavyStart, let main, main.calls >= 10 {
            let extra = start - baseline
            // Nomi o'rnida faqat ID (UUID) bo'lgan konnektorlar ro'yxatga kirmaydi — o'qib bo'lmaydi
            let used = (main.resources.first { $0.category == .mcp }?.items.map(\.name) ?? [])
                .filter { $0.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"#, options: .regularExpression) == nil }
                .prefix(6).map { $0 }
            out.append(SavingsTip(
                kind: .heavyStart, level: main.calls >= 150 ? .notable : .info,
                title: tr("Sessiya \(Fmt.tokens(start)) bilan boshlangan", "Session started at \(Fmt.tokens(start))"),
                detail: tr("Bu — ish boshlanmasdan oldingi qism: tizim ko'rsatmalari, ulangan konnektorlar, pluginlar va skill'lar ro'yxati. "
                    + "Terminalda sessiyalar ~40–65K dan boshlanadi. Claude ilovasida shu ishga kerakmas konnektorlarni o'chirsangiz, "
                    + "har chaqiruv yengillashadi"
                    + (used.isEmpty ? " — bu sessiyada birorta ham tashqi xizmat ishlatilmagan." : ". Bu sessiyada ishlatilganlari: \(used.joined(separator: ", ")).") ,
                    "This is what loads before any work: system instructions, connected connectors, the list of plugins and skills. "
                    + "In the terminal, sessions start at ~40–65K. Turning off connectors this task doesn't need in the Claude app "
                    + "makes every call lighter"
                    + (used.isEmpty ? " — this session didn't use a single external service." : ". Used in this session: \(used.joined(separator: ", ")).")) ,
                tokens: extra, perCall: true))
        }

        return out.sorted { $0.level > $1.level }
    }

    /// Kesh hozir saqlanib turibdimi va qancha vaqti qoldi (tinch sessiyada)
    public static func cacheTimeLeft(for s: SessionSnap, now: Date = Date()) -> TimeInterval? {
        guard s.state == .idle, s.contextTokens >= bigContext, let la = s.lastActivity else { return nil }
        let left = cacheTTL(for: s) - now.timeIntervalSince(la)
        return left > 0 ? left : nil
    }

    /// Yangi sessiyada sifat tushmasligi uchun «davom etish xulosasi»: so'nggi vazifalar, o'zgargan fayllar, oxirgi holat
    public static func handoff(for s: SessionSnap, lastTurns: Int = 6) -> String {
        var lines: [String] = []
        lines.append(tr("Bu — oldingi Claude Code sessiyasining davomi (\(s.project)). Quyidagi xulosaga tayanib ishni davom ettir.", "This continues a previous Claude Code session (\(s.project)). Continue the work based on the summary below."))
        let turns = s.turns.filter { !$0.isContinuation }.suffix(lastTurns)
        if !turns.isEmpty {
            lines.append("")
            lines.append(tr("So'nggi vazifalar:", "Recent tasks:"))
            for t in turns { lines.append("- #\(t.id): \(t.prompt)") }
        }
        let changed = Array(Set(s.agents.flatMap(\.steps).filter { $0.category == .files && $0.access == .write }
            .map { $0.targetKey.replacingOccurrences(of: "files|", with: "") })).sorted()
        if !changed.isEmpty {
            lines.append("")
            lines.append(tr("O'zgartirilgan fayllar:", "Changed files:"))
            for f in changed.prefix(25) { lines.append("- \(f)") }
        }
        if let reply = s.notes.last(where: { $0.kind == .reply && $0.agent == nil }) {
            lines.append("")
            lines.append(tr("Oxirgi holat (oldingi javobdan):", "Last state (from the previous reply):"))
            lines.append(String(reply.text.prefix(1200)))
        }
        lines.append("")
        lines.append(tr("Avval kerakli fayllarni o'qib chiq, keyin davom et. Allaqachon bajarilganlarni qayta qilma.", "Read the relevant files first, then continue. Don't redo what's already done."))
        return lines.joined(separator: "\n")
    }
}
