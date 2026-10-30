import Foundation

/// Ko'chirishning haqiqiy foydasi — sessiya yozuvlaridagi tokenlardan o'lchanadi, taxmin emas.
/// Har ko'chirilgan sessiya o'zi davom ettirgan eski sessiya bilan solishtiriladi: eski sessiya oxirida har javob
/// qancha kontekst o'qirdi va yangi sessiya qancha o'qiyapti. Eski sessiyada qolinsa, kontekst kamida o'sha
/// darajada qolardi (aslida o'sardi) — shuning uchun hisob ehtiyotkor
public enum HandoffSavings {
    /// Eski sessiya oxiridagi kontekst shuncha javobning medianasi
    static let tailCalls = 5

    public struct Pair: Sendable {
        public let newID: String
        public let oldID: String
        public let start: Date
        /// Eski sessiya oxirida har javob o'qigan kontekst
        public let before: Int
        /// Yangi sessiyaning birinchi javobidagi kontekst
        public let after: Int
        /// Yangi sessiyadagi javoblar
        public let calls: Int
        /// Kamroq o'qilgan token: har javobda (before − after)
        public let savedTokens: Int
        /// Narx bo'yicha: kamroq keshdan o'qish, minus yangi sessiya kontekstini bir marta keshga yozish
        public let savedWeighted: Double
        /// Yangi sessiyada o'qilgan jami kontekst
        public let readTokens: Int
        /// Yangi sessiya eski sessiya yozuvini qayta o'qigan — xulosada nimadir yetishmagan
        public let reread: Bool
    }

    public struct Summary: Sendable {
        public var handoffs = 0
        public var calls = 0
        public var savedTokens = 0
        public var savedWeighted = 0.0
        public var readTokens = 0
        public var rereads = 0
        public var medianBefore = 0
        public var medianAfter = 0
        /// Ko'chirilmaganda o'qilardi — shundan necha foiz tejaldi
        public var fraction: Double { savedTokens + readTokens > 0 ? Double(savedTokens) / Double(savedTokens + readTokens) : 0 }
    }

    /// Ko'chirilgan sessiyalar va ular davom ettirgan eski sessiyalar — ikkalasi ham ro'yxatda bo'lsa
    public static func pairs(_ sessions: [SessionSnap]) -> [Pair] {
        let byID = Dictionary(sessions.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return sessions.compactMap { s in
            guard let first = s.turns.first, AutoHandoffRule.isHandoffPrompt(first.prompt) else { return nil }
            // Ro'yxatdagi birinchi yozuv — bevosita oldingi sessiya
            let carried = SavingsAdvisor.carriedTranscripts(first.text)
            guard let oldID = carried.first.map({ ($0 as NSString).lastPathComponent.replacingOccurrences(of: ".jsonl", with: "") }),
                  oldID != s.id, let old = byID[oldID] else { return nil }
            return pair(new: s, old: old, start: first.start)
        }
    }

    static func pair(new s: SessionSnap, old: SessionSnap, start: Date) -> Pair? {
        let tail = (old.main?.usage ?? []).filter { $0.date < start }.suffix(tailCalls).map(\.context).sorted()
        let calls = s.main?.usage ?? []
        guard tail.count == tailCalls, let firstCall = calls.first else { return nil }
        let before = tail[tail.count / 2]
        // Uzun sessiyada `usage` boshidan kesiladi — birinchi chaqiruv konteksti alohida saqlanadi
        let after = s.main?.startContext ?? firstCall.context
        let trimmed = after != firstCall.context
        let saved = max(0, before - after) * calls.count
        // Kesilgan bo'lsa, birinchi kesh yozuvi noma'lum — butun boshlang'ich kontekst yozilgan deb olinadi (ehtiyotkor)
        let rewrite = Double(trimmed ? after : firstCall.tokens.cacheWrite) * (Pricing.cacheWrite5m - Pricing.cacheRead)
        let reread = s.agents.contains { a in a.steps.contains { ($0.input ?? "").contains(old.id) || $0.targetKey.contains(old.id) } }
        return Pair(newID: s.id, oldID: old.id, start: start, before: before, after: after, calls: calls.count,
                    savedTokens: saved, savedWeighted: Double(saved) * Pricing.cacheRead - rewrite,
                    readTokens: calls.reduce(0) { $0 + $1.context }, reread: reread)
    }

    public static func summary(_ pairs: [Pair], since: Date? = nil) -> Summary {
        let p = pairs.filter { since == nil || $0.start >= since! }
        var out = Summary()
        out.handoffs = p.count
        out.calls = p.reduce(0) { $0 + $1.calls }
        out.savedTokens = p.reduce(0) { $0 + $1.savedTokens }
        out.savedWeighted = p.reduce(0) { $0 + $1.savedWeighted }
        out.readTokens = p.reduce(0) { $0 + $1.readTokens }
        out.rereads = p.filter(\.reread).count
        let b = p.map(\.before).sorted(), a = p.map(\.after).sorted()
        out.medianBefore = b.isEmpty ? 0 : b[b.count / 2]
        out.medianAfter = a.isEmpty ? 0 : a[a.count / 2]
        return out
    }
}
