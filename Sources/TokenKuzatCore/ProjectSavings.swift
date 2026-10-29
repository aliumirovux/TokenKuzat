import Foundation

// Loyihalar bo'yicha token nazorati: qaysi loyiha ko'p yeyapti, qayerda isrof bor va uni qanday tuzatish mumkin.
// Sessiya maslahatlari (SavingsAdvisor) loyiha bo'yicha jamlanadi; katta kontekst va og'ir boshlanish uchun
// isrof haqiqiy chaqiruvlardan hisoblanadi — faqat oldini olsa bo'ladigan qism: chegaradan (150K / 80K) ortig'i.
// Isrofning deyarli hammasi kesh o'qish (arzon), shuning uchun vaznli bahosi xomdan ancha kichik.

public enum SavingsPeriod: String, CaseIterable, Identifiable, Sendable {
    case today, week
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .today: return tr("Bugun", "Today")
        case .week: return tr("7 kun", "7 days")
        }
    }

    public func start(now: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: now)
        switch self {
        case .today: return day
        case .week: return calendar.date(byAdding: .day, value: -6, to: day) ?? day
        }
    }
}

/// Loyihadagi bir turdagi isrof — barcha sessiyalar bo'yicha jamlangan
public struct ProjectIssue: Identifiable, Sendable {
    public var id: String { kind.rawValue }
    public let kind: SavingsTip.Kind
    public let level: SavingsTip.Level
    /// Necha sessiyada uchragan
    public let sessions: Int
    /// Taxminiy isrof (xom token)
    public let waste: Int
    /// Shu isrof vaznli tokenda (kesh o'qish ×0,1, kesh yozish ×1,25)
    public let weighted: Double
    /// Eng og'ir sessiyadagi aniq tafsilot (fayl nomlari, asboblar)
    public let detail: String

    /// Qanday tuzatiladi: ilovaning o'zida (yangi sessiya), Claude orqali (CLAUDE.md, konnektorlar) yoki odat
    public enum Fix: Sendable { case newSession, claudeRules, connectors, habit }

    public var fix: Fix {
        switch kind {
        case .bigContext: return .newSession
        case .heavyStart: return .connectors
        case .repeatedReads, .bigResults, .screenshots: return .claudeRules
        case .cacheRebuilds, .errorLoop: return .habit
        }
    }

    public var title: String {
        switch kind {
        case .bigContext: return tr("Katta kontekst qayta o'qilyapti", "Large context re-read on every reply")
        case .cacheRebuilds: return tr("Tanaffusdan keyin kesh qayta yozilgan", "Cache rewritten after breaks")
        case .repeatedReads: return tr("Bir fayl qayta-qayta o'qilgan", "Same files read again and again")
        case .screenshots: return tr("Ko'p skrinshot", "Many screenshots")
        case .errorLoop: return tr("Ketma-ket xatolar", "Errors in a row")
        case .bigResults: return tr("Katta asbob natijalari kontekstda", "Large tool results kept in context")
        case .heavyStart: return tr("Sessiya og'ir boshlanadi (konnektorlar, pluginlar)", "Sessions start heavy (connectors, plugins)")
        }
    }

    /// Qisqa yechim — foydalanuvchi uchun
    public var remedy: String {
        switch kind {
        case .bigContext:
            return tr("Yangi mavzuda — xulosa bilan yangi sessiya, shu mavzuda — /compact.",
                      "New topic — a new session with a summary; same topic — /compact.")
        case .cacheRebuilds:
            return tr("Uzoq tanaffusdan oldin ishni yakunlang yoki qaytgach yangi sessiya oching.",
                      "Wrap up before a long break, or start a new session when you're back.")
        case .repeatedReads:
            return tr("CLAUDE.md'ga qoida: o'zgarmagan faylni qayta o'qima, kerakli qismini o'qi.",
                      "A CLAUDE.md rule: don't re-read unchanged files, read only the needed part.")
        case .screenshots:
            return tr("CLAUDE.md'ga qoida: skrinshotni kichik masshtabda yoki faqat kerakli joyini ol, natijani matn bilan tekshir.",
                      "A CLAUDE.md rule: take screenshots at a small scale or just the needed area, verify results as text.")
        case .errorLoop:
            return tr("Claude aylanib qolsa — to'xtatib, aniqroq ko'rsatma bering.",
                      "If Claude goes in circles, stop it and give clearer instructions.")
        case .bigResults:
            return tr("CLAUDE.md'ga qoida: uzun chiqishni qisqartir (head/tail, grep), keng qidiruvni yordamchi agentga ber.",
                      "A CLAUDE.md rule: trim long output (head/tail, grep), hand broad searches to a subagent.")
        case .heavyStart:
            return tr("Bu loyihada ishlatilmaydigan MCP serverlar va pluginlarni o'chiring.",
                      "Turn off MCP servers and plugins this project doesn't use.")
        }
    }
}

