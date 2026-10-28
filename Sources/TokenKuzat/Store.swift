import Foundation
import TokenKuzatCore

/// Limitga nisbatan joriy holat (har doim vaznli tokenda — limit narxga bog'liq).
struct BudgetStatus {
    let period: BudgetPeriod
    let used: Double
    let limit: Double

    var fraction: Double { limit > 0 ? used / limit : 0 }
    var level: Level {
        switch fraction {
        case ..<0.8: return .ok
        case ..<1: return .warning
        default: return .over
        }
    }

    enum Level { case ok, warning, over }

    static func current(_ s: Snapshot, defaults: UserDefaults = .standard) -> BudgetStatus? {
        guard defaults.bool(forKey: Pref.budgetEnabled) else { return nil }
        let period = BudgetPeriod(rawValue: defaults.string(forKey: Pref.budgetPeriod) ?? "") ?? .fiveHours
        let limit = defaults.double(forKey: Pref.budgetLimitM) * 1_000_000
        guard limit > 0 else { return nil }
        let used = period == .day ? s.today.weighted : s.lastFiveHours.weighted
        return BudgetStatus(period: period, used: used, limit: limit)
    }
}

/// Engine'ni fon navbatida har soniyada yurgizadi va UI'ga snapshot beradi.
/// Ma'lumot o'zgarmasa UI 3 soniyada bir marta yangilanadi (holat va «N s oldin» uchun) — CPU tejaladi.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var snap = Snapshot()

    private let engine: Engine
    private let limitsReader = RateLimitsReader()
    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.engine", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastRevision = -1
    private var lastPublish = Date.distantPast

    init() {
        engine = Engine(history: HistoryStore(url: HistoryStore.defaultURL))
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(250))
        t.setEventHandler { [weak self] in self?.step() }
        t.resume()
        timer = t
    }

    private func step() {
        let now = Date()
        engine.update(now: now)
        guard engine.revision != lastRevision || now.timeIntervalSince(lastPublish) >= 3 else { return }
        lastRevision = engine.revision
        lastPublish = now
        var s = engine.snapshot()
        if let l = limitsReader.read()?.active(at: now), !l.isEmpty || !l.costBySession.isEmpty {
            s.limits = l
            if let w = l.fiveHour {
                s.fiveHourForecast = LimitForecast.forecast(w, history: limitsReader.fiveHourHistory, now: now)
            }
        }
        // Claude ruxsat so'rab to'xtagan sessiyalar: hook xabaridan keyin transkriptda harakat bo'lmagan
        let notices = HookEvents.read()
        for sess in s.sessions {
            if let n = notices[sess.id], n.isPending(lastActivity: sess.lastActivity, now: now) {
                s.permissionWaits[sess.id] = n
            }
        }
        DispatchQueue.main.async {
            self.snap = s
            Alerts.shared.evaluate(s)
        }
    }

    func flush() {
        queue.sync { engine.flushHistory() }
    }

    func clearHistory() {
        queue.async { [engine] in
            engine.clearHistory()
            self.lastRevision = -1
        }
    }

    /// CSV eksport uchun to'liq tarix (asosiy oqimdan chaqiriladi)
    func allHistory() -> [DayPoint] {
        queue.sync { engine.allHistory() }
    }
}
