import Foundation

// Claude limitining Mac'dan tashqariga ketgan qismi: claude.ai va desktop chatlar, bulutdagi sessiyalar, telefon.
// Ular Mac diskiga yozilmaydi, lekin hisobdan olinadigan haqiqiy 5 soatlik foiz hammasini o'z ichiga oladi.
//
// Usul: har yangi limit o'lchovida foiz qancha oshgani (Δ%) va shu oraliqda Mac'da qancha vaznli token
// ketgani (L) yoziladi. Foiz butun sonlarda kelishi mumkin, shuning uchun foiz o'zgarmagan oraliqlardagi
// Mac sarfi keyingi o'sishgacha yig'ilib boradi.
// - L = 0, Δ > 0 → o'sishning hammasi tashqarida.
// - L > 0 → Mac ulushi L / k, qolgani tashqarida. k — «1% = k vaznli token», juftlarning L/Δ nisbatidan
//   o'rganiladi. Chat bir vaqtda ishlasa, Δ katta bo'ladi va nisbat kichrayadi; shuning uchun o'rta qiymat
//   emas, yuqori chorak (75-persentil) olinadi — u faqat Mac ishlagan oraliqlarga yaqin.
// - k hali o'rganilmagan bo'lsa (3 juftdan kam) — bu qism «aniqlanmagan».

/// Joriy 5 soatlik oyna va bugungi kun bo'yicha: limit qayerga ketgan
public struct OutsideUsage: Equatable, Sendable {
    /// Joriy oyna (tugagan bo'lsa — nil)
    public var windowResetsAt: Date?
    /// Oyna bo'yicha foizlar (limitning foizida). Yig'indisi ≈ joriy foiz.
    public var macPct: Double = 0
    public var outsidePct: Double = 0
    /// Koeffitsiyent hali o'rganilmagan paytdagi aralash o'sish
    public var uncertainPct: Double = 0
    /// Ilova kuzatishni boshlagunga qadar ishlatilgan qism
    public var unobservedPct: Double = 0
    /// 1% limit ≈ shuncha vaznli token (o'rganilgan bo'lsa)
    public var tokensPerPct: Double?
    /// Bugun Mac'dan tashqarida: limit foizida (barcha oynalar yig'indisi) va taxminiy vaznli tokenda
    public var outsideTodayPct: Double = 0
    public var outsideTodayTokens: Double?
    /// Oxirgi limit o'lchovi
    public var updatedAt: Date?

    /// So'nggi 6 soatdagi tashqi sarf vaqt bo'yicha («Jonli» sahifa uchun), eskidan yangiga
    public var segments: [Segment] = []

    public struct Segment: Equatable, Sendable {
        public let start: Date
        public let end: Date
        /// Limitning foizida (Mac ulushi ayirilgan)
        public let percent: Double

        public init(start: Date, end: Date, percent: Double) {
            self.start = start
            self.end = end
            self.percent = percent
        }
    }

    public init() {}

    /// Oxirgi `window` ichida tashqarida ketgan % (bo'lak qisman tushsa — ulushiga qarab)
    public func percent(within window: TimeInterval, now: Date) -> Double {
        let from = now.addingTimeInterval(-window)
        return segments.reduce(0) { acc, s in
            let a = max(s.start, from), b = min(s.end, now)
            guard b > a else { return acc }
            return acc + s.percent * b.timeIntervalSince(a) / max(1, s.end.timeIntervalSince(s.start))
        }
    }

    /// Hozir tashqarida ish ketyapti: oxirgi o'sish yaqinda (foiz butun sonlarda o'sadi — bir necha daqiqa kechikadi)
    public func isActive(now: Date) -> Bool {
        lastActivity.map { now.timeIntervalSince($0) <= 15 * 60 } ?? false
    }

    public var lastActivity: Date? { segments.last?.end }

    public var calibrated: Bool { tokensPerPct != nil }
    /// Oynada kuzatilgan qism
    public var observedPct: Double { macPct + outsidePct + uncertainPct }
    public var hasWindow: Bool { windowResetsAt != nil }
}

