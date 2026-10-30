import Foundation

/// Agent turlari: bosh agent (rahbar) ishni rejalaydi va tekshiradi, og'ir o'qishni yordamchilarga beradi.
/// Token Kuzatuv plagini `izlovchi`, `bajaruvchi`, `tekshiruvchi`, `sinovchi` agentlarini o'rnatadi; Claude Code'ning o'z turlari ham tanildi
public enum AgentRole: String, CaseIterable, Sendable {
    case lead, explorer, builder, reviewer, tester, other

    public var title: String {
        switch self {
        case .lead: return tr("Rahbar", "Lead")
        case .explorer: return tr("Izlovchi", "Explorer")
        case .builder: return tr("Bajaruvchi", "Builder")
        case .reviewer: return tr("Tekshiruvchi", "Reviewer")
        case .tester: return tr("Sinovchi", "Tester")
        case .other: return tr("Boshqa yordamchi", "Other helpers")
        }
    }

    /// Qisqa izoh: tur nima qiladi
    public var hint: String {
        switch self {
        case .lead: return tr("rejalash, tekshirish", "plans, checks")
        case .explorer: return tr("qidirish, o'qish", "searches, reads")
        case .builder: return tr("aniq kod o'zgarishi", "specified code change")
        case .reviewer: return tr("kodni mustaqil ko'rish", "independent code review")
        case .tester: return tr("ishga tushirib sinash", "runs and tests")
        case .other: return tr("Plan, general-purpose…", "Plan, general-purpose…")
        }
    }

    /// `kind` — Claude Code yozuvidagi agentType («Explore», «tokenkuzat:izlovchi» …)
    public static func of(_ a: AgentSnap) -> AgentRole {
        if a.isMain { return .lead }
        let k = a.kind.lowercased()
        let name = k.split(separator: ":").last.map(String.init) ?? k
        if name == "izlovchi" || name == "explore" || name.contains("search") { return .explorer }
        if name == "bajaruvchi" { return .builder }
        if name == "sinovchi" || name == "qa" || name.contains("test") { return .tester }
        if name == "tekshiruvchi" || name.contains("review") || name.contains("verif") { return .reviewer }
        return .other
    }

    /// Rahbar o'zi shuncha faylni o'qisa (yordamchisiz) — izlash ishini izlovchiga berish mumkin edi
    public static let heavyLeadReads = 30
}

public enum AgentRoleUsage {
    public struct Row: Sendable {
        public let role: AgentRole
        public var tokens = TokenCounts()
        public var agents = 0
        public var calls = 0
        /// Opus-ekvivalent og'irlikdagi haqiqiy sarf (Opus = 1): token og'irligi × model narxi nisbati
        public var actual = 0.0
        /// Taxminiy tejalgan token, Opus-ekvivalentda; manfiy — ortiqcha sarf. Faqat `estimates > 0` bo'lsa ma'noli
        public var saved = 0.0
        /// Tejash hisoblangan yordamchilar soni (rahbari yo'q yoki `usage`siz yordamchi hisoblanmaydi)
        public var estimates = 0
        public var hasEstimate: Bool { estimates > 0 }
        /// Shu turdagi agentlar ishlagan model darajalari (modeli noma'lum yordamchi — rahbar modelida)
        public var tiers: Set<ModelTier> = []
        /// Bitta daraja — o'sha; bir nechta — `.mixed`; noma'lum — nil
        public var tier: ModelTier? { tiers.count > 1 ? .mixed : tiers.first }
        /// 1 token (Opus-ekvivalent) sarfga qancha tejaldi; manfiy — ortiqcha sarf.
        /// Butun `actual` ga bo'linadi: tejashi hisoblanmagan yordamchi sarfi ham kiradi (ehtiyotkor baho)
        public var efficiency: Double? { hasEstimate && actual > 0 ? saved / actual : nil }
    }

