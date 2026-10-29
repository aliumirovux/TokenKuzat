import Foundation

/// Kesh taymeri: sessiyaning prompt keshi qachon soviydi. Kesh har chaqiruvda yangilanadi va oxirgi chaqiruvdan
/// 5 daqiqa (yoki 1 soat) keyin o'chadi; shundan keyingi so'rov butun kontekstni qaytadan, qimmat narxda yozadi.
public struct CacheClock: Sendable, Equatable {
    /// Kesh shu paytda soviydi
    public let expiresAt: Date
    public let ttl: TimeInterval
    /// Sovigach qayta yoziladigan kontekst
    public let tokens: Int

    /// Bundan kichik kontekstda qayta yozish arzon — taymer ko'rsatilmaydi
    public static let minContext = 50_000

    /// Sessiyaning asosiy agenti bo'yicha. Chaqiruv bo'lmasa yoki kontekst kichik bo'lsa — nil
    public static func of(_ s: SessionSnap) -> CacheClock? {
        guard s.contextTokens >= minContext, let last = s.main?.usage.last?.date else { return nil }
        let ttl = SavingsAdvisor.cacheTTL(for: s)
        return CacheClock(expiresAt: last.addingTimeInterval(ttl), ttl: ttl, tokens: s.contextTokens)
    }

    public func remaining(at now: Date) -> TimeInterval { max(0, expiresAt.timeIntervalSince(now)) }
    public func isWarm(at now: Date) -> Bool { now < expiresAt }

    /// Ogohlantirish sovishdan shuncha oldin: 5 daqiqalikda — 1 daqiqa, 1 soatlikda — 5 daqiqa
    public var warnBefore: TimeInterval { ttl >= SavingsAdvisor.longCacheTTL ? 5 * 60 : 60 }
    public func isEnding(at now: Date) -> Bool { isWarm(at: now) && remaining(at: now) <= warnBefore }

    /// Sovigan keshdan keyingi so'rov iliq keshdagidan necha barobar qimmat (kontekst qismi)
    public var coldMultiplier: Int {
        let write = ttl >= SavingsAdvisor.longCacheTTL ? Pricing.cacheWrite1h : Pricing.cacheWrite5m
        return Int((write / Pricing.cacheRead).rounded())
    }

    /// «4:05» yoki «52 daq»
    public static func countdown(_ t: TimeInterval) -> String {
        let s = Int(t.rounded(.up))
        if s >= 600 { return tr("\((s + 59) / 60) daq", "\((s + 59) / 60) min") }
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