public final class OutsideUsageTracker {
    struct Pair: Codable, Equatable {
        /// O'sish qayd etilgan vaqt
        var t: Double
        /// Qaysi oyna (resets_at)
        var w: Double
        /// Oraliqdagi Mac vaznli tokenlari
        var local: Double
        /// Foiz o'sishi
        var d: Double
        /// O'sish to'plana boshlagan vaqt (oldingi qayd) — eski yozuvlarda yo'q
        var s: Double? = nil
    }

    struct State: Codable, Equatable {
        var windowResetsAt: Double?
        var baseline: Double = 0
        var lastT: Double?
        var lastPct: Double?
        var pendingLocal: Double = 0
        /// `pendingLocal` qachondan beri yig'ilyapti
        var pendingSince: Double?
        var pairs: [Pair] = []
    }

    public static let windowLength: TimeInterval = 5 * 3600
    /// Shundan katta tanaffusdan keyin (Mac uxlagan, ilova yopiq) yangi oynaning boshlang'ich foizi «kuzatilmagan»
    static let maxGap: TimeInterval = 15 * 60
    /// Koeffitsiyent shuncha juftdan o'rganiladi
    static let minPairs = 3
    static let keepPairs: TimeInterval = 7 * 86400

    public let url: URL?
    private(set) var state = State()

    public static var defaultURL: URL {
        HistoryStore.defaultURL.deletingLastPathComponent().appendingPathComponent("outside-usage.json")
    }

    /// `url` = nil — faqat xotirada (testlar uchun)
    public init(url: URL? = OutsideUsageTracker.defaultURL) {
        self.url = url
        if let url, let d = try? Data(contentsOf: url), let s = try? JSONDecoder().decode(State.self, from: d) {
            state = s
        }
    }

    /// Yangi limit o'lchovi. `minutes` — Mac sarfi daqiqama-daqiqa (oxirgi 6 soat yetadi).
    /// O'lchov vaqti oldingisidan keyin bo'lmasa — e'tiborsiz. Holat o'zgargan bo'lsa true.
    @discardableResult
    public func observe(_ window: LimitWindow, at t: Date, minutes: [MinutePoint]) -> Bool {
        let tt = t.timeIntervalSince1970
        if let last = state.lastT, tt <= last { return false }
        let pct = window.usedPercentage
        let w = window.resetsAt.timeIntervalSince1970
        let newWindow = (state.windowResetsAt.map { abs($0 - w) > 600 } ?? true)
            || pct + 0.5 < (state.lastPct ?? 0)

        if newWindow {
            let start = window.resetsAt.addingTimeInterval(-Self.windowLength)
            let prev = state.lastT.map { Date(timeIntervalSince1970: $0) }
            state.windowResetsAt = w
            state.pendingLocal = 0
            state.pendingSince = tt
            if let prev, t.timeIntervalSince(prev) <= Self.maxGap, start <= t {
                state.pendingSince = max(prev, start).timeIntervalSince1970
                // Yangi oyna kuzatuv paytida boshlandi — boshlang'ich foiz ham o'lchanadi
                state.baseline = 0
                state.lastPct = 0
                state.pendingLocal = Self.local(minutes, from: max(prev, start), to: t)
                if pct > 0.05 { record(d: pct, at: tt) }
            } else {
                state.baseline = pct
            }
            state.lastPct = pct
            state.lastT = tt
            prune(now: tt)
            save()
            return true
        }

        if let prev = state.lastT {
            state.pendingLocal += Self.local(minutes, from: Date(timeIntervalSince1970: prev), to: t)
            if state.pendingSince == nil { state.pendingSince = prev }
        }
        state.lastT = tt
        let d = pct - (state.lastPct ?? pct)
        if d > 0.05 {
            record(d: d, at: tt)
            state.lastPct = pct
        }
        prune(now: tt)
        save()
        return true
    }