/// Bitta loyiha: davr ichidagi sarf, isroflar va tuzatish uchun ma'lumot
public struct ProjectReport: Identifiable, Sendable {
    public var id: String { project }
    public let project: String
    /// Loyiha papkasi (eng so'nggi sessiyadan) — Claude Code shu yerda ochiladi
    public let cwd: String?
    public let tokens: TokenCounts
    public let sessions: Int
    public let prompts: Int
    public let lastActivity: Date?
    public let active: Bool
    /// Isrofi kattasidan kichigiga
    public let issues: [ProjectIssue]
    /// Eng so'nggi sessiya id — «yangi sessiyada davom ettirish» uchun
    public let latestSession: String?

    /// Taxminiy isrof jami (xom token)
    public var waste: Int { issues.reduce(0) { $0 + $1.waste } }

    /// Isrof tanlangan hisoblash usulida
    public func waste(_ mode: CountMode) -> Double {
        mode == .weighted ? issues.reduce(0) { $0 + $1.weighted } : Double(waste)
    }

    /// Isrof loyiha sarfining qancha qismi (0…1)
    public func wasteShare(_ mode: CountMode) -> Double {
        let t = tokens.value(mode)
        return t > 0 ? min(1, waste(mode) / t) : 0
    }
}

public enum ProjectSavings {
    /// Davr ichida faol bo'lgan loyihalar, sarfi kattasidan kichigiga
    public static func reports(_ snap: Snapshot, period: SavingsPeriod, now: Date = Date(),
                               calendar: Calendar = .current, mode: CountMode = .raw) -> [ProjectReport] {
        let from = period.start(now: now, calendar: calendar)
        let byProject = Dictionary(grouping: snap.sessions.filter { s in
            s.turns.contains { $0.end >= from } || (s.lastActivity ?? .distantPast) >= from
        }, by: \.project)

        return byProject.map { project, list in
            var tokens = TokenCounts(), prompts = 0
            for s in list {
                for t in s.turns where t.start >= from || t.end >= from {
                    tokens.add(t.tokens)
                    if !t.isContinuation { prompts += 1 }
                }
            }
            let latest = list.max { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }
            return ProjectReport(project: project, cwd: latest?.cwd ?? list.compactMap(\.cwd).first,
                                 tokens: tokens, sessions: list.count, prompts: prompts,
                                 lastActivity: latest?.lastActivity, active: list.contains { $0.state != .idle },
                                 issues: issues(list, from: from, now: now), latestSession: latest?.id)
        }
        .filter { !$0.tokens.isEmpty }
        .sorted { $0.tokens.value(mode) > $1.tokens.value(mode) }
    }

    /// Sessiya maslahatlari tur bo'yicha jamlanadi
    static func issues(_ sessions: [SessionSnap], from: Date, now: Date) -> [ProjectIssue] {
        var acc: [SavingsTip.Kind: (level: SavingsTip.Level, sessions: Int, waste: Int, detail: String, worst: Int)] = [:]
        // Kesh qayta yozilishi — kesh yozish narxida, qolganlari — qayta o'qish (kesh o'qish) narxida
        for s in sessions {
            for tip in SavingsAdvisor.tips(for: s, now: now) {
                let w = waste(tip, session: s, from: from)
                var a = acc[tip.kind] ?? (tip.level, 0, 0, tip.detail, -1)
                a.level = max(a.level, tip.level)
                a.sessions += 1
                a.waste += w
                if w > a.worst { a.worst = w; a.detail = tip.detail }
                acc[tip.kind] = a
            }
        }
        return acc.map { k, v in
            let price = k == .cacheRebuilds ? Pricing.cacheWrite5m : Pricing.cacheRead
            return ProjectIssue(kind: k, level: v.level, sessions: v.sessions, waste: v.waste,
                                weighted: Double(v.waste) * price, detail: v.detail)
        }
            .sorted { ($0.waste, $0.level) > ($1.waste, $1.level) }
    }

    /// Isrof — faqat oldini olsa bo'ladigan qism. Katta kontekstda: davr ichidagi har chaqiruvda 150K dan ortiq
    /// qayta o'qilgan kontekst (o'z vaqtida yangi sessiya yoki /compact qilinsa bo'lmasdi); og'ir boshlanishda —
    /// 80K dan ortiq boshlang'ich qism har chaqiruvda. Qolganlarida — maslahatning o'z bahosi.
    static func waste(_ tip: SavingsTip, session s: SessionSnap, from: Date) -> Int {
        let usage = (s.main?.usage ?? []).filter { $0.date >= from }
        let start = SavingsAdvisor.startContext(for: s) ?? SavingsAdvisor.baseline
        switch tip.kind {
        case .bigContext:
            // Boshlang'ich qism «og'ir boshlanish»da sanaladi — bu yerda faqat undan va 150K dan yuqorisi
            return usage.reduce(0) { $0 + max(0, $1.context - max(SavingsAdvisor.bigContext, start)) }
        case .heavyStart:
            return max(0, start - SavingsAdvisor.heavyStart) * usage.count
        default:
            return tip.tokens
        }
    }

