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
    /// Loyihalar bo'yicha kunlik sarf/isrof va tuzatish sanalari — «Tejash» sahifasidagi «avval / keyin» uchun
    @Published private(set) var savingsHistory = ProjectSavingsData()

    private let engine: Engine
    private let limitsReader = RateLimitsReader()
    private let outsideTracker = OutsideUsageTracker()
    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.engine", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastRevision = -1
    private var lastPublish = Date.distantPast
    private let projectHistory = ProjectSavingsHistory()
    private var lastProjectRecord = Date.distantPast

    init() {
        engine = Engine(history: HistoryStore(url: HistoryStore.defaultURL))
        savingsHistory = projectHistory.load()
        let t = DispatchSource.makeTimerSource(queue: queue)
        // Birinchi o'qish bir necha soniya oladi (yuzlab MB yozuv) — shu orada panelda limitlar bo'sh turmasin
        queue.async { [weak self] in
            guard let self else { return }
            var s = Snapshot()
            self.applyLimits(&s, now: Date())
            guard s.limits != nil else { return }
            DispatchQueue.main.async { if !self.snap.initialScanDone { self.snap = s } }
        }
        t.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(250))
        t.setEventHandler { [weak self] in self?.step() }
        t.resume()
        timer = t
    }

    /// Status line va Claude hisobidan limitlar — yozuvlarni o'qishga bog'liq emas, bir zumda
    private func applyLimits(_ s: inout Snapshot, now: Date) {
        let statusLine = limitsReader.read()
        s.applyContextWindows(statusLine?.windowBySession ?? [:])
        if let l = statusLine?.active(at: now), !l.isEmpty || !l.costBySession.isEmpty {
            s.limits = l
            if let w = l.fiveHour {
                s.fiveHourForecast = LimitForecast.forecast(w, history: limitsReader.fiveHourHistory, now: now)
            }
            if let w = l.sevenDay { s.weekForecast = WeeklyForecast.forecast(w, now: now) }
        }
        // Hisobdan olingan limit (claude.ai bilan bir xil) — yangi bo'lsa, status line'dan ustun
        let acct = AccountUsage.shared
        if acct.isEnabled, var a = acct.latest?.active(at: now), !a.isEmpty,
           now.timeIntervalSince(a.updatedAt) < AccountUsage.maxAge,
           a.updatedAt >= (s.limits?.updatedAt ?? .distantPast) || s.limits?.fromAccount == false {
            a.costBySession = s.limits?.costBySession ?? [:]
            s.limits = a
            if let w = a.fiveHour { s.fiveHourForecast = LimitForecast.forecast(w, history: acct.fiveHourHistory, now: now) }
            if let w = a.sevenDay { s.weekForecast = WeeklyForecast.forecast(w, now: now) }
        }
    }

    private func step() {
        let now = Date()
        engine.update(now: now)
        guard engine.revision != lastRevision || now.timeIntervalSince(lastPublish) >= 3 else { return }
        lastRevision = engine.revision
        lastPublish = now
        var s = engine.snapshot()
        applyLimits(&s, now: now)
        // Limit o'sishini Mac sarfi bilan solishtirib — chat va bulutga ketgan qism
        if let l = s.limits, let w = l.fiveHour {
            outsideTracker.observe(w, at: l.updatedAt, minutes: s.recentMinutes)
        }
        let out = outsideTracker.summary(now: now)
        if out.hasWindow || out.outsideTodayPct > 0 { s.outside = out }
        // Claude ruxsat so'rab to'xtagan sessiyalar: hook xabaridan keyin transkriptda harakat bo'lmagan
        let notices = HookEvents.read()
        for sess in s.sessions {
            if let n = notices[sess.id], n.isPending(lastActivity: sess.lastActivity, now: now) {
                s.permissionWaits[sess.id] = n
            } else if let n = notices[sess.id], n.isFreshFailure(lastActivity: sess.lastActivity, now: now) {
                s.failures[sess.id] = n
            }
        }
        // Loyiha yakunlari 5 daqiqada bir marta diskka (bugungi kun ustiga yoziladi)
        var savings: ProjectSavingsData?
        if s.initialScanDone, now.timeIntervalSince(lastProjectRecord) >= 300 {
            lastProjectRecord = now
            savings = projectHistory.record(ProjectSavings.reports(s, period: .today, now: now),
                                             cache: ProjectSavings.cacheDays(s, now: now), now: now)
        }
        DispatchQueue.main.async {
            self.snap = s
            if let savings, savings != self.savingsHistory { self.savingsHistory = savings }
            Alerts.shared.evaluate(s)
            ProjectTracker.shared.update(s)
        }
    }

    /// «Claude'ga topshirish» bosilganda — shu sanadan keyingi kunlar «keyin» sifatida solishtiriladi
    func markFixed(_ project: String) {
        queue.async { [projectHistory] in
            let data = projectHistory.markFixed(project)
            DispatchQueue.main.async { self.savingsHistory = data }
        }
    }

    func flush() {
        queue.sync { engine.flushHistory() }
    }

    func clearHistory() {
        queue.async { [engine] in
            engine.clearHistory()
            self.outsideTracker.reset()
            self.projectHistory.clear()
            DispatchQueue.main.async { self.savingsHistory = ProjectSavingsData() }
            self.lastRevision = -1
        }
    }

    /// CSV eksport uchun to'liq tarix (asosiy oqimdan chaqiriladi)
    func allHistory() -> [DayPoint] {
        queue.sync { engine.allHistory() }
    }
}