    private func record(d: Double, at tt: Double) {
        state.pairs.append(Pair(t: tt, w: state.windowResetsAt ?? 0, local: state.pendingLocal, d: d, s: state.pendingSince))
        state.pendingLocal = 0
        state.pendingSince = tt
    }

    private func prune(now: Double) {
        state.pairs.removeAll { now - $0.t > Self.keepPairs }
        if state.pairs.count > 4000 { state.pairs.removeFirst(state.pairs.count - 4000) }
    }

    /// 1% ≈ k vaznli token: Mac sarfi bo'lgan juftlarning L/Δ nisbatlari, 75-persentil
    var tokensPerPct: Double? {
        let ratios = state.pairs.filter { $0.local > 0 && $0.d > 0 }.map { $0.local / $0.d }.sorted()
        guard ratios.count >= Self.minPairs else { return nil }
        let i = min(ratios.count - 1, Int((Double(ratios.count - 1) * 0.75).rounded()))
        return ratios[i]
    }

    /// Bitta o'sish: (Mac, tashqari, aniqlanmagan)
    static func split(_ p: Pair, k: Double?) -> (mac: Double, out: Double, unc: Double) {
        if p.local <= 0 { return (0, p.d, 0) }
        guard let k, k > 0 else { return (0, 0, p.d) }
        let mac = min(p.d, p.local / k)
        return (mac, p.d - mac, 0)
    }

    public func summary(now: Date) -> OutsideUsage {
        var o = OutsideUsage()
        let k = tokensPerPct
        o.tokensPerPct = k
        o.updatedAt = state.lastT.map { Date(timeIntervalSince1970: $0) }
        if let w = state.windowResetsAt, Date(timeIntervalSince1970: w) > now {
            o.windowResetsAt = Date(timeIntervalSince1970: w)
            o.unobservedPct = state.baseline
            for p in state.pairs where p.w == w {
                let s = Self.split(p, k: k)
                o.macPct += s.mac
                o.outsidePct += s.out
                o.uncertainPct += s.unc
            }
        }
        let dayStart = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        for p in state.pairs where p.t >= dayStart {
            o.outsideTodayPct += Self.split(p, k: k).out
        }
        o.outsideTodayTokens = k.map { $0 * o.outsideTodayPct }
        // Vaqt bo'yicha: har o'sish — oldingi qaydidan shu qaydigacha (eski yozuvlarda — oldingi juftdan, ko'pi 15 daqiqa)
        let since = now.timeIntervalSince1970 - 6 * 3600
        var prevT: Double?
        for p in state.pairs {
            defer { prevT = p.t }
            guard p.t >= since else { continue }
            let out = Self.split(p, k: k).out
            guard out > 0.05 else { continue }
            let start = max(p.s ?? prevT ?? (p.t - 90), p.t - 2 * 3600)
            o.segments.append(.init(start: Date(timeIntervalSince1970: min(start, p.t - 60)),
                                    end: Date(timeIntervalSince1970: p.t), percent: out))
        }
        return o
    }

    /// [from, to) oralig'idagi daqiqalar (daqiqa boshi bo'yicha) vaznli tokenlari
    static func local(_ minutes: [MinutePoint], from a: Date, to b: Date) -> Double {
        let lo = floor(a.timeIntervalSince1970 / 60) * 60
        let hi = floor(b.timeIntervalSince1970 / 60) * 60
        guard hi > lo else { return 0 }
        var sum = 0.0
        for m in minutes {
            let x = m.date.timeIntervalSince1970
            if x >= lo && x < hi { sum += m.main.weighted + m.agents.weighted }
        }
        return sum
    }

    /// Hamma o'rganilgan ma'lumotni o'chiradi (Sozlamalar → tarixni tozalash)
    public func reset() {
        state = State()
        if let url { try? FileManager.default.removeItem(at: url) }
    }

    private func save() {
        guard let url, let d = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? d.write(to: url, options: .atomic)
    }
}
