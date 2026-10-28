import Foundation

/// Raqam va vaqtni o'zbekcha ko'rinishda yozish.
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
        return s.replacingOccurrences(of: ".", with: ",")
    }

    public static func tokens(_ v: Int) -> String { tokens(Double(v)) }

    /// To'liq raqam, minglar bo'sh joy bilan: 1 234 567
    public static func full(_ v: Double) -> String {
        grouped.string(from: NSNumber(value: v.rounded())) ?? "\(Int(v))"
    }

    public static func ago(_ d: Date?, now: Date = Date()) -> String {
        guard let d else { return "—" }
        let s = Int(now.timeIntervalSince(d))
        if s < 5 { return "hozir" }
        if s < 60 { return "\(s) s oldin" }
        if s < 3600 { return "\(s / 60) daq oldin" }
        if s < 86_400 { return "\(s / 3600) soat oldin" }
        return "\(s / 86_400) kun oldin"
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

    public static let clock = formatter("HH:mm:ss")
    public static let hourMinute = formatter("HH:mm")
    public static let dayTime = formatter("dd.MM HH:mm")
    /// «28-okt», «3-noy»
    public static let shortDay = formatter("d-MMM")
    /// «28-oktabr, chorshanba»
    public static let longDay = formatter("d-MMMM, EEEE")

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f
    }()

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "uz_Latn_UZ")
        f.dateFormat = format
        return f
    }
}