    public struct Summary: Sendable {
        public var rows: [Row] = []
        /// Rahbar ko'p faylni o'zi o'qigan va yordamchi ishlatmagan sessiyalar
        public var heavyLeadSessions = 0
        public var sessions = 0
        /// Barcha yordamchilar bo'yicha taxminiy tejalgan token (Opus-ekvivalentda)
        public var totalSaved = 0.0
        /// Hamma qatorning `actual` yig'indisi
        public var totalActual = 0.0
        /// Tejash ulushi, %: tejalgan / (haqiqiy sarf + tejalgan). Maxraj ≤ 0 bo'lsa — 0
        public var savedPercent: Double {
            let denominator = totalActual + totalSaved
            return denominator > 0 ? totalSaved / denominator * 100 : 0
        }
        public var hasEstimate: Bool { rows.contains { $0.hasEstimate } }
        public var helpersUsed: Bool { rows.contains { $0.role != .lead && $0.agents > 0 } }
        /// Yordamchi agentlar soni (rahbardan tashqari hamma qator)
        public var helperAgents: Int { rows.filter { $0.role != .lead }.reduce(0) { $0 + $1.agents } }
    }

    public static func summary(_ sessions: [SessionSnap], since: Date) -> Summary {
        var rows = Dictionary(uniqueKeysWithValues: AgentRole.allCases.map { ($0, Row(role: $0)) })
        var out = Summary()
        for s in sessions where (s.lastActivity ?? .distantPast) >= since {
            out.sessions += 1
            let lead = s.main
            // Oyna sessiyada umumiy: yordamchilar tugash vaqti bo'yicha, avvalgilar kiritgan matn hisobga olinadi
            var alreadyKept = 0.0
            var estimates: [String: (actual: Double, saved: Double?)] = [:]
            for a in s.agents.filter({ !$0.isMain }).sorted(by: { ($0.lastActivity ?? .distantPast) < ($1.lastActivity ?? .distantPast) }) {
                let e = estimate(helper: a, lead: lead, alreadyKept: alreadyKept)
                alreadyKept += e.kept
                estimates[a.id] = (e.actual, e.saved)
            }
            for a in s.agents {
                let r = AgentRole.of(a)
                var row = rows[r] ?? Row(role: r)
                row.tokens = row.tokens + a.tokens
                row.agents += 1
                row.calls += a.calls
                // Modeli yozilmagan yordamchi rahbar modelida ishlaydi; Claude bo'lmagan model darajasiz
                if let t = ModelTier.of(a.model ?? (a.isMain ? nil : lead?.model)) { row.tiers.insert(t) }
                if a.isMain {
                    row.actual += a.tokens.weighted * (ModelPrice.ratio(a.model) ?? 1)
                } else {
                    let e = estimates[a.id] ?? (a.tokens.weighted, nil)
                    row.actual += e.actual
                    if let saved = e.saved {
                        row.saved += saved
                        row.estimates += 1
                    }
                }
                rows[r] = row
            }
            let reads = s.main?.reads ?? 0
            if reads >= AgentRole.heavyLeadReads, s.helperCount == 0 { out.heavyLeadSessions += 1 }
        }
        out.rows = AgentRole.allCases.compactMap { rows[$0] }.filter { $0.agents > 0 }
        out.totalSaved = out.rows.reduce(0) { $0 + $1.saved }
        out.totalActual = out.rows.reduce(0) { $0 + $1.actual }
        return out
    }

    /// Rahbar o'z kontekstining shuncha qismidan kamiga tushsa (/compact), yordamchi to'plagan matn endi kontekstda emas
    static let compactRatio = 0.6
    /// Kontekst oynasi: rahbar kontekstiga yordamchi matni shundan ortiq sig'maydi
    static let contextWindow = 200_000

