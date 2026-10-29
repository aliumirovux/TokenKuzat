import Foundation

/// Raqam va vaqtni joriy tilda (o'zbekcha yoki inglizcha) yozish.
public enum Fmt {
    /// 1234 → «1,2K», 12_345_678 → «12M»
    public static func tokens(_ v: Double) -> String {
        let a = abs(v)
        let s: String
        if a >= 1_000_000_000 { s = String(format: "%.2fB", v / 1_000_000_000) }
        else if a >= 10_000_000 { s = String(format: "%.0fM", v / 1_000_000) }
        else if a >= 1_000_000 { s = String(format: "%.1fM", v / 1_000_000) }
        else if a >= 100_000 { s = String(format: "%.0fK", v / 1_000) }
        else if a >= 1_000 { s = String(format: "%.1fK", v / 1_000) }
        else { s = String(format: "%.0f", v) }
        return Lang.isEnglish ? s : s.replacingOccurrences(of: ".", with: ",")
    }

    public static func tokens(_ v: Int) -> String { tokens(Double(v)) }

    /// 1.234 → «$1,23» (inglizchada «$1.23»)
    public static func usd(_ v: Double) -> String {
        let s = String(format: "$%.2f", v)
        return Lang.isEnglish ? s : s.replacingOccurrences(of: ".", with: ",")
    }

    /// To'liq raqam, minglar bo'sh joy bilan: 1 234 567 (inglizchada 1,234,567)
    public static func full(_ v: Double) -> String {
        (Lang.isEnglish ? groupedEN : grouped).string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }

    public static func ago(_ d: Date?, now: Date = Date()) -> String {
        guard let d else { return "—" }
        let s = Int(now.timeIntervalSince(d))
        if s < 5 { return tr("hozir", "now") }
        if s < 60 { return tr("\(s) s oldin", "\(s)s ago") }
        if s < 3600 { return tr("\(s / 60) daq oldin", "\(s / 60) min ago") }
        if s < 86_400 { return tr("\(s / 3600) soat oldin", "\(s / 3600)h ago") }
        return tr("\(s / 86_400) kun oldin", "\(s / 86_400)d ago")
    }

    public static func percent(_ part: Double, of whole: Double) -> String {
        guard whole > 0 else { return "0%" }
        let p = part / whole * 100
        if p > 0 && p < 1 { return "<1%" }
        return String(format: "%.0f%%", p)
    }

    /// «claude-opus-5-5» → «Opus 5.5», «claude-sonnet-4-5-20250929» → «Sonnet 4.5»
    public static func model(_ m: String) -> String {
        guard !m.isEmpty else { return "" }
        let parts = m.split(separator: "-").map(String.init)
            .filter { $0 != "claude" && !($0.count == 8 && Int($0) != nil) }
        let words = parts.filter { Int($0) == nil }.map { $0.capitalized }
        let nums = parts.filter { Int($0) != nil }.joined(separator: ".")
        return (words + [nums]).filter { !$0.isEmpty }.joined(separator: " ")
    }

    public static var clock: DateFormatter { formatter("HH:mm:ss") }
    public static var hourMinute: DateFormatter { formatter("HH:mm") }
    public static var dayTime: DateFormatter { formatter("dd.MM HH:mm") }
    /// «28-okt», «3-noy» (inglizchada «Oct 28»)
    public static var shortDay: DateFormatter { formatter("d-MMM", en: "MMM d") }
    /// «28-oktabr, chorshanba» (inglizchada «Wednesday, October 28»)
    public static var longDay: DateFormatter { formatter("d-MMMM, EEEE", en: "EEEE, MMMM d") }

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f
    }()

    private static let groupedEN: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = ","
        f.maximumFractionDigits = 0
        return f
    }()

    /// Har bir til va shakl uchun bitta formatter (til almashganda yangisi olinadi)
    private static var cache: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    private static func formatter(_ format: String, en: String? = nil) -> DateFormatter {
        let format = Lang.isEnglish ? (en ?? format) : format
        let key = (Lang.isEnglish ? "en|" : "uz|") + format
        lock.lock(); defer { lock.unlock() }
        if let f = cache[key] { return f }
        let f = DateFormatter()
        f.locale = Lang.locale
        f.dateFormat = format
        cache[key] = f
        return f
    }
}
