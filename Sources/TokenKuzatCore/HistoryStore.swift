import Foundation

/// Kunlik jami tokenlar diskda saqlanadi — eski transcript'lar o'chsa ham tarix qoladi.
/// Fayl: ~/Library/Application Support/TokenKuzat/history.json  («yyyy-MM-dd» → TokenCounts)
public final class HistoryStore {
    public let url: URL
    public private(set) var days: [String: TokenCounts] = [:]
    /// Shuncha kundan eski yozuvlar o'chiriladi
    public var keepDays = 400

    public static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("TokenKuzat/history.json")
    }

    public init(url: URL) {
        self.url = url
        if let d = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([String: TokenCounts].self, from: d) {
            days = decoded
        }
    }

    /// Transcript'dan hisoblangan kunlarni saqlanganlari bilan birlashtiradi.
    /// Kun bo'yicha kattasi olinadi: transcript qisman o'qilgan (eski fayl o'chgan) bo'lsa, saqlangani yo'qolmaydi.
    public func merged(with scanned: [String: TokenCounts]) -> [String: TokenCounts] {
        var out = days
        for (k, v) in scanned where v.total >= (out[k]?.total ?? 0) {
            out[k] = v
        }
        return out
    }

    /// Birlashtirib diskka yozadi. O'zgarish bo'lmasa — hech narsa qilmaydi.
    @discardableResult
    public func save(scanned: [String: TokenCounts], now: Date = Date(), calendar: Calendar = .current) -> Bool {
        var next = merged(with: scanned)
        if let cutoff = calendar.date(byAdding: .day, value: -keepDays, to: now) {
            let minKey = Self.key(cutoff, calendar: calendar)
            next = next.filter { $0.key >= minKey }
        }
        guard next != days else { return false }
        days = next
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.sortedKeys, .prettyPrinted]
            try enc.encode(next).write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    public func clear() {
        days = [:]
        try? FileManager.default.removeItem(at: url)
    }

    public static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        let p = key.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
    }
}