    /// Yordamchining haqiqiy narxi va taxminiy tejalgani — hammasi Opus-ekvivalent og'irlikdagi tokenda (Opus = 1).
    /// Taqqoslash: rahbar shu ishni o'zi qilganda to'laydigan narx.
    /// - rahbar yordamchining o'z boshlanishini (tizim ko'rsatmasi + topshiriq) to'lamaydi;
    /// - lekin har chaqiruvda o'zining kattaroq kontekstini keshdan o'qiydi;
    /// - yordamchi to'plagan matn rahbar kontekstida qolib, keyingi javoblarda qayta o'qiladi (/compact gacha, oynadan oshmasdan,
    ///   rahbar baribir olgan qisqa xulosani ayirib).
    /// `alreadyKept` — shu sessiyada avvalgi yordamchilar uchun kontekstda qoldi deb hisoblangan matn: 200K oyna ular bilan bo'lishiladi.
    /// `kept` — shu yordamchi uchun hisoblangan matn (keyingi yordamchiga `alreadyKept` sifatida beriladi).
    /// Natija manfiy bo'lishi mumkin. Rahbari yoki `usage`si yo'q yordamchida `saved` = nil.
    public static func estimate(helper h: AgentSnap, lead l: AgentSnap?, alreadyKept: Double = 0) -> (actual: Double, saved: Double?, kept: Double) {
        let leadRatio = ModelPrice.ratio(l?.model) ?? 1
        let actual = h.tokens.weighted * (ModelPrice.ratio(h.model) ?? leadRatio)
        guard let l, let first = h.usage.first, let last = h.usage.last else { return (actual, nil, 0) }

        let start = h.firstActivity ?? first.date
        let end = h.lastActivity ?? last.date
        var leadContext: Int = l.usage.last(where: { $0.date <= start })?.context ?? 0
        // Rahbar `usage`si boshidan kesilgan bo'lsa — eng eski mavjud nuqta (pastdan baho)
        if leadContext == 0, let earliest = l.usage.first, let born = l.firstActivity, earliest.date > born, earliest.date > start {
            leadContext = earliest.context
        }
        let base = Double(h.startContext ?? first.context)
        let loaded = Double(max(0, last.context - Int(base)))

        // Yordamchi tugagach rahbarning keyingi javoblari: /compact gacha
        let contextAtEnd = l.usage.last(where: { $0.date <= end })?.context ?? leadContext
        var callsAfter = 0
        for u in l.usage where u.date > end {
            if Double(u.context) < Double(contextAtEnd) * compactRatio { break }
            callsAfter += 1
        }
        let room = max(0, Double(contextWindow - contextAtEnd) - alreadyKept)
        let kept = max(0, min(loaded - Double(last.tokens.output), room))

        let calls = Double(h.calls)
        let ownWork: Double = max(0, h.tokens.weighted - first.tokens.weighted - base * Pricing.cacheRead * max(0, calls - 1))
        let leadRereads: Double = calls * Double(leadContext) * Pricing.cacheRead
        let keptRereads: Double = kept * Double(callsAfter) * Pricing.cacheRead
        return (actual, (ownWork + leadRereads + keptRereads) * leadRatio - actual, kept)
    }
}

/// Model narxining Opus'ga nisbati. Anthropic ro'yxat narxlarining nisbati (Opus : Sonnet : Haiku = 5 : 3 : 1) — mutlaq narx emas.
/// Eski Opus 4 / 4.1 da nisbat 15 : 3 : 1 edi, shuning uchun tarixiy sessiyalar taxminiy
public enum ModelPrice {
    public static let opus = 1.0
    public static let sonnet = 0.6
    public static let haiku = 0.2

    /// Model identifikatori yoki nomidagi oila bo'yicha; tanilmasa nil
    public static func ratio(_ model: String?) -> Double? {
        let m = (model ?? "").lowercased()
        if m.contains("opus") { return opus }
        if m.contains("sonnet") { return sonnet }
        if m.contains("haiku") { return haiku }
        return nil
    }
}

/// Model darajasi: narx nisbati bo'yicha (Opus ×5 · Sonnet ×3 · Haiku ×1)
public enum ModelTier: String, Sendable, Hashable {
    case opus, sonnet, haiku, mixed

    /// Model identifikatori yoki nomidagi oila bo'yicha (`ModelPrice.ratio` bilan bir xil); tanilmasa nil
    public static func of(_ model: String?) -> ModelTier? {
        let m = (model ?? "").lowercased()
        if m.contains("opus") { return .opus }
        if m.contains("sonnet") { return .sonnet }
        if m.contains("haiku") { return .haiku }
        return nil
    }

    public var title: String {
        switch self {
        case .opus: return "Opus"
        case .sonnet: return "Sonnet"
        case .haiku: return "Haiku"
        case .mixed: return tr("Aralash", "Mixed")
        }
    }

    /// Narx Haiku'ga nisbatan (5 : 3 : 1); aralashda nil
    public var multiplier: Int? {
        switch self {
        case .opus: return 5
        case .sonnet: return 3
        case .haiku: return 1
        case .mixed: return nil
        }
    }
}
