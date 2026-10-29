import Foundation

// Claude Code status line'ga har yangilanishda JSON beradi (code.claude.com/docs/en/statusline).
// Pro/Max obunachilarida unda haqiqiy limitlar bor: rate_limits.five_hour / seven_day — used_percentage (0–100)
// va resets_at (Unix soniya). Token Kuzatuv'ning `--statusline` rejimi shu JSON'ni diskka yozadi,
// bu yerda esa o'qiladi va sarf tezligidan «qachon tugaydi» bashorati chiqariladi.

public struct LimitWindow: Equatable, Sendable {
    public let usedPercentage: Double
    public let resetsAt: Date

    public init(usedPercentage: Double, resetsAt: Date) {
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }
}

public struct RateLimits: Equatable, Sendable {
    public var fiveHour: LimitWindow?
    public var sevenDay: LimitWindow?
    /// Ma'lumot oxirgi marta qachon kelgan (fayl vaqti)
    public var updatedAt: Date
    /// Sessiya bo'yicha taxminiy narx ($), Claude Code hisoblagani
    public var costBySession: [String: Double] = [:]
    /// Tarif: «Max (5x)», «Pro» — hisobdan olinganda
    public var plan: String?
    /// Ma'lumot qayerdan: hisob (claude.ai bilan bir xil) yoki status line
    public var fromAccount = false

    public init(fiveHour: LimitWindow? = nil, sevenDay: LimitWindow? = nil, updatedAt: Date, costBySession: [String: Double] = [:]) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.updatedAt = updatedAt
        self.costBySession = costBySession
    }

    /// Tiklanish vaqti o'tgan oyna endi amal qilmaydi
    public func active(at now: Date) -> RateLimits {
        var r = self
        if let w = r.fiveHour, w.resetsAt <= now { r.fiveHour = nil }
        if let w = r.sevenDay, w.resetsAt <= now { r.sevenDay = nil }
        return r
    }

    public var isEmpty: Bool { fiveHour == nil && sevenDay == nil }
}

/// Status line JSON'idan kerakli maydonlarni oladi
public enum StatusLinePayload {
    public struct Parsed: Equatable {
        public var sessionId: String?
        public var costUSD: Double?
        public var fiveHour: LimitWindow?
        public var sevenDay: LimitWindow?
    }

    public static func parse(_ data: Data) -> Parsed? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func window(_ k: String) -> LimitWindow? {
            guard let rl = o["rate_limits"] as? [String: Any], let w = rl[k] as? [String: Any],
                  let pct = (w["used_percentage"] as? NSNumber)?.doubleValue,
                  let reset = (w["resets_at"] as? NSNumber)?.doubleValue else { return nil }
            return LimitWindow(usedPercentage: pct, resetsAt: Date(timeIntervalSince1970: reset))
        }
        return Parsed(sessionId: o["session_id"] as? String,
                      costUSD: ((o["cost"] as? [String: Any])?["total_cost_usd"] as? NSNumber)?.doubleValue,
                      fiveHour: window("five_hour"), sevenDay: window("seven_day"))
    }
}

/// `--statusline` rejimi yozadigan papkani o'qiydi: latest.json (oxirgi limitlar) va sessions/<id>.json (narx).
public final class RateLimitsReader {
    public let directory: URL
    private var lastMtime: Date?
    private var cached: RateLimits?
    private var history: [(Date, Double)] = []

    public static var defaultDirectory: URL {
        HistoryStore.defaultURL.deletingLastPathComponent().appendingPathComponent("statusline")
    }

    public init(directory: URL = RateLimitsReader.defaultDirectory) {
        self.directory = directory
    }

    /// Fayl o'zgarmagan bo'lsa — keshdan (har soniyada chaqirsa bo'ladi)
    public func read() -> RateLimits? {
        let latest = directory.appendingPathComponent("latest.json")
        guard let mtime = (try? latest.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
            cached = nil
            return nil
        }
        if mtime == lastMtime { return cached }
        lastMtime = mtime
        guard let d = try? Data(contentsOf: latest), let p = StatusLinePayload.parse(d) else { return cached }

        var costs: [String: Double] = [:]
        let sessionsDir = directory.appendingPathComponent("sessions")
        for url in (try? FileManager.default.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil)) ?? [] {
            guard url.pathExtension == "json", let sd = try? Data(contentsOf: url),
                  let sp = StatusLinePayload.parse(sd), let id = sp.sessionId, let c = sp.costUSD else { continue }
            costs[id] = c
        }
        var r = RateLimits(fiveHour: p.fiveHour, sevenDay: p.sevenDay, updatedAt: mtime, costBySession: costs)
        // Limit kelmagan javob (masalan, sessiyaning birinchi qatori) oldingi qiymatni o'chirmasin
        if r.fiveHour == nil { r.fiveHour = cached?.fiveHour }
        if r.sevenDay == nil { r.sevenDay = cached?.sevenDay }
        if let w = r.fiveHour { record(w, at: mtime) }
        cached = r
        return r
    }

    /// 5 soatlik oyna foizi tarixi — bashorat uchun (oxirgi 1 soat)
    public var fiveHourHistory: [(Date, Double)] { history }

    private func record(_ w: LimitWindow, at t: Date) {
        // Oyna tiklangan bo'lsa (foiz tushib ketgan) — tarix boshidan
        if let last = history.last, w.usedPercentage + 0.5 < last.1 { history.removeAll() }
        history.append((t, w.usedPercentage))
        history.removeAll { t.timeIntervalSince($0.0) > 3600 }
    }
}