    /// Claude Code uchun tayyor topshiriq: shu loyihada qo'yilsa, Claude isrof sabablarini ko'rib, tuzatishlarni taklif qiladi
    /// va har birini tasdiqlagandan keyin qo'llaydi
    public static func prompt(for r: ProjectReport, period: SavingsPeriod) -> String {
        var l: [String] = []
        l.append(tr("Token Kuzatuv hisoboti — «\(r.project)» loyihasi (\(period.title.lowercased())):",
                    "Token Kuzatuv report — project «\(r.project)» (\(period.title.lowercased())):"))
        l.append(tr("- Sarf: \(Fmt.tokens(r.tokens.total)) token, \(r.sessions) sessiya, \(r.prompts) so'rov",
                    "- Usage: \(Fmt.tokens(r.tokens.total)) tokens, \(r.sessions) sessions, \(r.prompts) prompts"))
        if r.waste > 0 {
            let pct = Fmt.percent(r.waste(.weighted), of: r.tokens.weighted)
            l.append(tr("- Taxminiy isrof: ~\(Fmt.tokens(r.waste)) token (asosan kesh o'qish; narx bo'yicha sarfning ~\(pct))",
                        "- Estimated waste: ~\(Fmt.tokens(r.waste)) tokens (mostly cache reads; ~\(pct) of usage by price)"))
        }
        l.append("")
        l.append(tr("Sabablar:", "Causes:"))
        for i in r.issues {
            let amount = i.waste > 0 ? "~\(Fmt.tokens(i.waste)), " : ""
            l.append("- \(i.title) — \(amount)\(tr("\(i.sessions) sessiyada", "in \(i.sessions) \(i.sessions == 1 ? "session" : "sessions")")). \(i.detail)")
        }
        l.append("")
        l.append(tr("Vazifa: shu loyihada token sarfini kamaytir, ish sifati va model o'zgarmasin.",
                    "Task: reduce token usage in this project without changing the model or the quality of work."))
        l.append(tr("1. Avval CLAUDE.md, .claude/settings.json, .mcp.json va ~/.claude/settings.json ni o'qib, hozirgi holatni ko'r.",
                    "1. First read CLAUDE.md, .claude/settings.json, .mcp.json and ~/.claude/settings.json to see the current setup."))
        l.append(tr("2. Har sabab uchun aniq o'zgarish taklif qil:", "2. Propose a concrete change for each cause:"))
        let kinds = Set(r.issues.map(\.kind))
        if !kinds.isDisjoint(with: [.repeatedReads, .bigResults, .screenshots]) {
            l.append(tr("   - CLAUDE.md'ga qisqa «Token tejash» bo'limi: o'zgarmagan faylni qayta o'qimaslik, faqat kerakli qatorlarni o'qish, "
                        + "uzun buyruq chiqishini qisqartirish (head/tail/grep), keng qidiruvni yordamchi agentga berish, skrinshotni kichik olish.",
                        "   - A short «Saving tokens» section in CLAUDE.md: don't re-read unchanged files, read only the needed lines, "
                        + "trim long command output (head/tail/grep), hand broad searches to a subagent, take small screenshots."))
        }
        if kinds.contains(.heavyStart) {
            l.append(tr("   - Bu loyihada ishlatilmaydigan MCP serverlar/pluginlar: loyiha .mcp.json serverlari uchun — .claude/settings.json'dagi "
                        + "disabledMcpjsonServers; foydalanuvchi darajasidagilarni — qaysilarini /mcp orqali o'chirishni ayt (o'zing o'chirma).",
                        "   - MCP servers/plugins this project doesn't use: for project .mcp.json servers — disabledMcpjsonServers in "
                        + ".claude/settings.json; for user-level ones — tell me which to turn off via /mcp (don't turn them off yourself)."))
        }
        if kinds.contains(.bigContext) || kinds.contains(.cacheRebuilds) {
            l.append(tr("   - Katta kontekst va kesh: menga odat bo'yicha qisqa tavsiya ber (yangi mavzu — yangi sessiya, shu mavzu — /compact).",
                        "   - Large context and cache: give me a short habit tip (new topic — new session, same topic — /compact)."))
        }
        l.append(tr("3. Har bir faylni o'zgartirishdan oldin nima o'zgarishini ko'rsat va mening tasdig'imni kut. Kod va loyiha mantiqiga tegma.",
                    "3. Before changing any file, show what will change and wait for my approval. Don't touch code or project logic."))
        return l.joined(separator: "\n")
    }
}
