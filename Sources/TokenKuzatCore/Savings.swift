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

    /// Kesh sovigani: tanaffusdan keyingi chaqiruv oldingi kontekstni keshdan o'qiy olmay, qaytadan yozgan
    public struct CacheMiss: Equatable, Sendable {
        public let date: Date
        /// Oldingi chaqiruvdan beri o'tgan vaqt
        public let gap: TimeInterval
        /// Qaytadan yozilgan eski kontekst — kesh iliq bo'lganda arzon o'qilardi
        public let tokens: Int
        public let longCache: Bool
        /// Ortiqcha narx vaznli tokenda: yozish narxi va o'qish narxi farqi
        public var weighted: Double {
            Double(tokens) * ((longCache ? Pricing.cacheWrite1h : Pricing.cacheWrite5m) - Pricing.cacheRead)
        }
    }

    /// Tanaffus uzunligi: «47 daq», «2 soat 10 daq»
    static func breakText(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return m >= 60 ? tr("\(m / 60) soat \(m % 60) daq", "\(m / 60) h \(m % 60) min") : tr("\(m) daq", "\(m) min")
    }

    /// Shundan kichik qayta yozuv sanalmaydi — qisqa sessiya boshidagi shovqin
    static let minCacheMiss = 20_000

    /// Tanaffusdan keyin kesh sovigan chaqiruvlar — taxmin emas, transkriptdagi haqiqiy raqamlardan:
    /// tanaffus o'sha paytdagi kesh muddatidan (5 daqiqa / 1 soat) uzun, keyingi chaqiruv eski kontekstning yarmini ham
    /// keshdan o'qimagan va uni qaytadan yozgan. /compact (kontekst keskin kichraygan) sanalmaydi.
    public static func cacheMisses(for s: SessionSnap, from: Date = .distantPast) -> [CacheMiss] {
        guard let usage = s.main?.usage, usage.count > 1 else { return [] }
        var out: [CacheMiss] = []
        var long = false
        for (a, b) in zip(usage, usage.dropFirst()) {
            if let l = a.longCache { long = l }
            let gap = b.date.timeIntervalSince(a.date)
            guard b.date >= from, gap > (long ? longCacheTTL : cacheTTL),
                  b.context >= a.context * 6 / 10, b.tokens.cacheRead < a.context / 2 else { continue }
            let rewritten = min(b.tokens.cacheWrite, a.context)
            if rewritten >= minCacheMiss {
                out.append(CacheMiss(date: b.date, gap: gap, tokens: rewritten, longCache: b.longCache ?? long))
            }
        }
        return out
    }

    /// Birinchi chaqiruvdagi kontekst: tizim ko'rsatmalari, asboblar, CLAUDE.md, ulangan xizmatlar
    public static func startContext(for s: SessionSnap) -> Int? {
        (s.main?.startContext ?? s.main?.usage.first?.context).flatMap { $0 > 0 ? $0 : nil }
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

    public static func tips(for s: SessionSnap, now: Date = Date(),
                            instructions: (String) -> [InstructionFile] = { InstructionFiles.read($0) }) -> [SavingsTip] {
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
                    + "(«Yangi sessiyada davom ettirish» tugmasi bilan); shu mavzu bo'lsa — /compact. So'rov boshiga ~\(Int(perTurn.rounded())) chaqiruv "
                    + "≈ \(Fmt.tokens(Double(extra) * perTurn)) tejaladi.",
                    "Before every reply Claude re-reads the whole conversation. New topic — start a new session "
                    + "(with «Continue in a new session»); same topic — /compact. ~\(Int(perTurn.rounded())) calls per prompt "
                    + "≈ \(Fmt.tokens(Double(extra) * perTurn)) saved."),
                tokens: extra, perCall: true))
        }

        // 2) Kesh qayta yozilishi: kesh muddatidan uzoq tanaffusdan keyin kontekst qaytadan keshlanadi
        let misses = cacheMisses(for: s)
        if !misses.isEmpty {
            let rebuilt = misses.reduce(0) { $0 + $1.tokens }
            let worst = misses.max { $0.tokens < $1.tokens }!
            let ttlText = worst.longCache ? tr("1 soat", "1 hour") : tr("5 daqiqa", "5 minutes")
            let count = misses.count
            out.append(SavingsTip(
                kind: .cacheRebuilds, level: rebuilt > 500_000 ? .notable : .info,
                title: tr("Tanaffusdan keyin kesh \(count) marta qayta yozildi", count == 1 ? "Cache rewritten once after a break" : "Cache rewritten \(count) times after breaks"),
                detail: tr("Eng kattasi: \(breakText(worst.gap)) tanaffusdan keyin \(Fmt.tokens(worst.tokens)) kontekst qaytadan yozildi. "
                    + "\(ttlText)dan uzoq jim tursangiz, kesh o'chadi va keyingi so'rovda kontekst qimmatroq narxda qayta yoziladi. "
                    + "Uzoq tanaffusdan oldin ishni yakunlang yoki qaytgach yangi sessiya oching.",
                    "Largest: \(Fmt.tokens(worst.tokens)) of context rewritten after a \(breakText(worst.gap)) break. "
                    + "If you stay idle longer than \(ttlText), the cache expires and the next prompt rewrites the context at a higher price. "
                    + "Wrap up before a long break, or start a new session when you're back."),
                tokens: rebuilt, perCall: false))
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
            let used = (main.resources.first { $0.category == .mcp }?.items ?? [])
                .filter { $0.id.range(of: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-"#, options: .regularExpression) == nil }
                .prefix(6).map(\.name)
            // InstructionsLoaded hook'i yozgan CLAUDE.md va qoida fayllari — kattasidan
            let files = instructions(s.id).filter { $0.tokens > 0 }.sorted { $0.tokens > $1.tokens }
            let listed = files.prefix(5).map { "\(InstructionFiles.shortName($0.path)) \(Fmt.tokens($0.tokens))" }.joined(separator: ", ")
            let filesNote = files.isEmpty ? "" : tr(" Ko'rsatma fayllari (\(Fmt.tokens(files.reduce(0) { $0 + $1.tokens }))): \(listed) — "
                                                    + "keraksiz qismini qisqartirsangiz, har sessiya yengilroq boshlanadi.",
                                                    " Instruction files (\(Fmt.tokens(files.reduce(0) { $0 + $1.tokens }))): \(listed) — "
                                                    + "trimming what's not needed makes every session start lighter.")
            out.append(SavingsTip(
                kind: .heavyStart, level: main.calls >= 150 ? .notable : .info,
                title: tr("Sessiya \(Fmt.tokens(start)) bilan boshlangan", "Session started at \(Fmt.tokens(start))"),
                detail: tr("Bu — ish boshlanmasdan oldingi qism: tizim ko'rsatmalari, ulangan konnektorlar, pluginlar va skill'lar ro'yxati. "
                    + "Terminalda sessiyalar ~40–65K dan boshlanadi. Claude ilovasida shu ishga kerakmas konnektorlarni o'chirsangiz, "
                    + "har chaqiruv yengillashadi"
                    + (used.isEmpty ? " — bu sessiyada birorta ham tashqi xizmat ishlatilmagan." : ". Bu sessiyada ishlatilganlari: \(used.joined(separator: ", ")).") + filesNote,
                    "This is what loads before any work: system instructions, connected connectors, the list of plugins and skills. "
                    + "In the terminal, sessions start at ~40–65K. Turning off connectors this task doesn't need in the Claude app "
                    + "makes every call lighter"
                    + (used.isEmpty ? " — this session didn't use a single external service." : ". Used in this session: \(used.joined(separator: ", ")).") + filesNote),
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
    /// Xulosa suhbat tilida yoziladi (ilova tilida emas) — Claude javoblarni ham shu tilda beradi
    public static func handoff(for s: SessionSnap, lastTurns: Int = 6,
                               gitLines: ([String]) -> [String] = GitState.lines,
                               transcripts: (SessionSnap) -> [String] = { transcriptPaths(for: $0) }) -> String {
        Lang.with(english: conversationEnglish(s)) {
            handoffText(s, lastTurns: lastTurns, gitLines: gitLines, transcripts: transcripts(s))
        }
    }

    /// Xulosadagi yozuvlar bo'limining sarlavhasi — keyingi ko'chirishda shu bo'yicha oldingi yozuvlar olib o'tiladi
    static let transcriptsHeader = ["Oldingi sessiya yozuvlari", "Previous session transcripts"]

    /// Sessiya yozuvlari (.jsonl): shu sessiyaniki va u davom ettirgan oldingi sessiyalarniki (ko'chirish xabaridan).
    /// Xulosaga hammasi sig'maydi — yangi sessiya undan tushib qolgan jadval, taklif yoki qarorni shu fayllardan grep bilan topadi
    public static func transcriptPaths(for s: SessionSnap, roots: [URL] = Engine.defaultRoots(), fm: FileManager = .default) -> [String] {
        var paths: [String] = []
        for root in roots {
            guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: nil),
                  let f = dirs.lazy.map({ $0.appendingPathComponent(s.id + ".jsonl") })
                    .first(where: { fm.fileExists(atPath: $0.path) }) else { continue }
            paths.append(f.path)
            break
        }
        if let first = s.turns.first(where: { AutoHandoffRule.isHandoffPrompt($0.prompt) }) {
            paths += carriedTranscripts(first.prompt).filter { !paths.contains($0) }
        }
        return Array(paths.prefix(4))
    }

    /// Ko'chirish xabaridagi oldingi yozuvlar ro'yxati
    static func carriedTranscripts(_ prompt: String) -> [String] {
        var out: [String] = []
        var inside = false
        for line in prompt.components(separatedBy: "\n") {
            if transcriptsHeader.contains(where: { line.hasPrefix($0) }) { inside = true; continue }
            guard inside else { continue }
            guard line.hasPrefix("- "), line.hasSuffix(".jsonl") else { break }
            out.append(String(line.dropFirst(2)))
        }
        return out
    }

    /// Foydalanuvchi xabarlarining tili; aniqlanmasa — ilova tili
    public static func conversationEnglish(_ s: SessionSnap) -> Bool {
        Lang.detectEnglish(s.turns.suffix(10).map(\.prompt)) ?? Lang.isEnglish
    }

    /// Yangi sessiya ochiladigan loyiha papkasi: sessiya papkasi, u Claude ilovasining vaqtinchalik papkasi bo'lsa —
    /// eng ko'p fayl yozilgan git repo (ish aslida o'sha yerda bo'lgan). Topilmasa — nil
    public static func projectFolder(for s: SessionSnap, fm: FileManager = .default) -> String? {
        if let dir = s.cwd, !HandoffStore.isScratch(dir), fm.fileExists(atPath: dir) { return dir }
        let files = changedFiles(s)
        let roots = GitState.roots(for: files, fm: fm).filter { !HandoffStore.isScratch($0) }
        func count(_ root: String) -> Int { files.filter { $0.hasPrefix(root + "/") }.count }
        return roots.max { count($0) < count($1) }
    }

    /// Sessiyada yozilgan fayllar (tartiblangan)
    /// Vaqtinchalik fayllar (scratchpad, /tmp) kirmaydi — yangi sessiya ularga tayanmasin
    static func changedFiles(_ s: SessionSnap) -> [String] {
        Array(Set(s.agents.flatMap(\.steps).filter { $0.category == .files && $0.access == .write }
            .map { $0.targetKey.replacingOccurrences(of: "files|", with: "") }
            .filter { !isTemporary($0) })).sorted()
    }

    static func isTemporary(_ path: String) -> Bool {
        ["/tmp/", "/private/tmp/"].contains { path.hasPrefix($0) }
            || path.contains("/scratchpad/") || HandoffStore.isScratch(path)
    }

    /// Oxirgi so'rovda foydalanuvchiga berilgan va javobsiz qolgan savol: yakuniy savol («ask») yoki
    /// AskUserQuestion savoli; ular bo'lmasa — oxirgi javobning «?» bilan tugagan so'nggi qatori
    static func pendingQuestion(_ s: SessionSnap) -> String? {
        let since = s.turns.last?.start ?? .distantPast
        for st in (s.main?.steps ?? []).reversed() where st.date >= since {
            if let input = st.input, let q = jsonField(input, ["ask", "question"]) { return q }
        }
        let last = lastReply(s).map { HandoffNote.extract(from: $0.text)?.rest ?? $0.text }?.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }.last { !$0.isEmpty }
        return last.flatMap { $0.hasSuffix("?") ? $0 : nil }
    }

    /// Asbob kiritmasidagi (JSON, kesilgan bo'lishi mumkin) birinchi topilgan matn maydoni
    static func jsonField(_ json: String, _ keys: [String]) -> String? {
        for key in keys {
            let pattern = "\"" + key + #""\s*:\s*"((?:[^"\\]|\\.)*)""#
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: json, range: NSRange(json.startIndex..., in: json)),
                  let r = Range(m.range(at: 1), in: json),
                  let v = try? JSONSerialization.jsonObject(with: Data(("\"" + json[r] + "\"").utf8), options: .fragmentsAllowed) as? String,
                  !v.isEmpty else { continue }
            return v
        }
        return nil
    }

    /// So'nggi javoblardagi eng oxirgi raqamli ro'yxat yoki jadval (kamida 2 qator) — o'zgarishsiz
    static func lastList(_ s: SessionSnap, replies: Int = 3, max: Int = 2500) -> String? {
        let item = try! NSRegularExpression(pattern: #"^\s*(\d+[.)]\s|\|)"#)
        for note in s.notes.filter({ $0.kind == .reply && $0.agent == nil }).suffix(replies).reversed() {
            var blocks: [[String]] = [], cur: [String] = []
            for line in note.text.components(separatedBy: "\n") {
                let ns = line as NSString
                if item.firstMatch(in: line, range: NSRange(location: 0, length: ns.length)) != nil {
                    cur.append(line)
                } else if !cur.isEmpty, line.hasPrefix("   ") || line.hasPrefix("\t") || line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                    cur.append(line)   // band ichidagi davom qatori
                } else if !cur.isEmpty {
                    blocks.append(cur); cur = []
                }
            }
            if !cur.isEmpty { blocks.append(cur) }
            if let b = blocks.last(where: { $0.count >= 2 }) {
                let text = b.joined(separator: "\n")
                return text.count > max ? String(text.prefix(max)) + "…" : text
            }
        }
        return nil
    }

    /// Suhbatdagi havolalar va Figma fayl kalitlari — eng so'nggilari. Yangi sessiya ularni eski yozuvdan qidirib yurmasin
    static func resources(_ s: SessionSnap, limit: Int = 12) -> [String] {
        // So'rovlardan faqat ma'nolilari — xulosadan tashlangan shovqin (yolg'iz havola, «Ha») qaytib kirmasin
        var texts = meaningfulTurns(s).map(\.text) + s.notes.filter { $0.kind == .reply }.map(\.text)
        texts += s.agents.flatMap { $0.steps.compactMap(\.input) }
        let url = try! NSRegularExpression(pattern: #"https?://[^\s)\]"'<>`«»\\]+"#)
        let key = try! NSRegularExpression(pattern: #"fileKey\\?"?\s*[:=]\s*\\?"?([A-Za-z0-9]{10,})"#)
        var out: [String] = []
        func add(_ v: String) {
            var v = v
            while let c = v.last, ".,;:!?".contains(c) { v.removeLast() }
            // Sessiya yozuvlari (.jsonl) yuqorida alohida; mahalliy server manzili ham resurs emas
            // shablon («{token}»), IPv6 bo'lagi va Claude imzosi ham emas
            guard !v.hasSuffix(".jsonl"), !v.contains("://localhost"), !v.contains("://127.0.0.1"), !v.contains("://["),
                  !v.contains("{"), !v.hasPrefix("https://claude.com/claude-code") else { return }
            out.removeAll { $0 == v }
            out.append(v)
        }
        for t in texts {
            let ns = t as NSString
            for m in url.matches(in: t, range: NSRange(location: 0, length: ns.length)) { add(ns.substring(with: m.range)) }
            for m in key.matches(in: t, range: NSRange(location: 0, length: ns.length)) { add("Figma fileKey: " + ns.substring(with: m.range(at: 1))) }
        }
        // Asbob kirishi yozuvda kesilgan bo'lishi mumkin — boshqa kalitning yoki havolaning boshi bo'lgan kalit tashlanadi
        let keyPrefix = "Figma fileKey: "
        let all = out
        out.removeAll { r in
            guard r.hasPrefix(keyPrefix) else { return false }
            let k = String(r.dropFirst(keyPrefix.count))
            return all.contains { o in o != r && (o.hasPrefix(keyPrefix) ? o.dropFirst(keyPrefix.count).hasPrefix(k) : o.contains(k)) }
        }
        return Array(out.suffix(limit))
    }

    static func lastReply(_ s: SessionSnap) -> NoteSnap? {
        s.notes.last { $0.kind == .reply && $0.agent == nil }
    }

    /// Matnning oxiri, gap yoki xatboshi chegarasidan boshlab
    static func tail(_ text: String, max: Int) -> String {
        guard text.count > max else { return text }
        let cut = String(text.suffix(max))
        let window = cut.prefix(300)
        if let r = window.range(of: "\n") ?? window.range(of: ". ") {
            return "…" + cut[r.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "…" + cut
    }

    /// Xulosaga kiradigan so'rovlar: oldingi ko'chirish xabarlari, yolg'iz havolalar va «Ha, yasa» kabi qisqa javoblar
    /// tushib qoladi (oxirgisi bundan mustasno — kutilayotgan qaror shunda bo'lishi mumkin)
    static func meaningfulTurns(_ s: SessionSnap) -> [TurnSnap] {
        let turns = s.turns.filter { !$0.isContinuation && !AutoHandoffRule.isHandoffPrompt($0.prompt) }
        return turns.enumerated().filter { i, t in
            let p = t.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty || p.range(of: #"^https?://\S+$"#, options: .regularExpression) != nil { return false }
            return i == turns.count - 1 || p.count >= AutoHandoffRule.meaningfulLength
        }.map(\.element)
    }

    /// Claude yozgan ko'chirish eslatmasi — faqat oxirgi so'rovga berilgan javobdan (eskisi ishning hozirgi holatini aytmaydi)
    static func handoffNote(_ s: SessionSnap) -> (note: String, reply: NoteSnap)? {
        let since = s.turns.last?.start ?? .distantPast
        for n in s.notes.reversed() where n.kind == .reply && n.agent == nil && n.date >= since {
            if let x = HandoffNote.extract(from: n.text) { return (x.note, n) }
        }
        return nil
    }

    /// Ish nomi: Claude eslatmasidagi «Ish», oldingi sessiya nomi, so'nggi ma'noli vazifa. 60 belgigacha, so'z chegarasida
    static func handoffTask(_ s: SessionSnap, note: String? = nil) -> String? {
        var found = note.flatMap { HandoffNote.field($0, ["Ish", "Task"]) }
        if found == nil, s.title.hasPrefix("↪ ") {
            // Ko'chirilgan sessiyada yangi mavzu boshlangan bo'lsa, meros nom eskiradi — o'zidagi so'nggi uzun so'rov olinadi
            let own = meaningfulTurns(s).filter { $0.prompt.count >= topicLength }
            if own.count >= 2 { found = own.last?.prompt }
        }
        // Meros nom «↪ Loyiha — ish»: loyiha nomi kartada va sarlavhada alohida turadi, takrorlanmasin
        if found == nil, s.title.hasPrefix("↪ ") { found = dropProject(String(s.title.dropFirst(2)), s) }
        var name = found ?? s.title
        // Nomsiz yoki eski usulda ko'chirilgan sessiyaning umumiy nomi — ish nomi emas
        let generic = ["Nomsiz sessiya", "Untitled session", "Oldingi sessiya davomi", "Continued session"]
        if name.trimmingCharacters(in: .whitespaces).isEmpty || generic.contains(name) || AutoHandoffRule.isHandoffPrompt(name) {
            name = meaningfulTurns(s).last { $0.prompt.count >= AutoHandoffRule.meaningfulLength }?.prompt ?? ""
        }
        name = name.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        guard name.count > 60 else { return name }
        let cut = String(name.prefix(60))
        let word = cut.range(of: " ", options: .backwards).map { String(cut[..<$0.lowerBound]) } ?? cut
        return (word.count >= 30 ? word : cut) + "…"
    }

    /// Ko'chirilgan sessiyada shundan uzun so'rov — yangi mavzu belgisi
    static let topicLength = 40

    /// «Loyiha — ish» → «ish» (loyiha — sessiya papkasi yoki loyiha nomi)
    static func dropProject(_ title: String, _ s: SessionSnap) -> String {
        var t = title
        for p in Set([s.project] + [s.cwd.map { URL(fileURLWithPath: $0).lastPathComponent }].compactMap { $0 }) where !p.isEmpty {
            while t.hasPrefix(p + " — ") { t = String(t.dropFirst(p.count + 3)) }
        }
        return t
    }

    private static func handoffText(_ s: SessionSnap, lastTurns: Int, gitLines: ([String]) -> [String],
                                    transcripts: [String]) -> String {
        var lines: [String] = []
        // Birinchi qator — «↪ ish»: Claude ilovasi sessiya nomini birinchi xabardan yasaydi.
        // Loyiha nomi bu yerda yo'q — aks holda hamma nom bir xil so'z bilan boshlanib, ro'yxatda farqlanmaydi
        let folder = projectFolder(for: s)
        let note = handoffNote(s)
        let project = folder.map { URL(fileURLWithPath: $0).lastPathComponent }
            ?? (s.cwd.map(HandoffStore.isScratch) == true ? nil : s.project)
        lines.append(AutoHandoffRule.headline(project: nil, task: handoffTask(s, note: note?.note)))
        lines.append("")
        lines.append(tr("Bu — oldingi Claude Code sessiyasining davomi (\(project ?? s.project)). Quyidagi xulosaga tayanib ishni davom ettir.", "This continues a previous Claude Code session (\(project ?? s.project)). Continue the work based on the summary below."))
        if let folder {
            lines.append(tr("Loyiha papkasi: \(folder)", "Project folder: \(folder)"))
        }
        // Boshida: xulosa 8000 belgida kesiladi, yo'l esa kesilmasin
        if !transcripts.isEmpty {
            lines.append("")
            lines.append(tr(transcriptsHeader[0] + " (butun suhbat shu yerda). Foydalanuvchi xulosada yo'q narsani eslasa — oldingi jadval, "
                            + "taklif, qaror yoki muhokama — faylni butunlay o'qima, grep bilan kerakli joyini top:",
                            transcriptsHeader[1] + " (the whole conversation is there). If the user mentions something missing here — an earlier "
                            + "table, proposal, decision or discussion — don't read the whole file, grep for the relevant part:"))
            for p in transcripts { lines.append("- \(p)") }
        }
        if let note {
            lines.append("")
            lines.append(tr("Claude'ning ko'chirish eslatmasi (oldingi sessiya oxirida o'zi yozgan — asosan shunga tayan):",
                            "Claude's handoff note (written at the end of the previous session — rely on it first):"))
            lines.append(note.note)
        }
        let turns = meaningfulTurns(s).suffix(lastTurns)
        if !turns.isEmpty {
            lines.append("")
            lines.append(tr("So'nggi vazifalar:", "Recent tasks:"))
            // So'nggi ikkitasi to'liq: odatda asosiy talab va kutilayotgan ish shularda
            let full = Set(turns.suffix(2).map(\.id))
            for t in turns {
                guard full.contains(t.id) else {
                    let p = t.prompt.replacingOccurrences(of: "\n", with: " ")
                    lines.append("- #\(t.id): " + (p.count > 400 ? String(p.prefix(400)) + "…" : p))
                    continue
                }
                let body = t.text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }.joined(separator: "\n  ")
                lines.append("- #\(t.id): " + (body.count > 1500 ? String(body.prefix(1500)) + "…" : body))
            }
        }
        let changed = changedFiles(s)
        if !changed.isEmpty {
            lines.append("")
            lines.append(tr("O'zgartirilgan fayllar:", "Changed files:"))
            for f in changed.prefix(25) { lines.append("- \(f)") }
        }
        let git = gitLines(changed)
        if !git.isEmpty {
            lines.append("")
            lines.append(tr("Git holati (ko'chirish paytida):", "Git state (at handoff time):"))
            lines += git
        }
        var lastTail = ""
        if let reply = lastReply(s) {
            // Eslatma bor javobdan eslatmaning o'zi olib tashlanadi — yuqorida bor
            let text = reply.id == note?.reply.id ? (HandoffNote.extract(from: reply.text)?.rest ?? reply.text) : reply.text
            if !text.isEmpty {
                lastTail = tail(text, max: 1500)
                lines.append("")
                lines.append(tr("Oxirgi holat (oldingi javobdan):", "Last state (from the previous reply):"))
                lines.append(lastTail)
            }
        }
        // Foydalanuvchi «2ni boshla», «keyingi bandlar» deydi — ro'yxat o'zi bo'lmasa, yangi sessiya eski yozuvni qidiradi
        if let list = lastList(s), !lastTail.contains(list) {
            lines.append("")
            lines.append(tr("Oxirgi ro'yxat (oldingi javoblardan, o'zgarishsiz — foydalanuvchi band raqamiga ishora qilishi mumkin):",
                            "Last list (from previous replies, verbatim — the user may refer to an item by number):"))
            lines.append(list)
        }
        let res = resources(s)
        if !res.isEmpty {
            lines.append("")
            lines.append(tr("Resurslar (havolalar va fayl kalitlari — aniq shu qiymatlarni ishlat):",
                            "Resources (links and file keys — use these exact values):"))
            for r in res { lines.append("- \(r)") }
        }
        if let tools = s.main?.topTools.prefix(8), !tools.isEmpty {
            lines.append("")
            lines.append(tr("Ishlatilgan asboblar (qaysi usul bilan ishlangani): ", "Tools used (how the work was done): ")
                         + tools.map { "\($0.name) \($0.count)" }.joined(separator: ", "))
        }
        if let q = pendingQuestion(s) {
            lines.append("")
            lines.append(tr("Kutilayotgan qaror (foydalanuvchi hali javob bermagan): \(q)",
                            "Pending decision (the user hasn't answered yet): \(q)"))
        }
        lines.append("")
        lines.append(tr("Avval kerakli fayllarni o'qib chiq, keyin davom et. Allaqachon bajarilganlarni qayta qilma. "
                        + "Oxirgi javob rejalashtirilgan, lekin hali bajarilmagan qadamni aytayotgan bo'lishi mumkin — "
                        + "uni bajarilgan deb hisoblama, avval tekshir (git, fayllar, o'rnatilgan versiya).",
                        "Read the relevant files first, then continue. Don't redo what's already done. "
                        + "The last reply may describe a step that was planned but not yet done — don't assume it happened; "
                        + "check first (git, files, installed version)."))
        return lines.joined(separator: "\n")
    }
}
