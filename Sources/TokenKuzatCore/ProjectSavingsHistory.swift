import Foundation

/// Loyiha bo'yicha kunlik sarf va isrof — sessiyalar 7 kundan keyin xotiradan chiqsa ham saqlanadi.
/// «Avval / keyin»: tuzatish (Claude'ga topshirish yoki /tokenkuzat:optimize) sanasidan oldingi va keyingi kunlardagi
/// isrof ulushi solishtiriladi.
/// Fayl: ~/Library/Application Support/TokenKuzat/project-savings.json
public struct ProjectDay: Codable, Equatable, Sendable {
    public var tokens: Int
    public var weighted: Double
    public var waste: Int
    public var wasteWeighted: Double

    public init(tokens: Int, weighted: Double, waste: Int, wasteWeighted: Double) {
        self.tokens = tokens
        self.weighted = weighted
        self.waste = waste
        self.wasteWeighted = wasteWeighted
    }

    public init(_ r: ProjectReport) {
        self.init(tokens: r.tokens.total, weighted: r.tokens.weighted, waste: r.waste, wasteWeighted: r.waste(.weighted))
    }

    /// Isrof ulushi (0…1) tanlangan hisoblash usulida
    public func wasteShare(_ mode: CountMode) -> Double {
        let t = mode == .weighted ? weighted : Double(tokens)
        let w = mode == .weighted ? wasteWeighted : Double(waste)
        return t > 0 ? min(1, w / t) : 0
    }
}

/// Bir kunda tanaffusdan keyin kesh sovib, qaytadan yozilgan kontekst — barcha loyihalar bo'yicha
public struct CacheDay: Codable, Equatable, Sendable {
    public var tokens: Int
    public var count: Int
    /// Ortiqcha narx vaznli tokenda (yozish − o'qish)
    public var weighted: Double

    public init(tokens: Int = 0, count: Int = 0, weighted: Double = 0) {
        self.tokens = tokens
        self.count = count
        self.weighted = weighted
    }

    public static func + (a: CacheDay, b: CacheDay) -> CacheDay {
        CacheDay(tokens: a.tokens + b.tokens, count: a.count + b.count, weighted: a.weighted + b.weighted)
    }
}

public struct ProjectSavingsData: Codable, Equatable, Sendable {
    /// «yyyy-MM-dd» → loyiha → kun yakuni
    public var days: [String: [String: ProjectDay]] = [:]
    /// Loyiha → oxirgi tuzatish vaqti
    public var fixes: [String: Date] = [:]
    /// «yyyy-MM-dd» → kesh sovishi. Optional — 6.46.0 dan oldingi faylda yo'q
    public var cacheDays: [String: CacheDay]?

    public init() {}

    /// `weeksBack` hafta oldingi 7 kunlik kesh sovishi (0 — bugun bilan tugaydigan 7 kun). Bironta kun yozilmagan bo'lsa — nil
    public func cacheWeek(weeksBack: Int = 0, now: Date, calendar: Calendar = .current) -> CacheDay? {
        let today = calendar.startOfDay(for: now)
        var sum = CacheDay(), found = false
        for back in (weeksBack * 7)..<(weeksBack * 7 + 7) {
            guard let d = calendar.date(byAdding: .day, value: -back, to: today),
                  let c = cacheDays?[HistoryStore.key(d, calendar: calendar)] else { continue }
            sum = sum + c
            found = true
        }
        return found ? sum : nil
    }