/// «Shu tezlikda limit qachon tugaydi»
public enum LimitForecast {
    public enum Outcome: Equatable, Sendable {
        /// Tiklanishdan oldin 100% ga yetadi
        case runsOut(at: Date)
        /// Tiklanguncha yetadi
        case lasts
        /// Bashorat uchun ma'lumot yetarli emas
        case unknown
    }

    /// `history` — (vaqt, foiz) juftlari. Oxirgi `window` soniyadagi o'rtacha tezlik olinadi.
    /// Tiklanishdan `margin` dan kamroq oldin tugashi ogohlantirishga arzimaydi — `.lasts`.
    public static func forecast(_ w: LimitWindow, history: [(Date, Double)], now: Date,
                                window: TimeInterval = 20 * 60, margin: TimeInterval = 10 * 60) -> Outcome {
        let recent = history.filter { now.timeIntervalSince($0.0) <= window }
        guard let first = recent.first, let last = recent.last, last.0.timeIntervalSince(first.0) >= 120 else { return .unknown }
        let rate = (last.1 - first.1) / last.0.timeIntervalSince(first.0)   // foiz / soniya
        guard rate > 0 else { return .lasts }
        let eta = now.addingTimeInterval((100 - w.usedPercentage) / rate)
        return eta < w.resetsAt.addingTimeInterval(-margin) ? .runsOut(at: eta) : .lasts
    }
}

// MARK: - Hisob (claude.ai «Usage» sahifasi bilan bir xil manba)

/// Claude Code kirish kaliti bilan Anthropic'dan olinadigan foydalanish ma'lumoti:
/// `{"five_hour": {"utilization": 44.0, "resets_at": "…"}, "seven_day": {…}}`
public enum AccountUsageAPI {
    public static let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    private static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static func date(_ v: Any?) -> Date? {
        if let n = v as? NSNumber { return Date(timeIntervalSince1970: n.doubleValue) }
        guard let s = v as? String else { return nil }
        return isoFrac.date(from: s) ?? isoPlain.date(from: s)
    }

    public static func parse(_ data: Data, at now: Date) -> RateLimits? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        func window(_ k: String) -> LimitWindow? {
            guard let w = o[k] as? [String: Any],
                  let u = (w["utilization"] as? NSNumber)?.doubleValue,
                  let r = date(w["resets_at"]) else { return nil }
            return LimitWindow(usedPercentage: u, resetsAt: r)
        }
        let r = RateLimits(fiveHour: window("five_hour"), sevenDay: window("seven_day"), updatedAt: now)
        guard !r.isEmpty else { return nil }
        var out = r
        out.fromAccount = true
        return out
    }

    /// «default_claude_max_5x» → «Max (5x)», «pro» → «Pro»
    public static func planName(subscriptionType: String?, rateLimitTier: String?) -> String? {
        let tier = (rateLimitTier ?? "").lowercased()
        if let r = tier.range(of: #"max_(\d+)x"#, options: .regularExpression) {
            let x = tier[r].replacingOccurrences(of: "max_", with: "").replacingOccurrences(of: "x", with: "")
            return "Max (\(x)x)"
        }
        guard let t = subscriptionType?.lowercased(), !t.isEmpty else { return nil }
        switch t {
        case "max": return "Max"
        case "pro": return "Pro"
        case "team": return "Team"
        case "enterprise": return "Enterprise"
        default: return t.capitalized
        }
    }
}

/// Haftalik bashorat: oyna boshidan hozirgacha o'rtacha sur'at bilan — tiklanishdan oldin tugaydimi
public enum WeeklyForecast {
    public static let window: TimeInterval = 7 * 24 * 3600

    public static func forecast(_ w: LimitWindow, now: Date) -> LimitForecast.Outcome {
        let start = w.resetsAt.addingTimeInterval(-window)
        let elapsed = now.timeIntervalSince(start)
        // Oynaning boshida (12 soatdan kam) sur'at ishonchsiz
        guard elapsed > 12 * 3600, w.usedPercentage > 1 else { return .unknown }
        let rate = w.usedPercentage / elapsed
        let eta = now.addingTimeInterval((100 - w.usedPercentage) / rate)
        return eta < w.resetsAt ? .runsOut(at: eta) : .lasts
    }
}