    /// Oxirgi `count` kun (eskidan yangiga), bugun — oxirgisi; yozuv bo'lmagan kun — nil
    public func series(_ project: String, count: Int, now: Date, calendar: Calendar = .current) -> [ProjectDay?] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().map { back in
            let d = calendar.date(byAdding: .day, value: -back, to: today) ?? today
            return days[HistoryStore.key(d, calendar: calendar)]?[project]
        }
    }

    public struct BeforeAfter: Equatable, Sendable {
        public let fixedAt: Date
        /// Tuzatishdan oldingi 7 kundagi isrof ulushi
        public let before: Double?
        /// Tuzatishdan keyingi kunlardagi (tuzatish kuni hisobga olinmaydi) — hali kun o'tmagan bo'lsa nil
        public let after: Double?
    }

    /// Tuzatish bo'lgan bo'lsa — oldin va keyingi isrof ulushi (kunlar sarfi bo'yicha tortilgan)
    public func beforeAfter(_ project: String, mode: CountMode, calendar: Calendar = .current) -> BeforeAfter? {
        guard let fixed = fixes[project] else { return nil }
        let fixDay = calendar.startOfDay(for: fixed)
        let from = calendar.date(byAdding: .day, value: -7, to: fixDay) ?? fixDay
        var before: [ProjectDay] = [], after: [ProjectDay] = []
        for (key, projects) in days {
            guard let d = HistoryStore.date(fromKey: key, calendar: calendar), let p = projects[project] else { continue }
            if d >= from && d < fixDay { before.append(p) } else if d > fixDay { after.append(p) }
        }
        func share(_ list: [ProjectDay]) -> Double? {
            guard !list.isEmpty else { return nil }
            let t = list.reduce(0.0) { $0 + (mode == .weighted ? $1.weighted : Double($1.tokens)) }
            let w = list.reduce(0.0) { $0 + (mode == .weighted ? $1.wasteWeighted : Double($1.waste)) }
            return t > 0 ? min(1, w / t) : nil
        }
        return BeforeAfter(fixedAt: fixed, before: share(before), after: share(after))
    }
}

public final class ProjectSavingsHistory {
    public let url: URL
    public var keepDays = 120

    public static var defaultURL: URL {
        HistoryStore.defaultURL.deletingLastPathComponent().appendingPathComponent("project-savings.json")
    }

    public init(url: URL = ProjectSavingsHistory.defaultURL) {
        self.url = url
    }

    /// Diskdan har safar yangidan o'qiladi: ilova va MCP (alohida jarayon) bir faylga yozadi
    public func load() -> ProjectSavingsData {
        guard let d = try? Data(contentsOf: url) else { return ProjectSavingsData() }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return (try? dec.decode(ProjectSavingsData.self, from: d)) ?? ProjectSavingsData()
    }

    /// Bugungi loyiha yakunlarini yozadi (kun davomida yangilanib boradi). O'zgarmasa — yozmaydi
    @discardableResult
    /// `cache` — so'nggi kunlarning kesh sovishi (`ProjectSavings.cacheDays`). Eski kunning sessiyalari xotiradan chiqqan
    /// bo'lishi mumkin, shuning uchun saqlangan qiymat kamaytirilmaydi
    public func record(_ reports: [ProjectReport], cache: [String: CacheDay] = [:], now: Date = Date(),
                       calendar: Calendar = .current) -> ProjectSavingsData {
        var data = load()
        let before = data
        let key = HistoryStore.key(now, calendar: calendar)
        var today = data.days[key] ?? [:]
        for r in reports { today[r.project] = ProjectDay(r) }
        data.days[key] = today
        var cacheDays = data.cacheDays ?? [:]
        for (k, c) in cache where c.tokens >= (cacheDays[k]?.tokens ?? 0) { cacheDays[k] = c }
        if !cacheDays.isEmpty { data.cacheDays = cacheDays }
        guard data != before else { return data }
        if let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) {
            let minKey = HistoryStore.key(cutoff, calendar: calendar)
            data.days = data.days.filter { $0.key >= minKey }
            data.cacheDays = data.cacheDays?.filter { $0.key >= minKey }
        }
        write(data)
        return data
    }

    /// Loyiha uchun tuzatish qilingani (Claude'ga topshirildi yoki /tokenkuzat:optimize o'zgarishlarni qo'lladi)
    @discardableResult
    public func markFixed(_ project: String, at date: Date = Date()) -> ProjectSavingsData {
        var data = load()
        data.fixes[project] = date
        write(data)
        return data
    }

    public func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    private func write(_ data: ProjectSavingsData) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? enc.encode(data).write(to: url, options: .atomic)
    }
}
