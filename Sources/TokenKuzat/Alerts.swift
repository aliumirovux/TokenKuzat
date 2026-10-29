import Foundation
import AppKit
import UserNotifications
import TokenKuzatCore

/// Barcha macOS bildirishnomalari: limit (80% / 100%) va sessiya hodisalari (tugadi, osildi, ketma-ket xato).
/// Bildirishnoma bosilsa — o'sha sessiya sxemada ochiladi.
final class Alerts: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Alerts()

    private let thresholds: [Double] = [0.8, 1.0]
    private let firedKey = "budgetFired"
    private let epochKey = "budgetEpoch"
    private let monitor = ActivityMonitor()
    private var center: UNUserNotificationCenter? {
        AppInfo.isBundled ? UNUserNotificationCenter.current() : nil
    }

    /// Ilova ochilganda: delegat va (biror bildirishnoma yoqilgan bo'lsa) ruxsat so'rovi
    func start() {
        guard let center else { return }
        center.delegate = self
        let d = UserDefaults.standard
        let any = [Pref.notifyFinished, Pref.notifyStuck, Pref.notifyErrors, Pref.notifyRealLimit,
                   Pref.notifyPermission, Pref.notifyContext, Pref.notifyWaste].contains { d.bool(forKey: $0) }
            || (d.bool(forKey: Pref.budgetEnabled) && d.bool(forKey: Pref.budgetNotify))
        if any { requestPermission() }
    }

    func requestPermission(_ done: ((Bool) -> Void)? = nil) {
        guard let center else { done?(false); return }
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { done?(ok) }
        }
    }

    /// Sozlamalardagi «Sinov bildirishnomasi» tugmasi
    func sendTest() {
        requestPermission { _ in
            self.post(tr("Token Kuzatuv: bildirishnomalar ishlayapti", "Token Kuzatuv: notifications are working"),
                      tr("Claude ishni tugatganda, qadam osilib qolganda yoki xatolar takrorlanganda shunday xabar keladi.",
                         "You'll get a message like this when Claude finishes, a step gets stuck, or errors repeat."))
        }
    }

    func evaluate(_ s: Snapshot) {
        evaluateBudget(s)
        evaluateActivity(s)
        evaluateRealLimits(s)
        evaluatePermission(s)
        evaluateContext(s)
        evaluateSavings(s)
        evaluateBigContext(s)
        evaluateProjectWaste(s)
    }

    // MARK: - Isrof

    private var bigContextWarned: Set<String> = []
    private var bigContextPrimed = false
    private var lastWasteCheck = Date.distantPast

    /// Ishlayotgan sessiya konteksti 200K dan oshganda — bir marta (100K dan tushsa — /compact yoki yangi sessiya — qayta qurollanadi).
    /// Ilova ochilgandagi mavjud katta sessiyalar uchun emas
    private func evaluateBigContext(_ s: Snapshot) {
        defer { bigContextPrimed = true }
        for sess in s.sessions {
            if sess.contextTokens < 100_000 { bigContextWarned.remove(sess.id); continue }
            guard sess.contextTokens >= 200_000, !bigContextWarned.contains(sess.id) else { continue }
            bigContextWarned.insert(sess.id)
            guard bigContextPrimed, sess.state != .idle, UserDefaults.standard.bool(forKey: Pref.notifyWaste) else { continue }
            let extra = sess.contextTokens - (SavingsAdvisor.startContext(for: sess) ?? SavingsAdvisor.baseline)
            post(tr("\(sess.project): kontekst \(Fmt.tokens(sess.contextTokens))", "\(sess.project): context \(Fmt.tokens(sess.contextTokens))"),
                 tr("Har javobda ~\(Fmt.tokens(extra)) ortiqcha qayta o'qilyapti. Yangi mavzu bo'lsa — yangi sessiya, shu mavzu bo'lsa — /compact. "
                    + "Bosing — sessiya ochiladi, «Yangi sessiyada davom ettirish» u yerda.",
                    "~\(Fmt.tokens(extra)) extra is re-read on every reply. New topic — a new session; same topic — /compact. "
                    + "Click to open the session — «Continue in a new session» is there."),
                 session: sess.id)
        }
    }

    /// Loyiha bugun sarfining 40%+ i isrof bo'lsa (narx bo'yicha, kamida 2M vaznli) — kuniga bir marta, 5 daqiqada bir tekshiriladi
    private func evaluateProjectWaste(_ s: Snapshot) {
        let now = s.updatedAt
        guard s.initialScanDone, now.timeIntervalSince(lastWasteCheck) >= 300 else { return }
        lastWasteCheck = now
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.notifyWaste) else { return }
        let day = HistoryStore.key(now)
        var alerted = d.dictionary(forKey: "wasteAlerted") as? [String: String] ?? [:]
        for r in ProjectSavings.reports(s, period: .today, now: now)
        where r.wasteShare(.weighted) >= 0.4 && r.waste(.weighted) >= 2_000_000 && alerted[r.project] != day {
            alerted[r.project] = day
            let pct = Int((r.wasteShare(.weighted) * 100).rounded())
            post(tr("\(r.project): bugun sarfning ~\(pct)% isrof", "\(r.project): ~\(pct)% of today's usage is waste"),
                 (r.issues.first.map { tr("Asosiy sabab: ", "Main cause: ") + $0.title.lowercased() + ". " } ?? "")
                    + tr("Bosing — Tejash sahifasida sabablar va «Claude'ga topshirish».",
                         "Click for the causes and «Hand to Claude» on the Savings page."),
                 section: .savings)
        }
        d.set(alerted, forKey: "wasteAlerted")
    }

    private var savingsAnnounced: [String: Int] = [:]
    private var savingsPrimed = false

    /// Kontekst katta (300K+) bo'lganda yangi mavzu (10 daqiqadan uzoq tanaffusdan keyingi so'rov) boshlansa —
    /// bir marta: yangi sessiya oching, davom etish xulosasi bilan. Model va sifat o'zgarmaydi
    private func evaluateSavings(_ s: Snapshot) {
        defer { savingsPrimed = true }
        for sess in s.sessions where sess.state != .idle && sess.contextTokens >= 300_000 {
            guard let t = sess.turns.last, sess.turns.count >= 2, savingsAnnounced[sess.id] != t.id else { continue }
            let prev = sess.turns[sess.turns.count - 2]
            guard !t.isContinuation, t.start.timeIntervalSince(prev.end) > 600 else { continue }
            savingsAnnounced[sess.id] = t.id
            guard savingsPrimed, UserDefaults.standard.bool(forKey: Pref.notifySavings) else { continue }
            let save = sess.contextTokens - SavingsAdvisor.baseline
            post(tr("\(sess.project): yangi mavzu — yangi sessiya arzonroq", "\(sess.project): new topic — a new session is cheaper"),
                 tr("Kontekst \(Fmt.tokens(Double(sess.contextTokens))). Yangi sessiyada har javobda ~\(Fmt.tokens(Double(save))) token tejaladi. "
                 + "Bosing — «Davom etish xulosasi»ni nusxalab, yangi sessiyaga qo'ying.",
                    "Context \(Fmt.tokens(Double(sess.contextTokens))). A new session saves ~\(Fmt.tokens(Double(save))) tokens on every reply. "
                 + "Click to copy the «Handoff summary» and paste it into a new session."),
                 session: sess.id)
        }
    }

    // MARK: - Ruxsat va kontekst

    private var announcedWaits: [String: Date] = [:]
    private var waitsPrimed = false
    private var contextWarned: Set<String> = []

    /// Claude ruxsat so'rab to'xtaganda — har bir so'rov uchun bir marta (ilova ochilgandagi eski holatlar uchun emas)
    private func evaluatePermission(_ s: Snapshot) {
        defer { waitsPrimed = true }
        for (sid, n) in s.permissionWaits where announcedWaits[sid] != n.date {
            announcedWaits[sid] = n.date
            guard waitsPrimed, UserDefaults.standard.bool(forKey: Pref.notifyPermission) else { continue }
            let project = s.sessions.first { $0.id == sid }?.project ?? "Claude"
            post(tr("\(project): Claude ruxsatingizni kutyapti", "\(project): Claude is waiting for your permission"),
                 (n.message.isEmpty ? tr("Asbobdan foydalanish uchun ruxsat kerak.", "Permission is needed to use a tool.") : Self.uz(n.message))
                    + tr("\nClaude Code oynasida javob bering.", "\nRespond in the Claude Code window."),
                 session: sid)
        }
    }

    /// Hook xabarini o'zbekchaga: «Claude needs your permission to use Bash» → «Bash uchun ruxsat so'rayapti»
    static func uz(_ message: String) -> String {
        let p = "Claude needs your permission to use "
        if message.hasPrefix(p) { return tr("\(message.dropFirst(p.count)) uchun ruxsat so'rayapti.", "Asking for permission to use \(message.dropFirst(p.count)).") }
        return message
    }

    /// Kontekst 85% dan oshganda — sessiyada bir marta; 50% dan tushsa (xulosa qilingan) qayta qurollanadi
    private func evaluateContext(_ s: Snapshot) {
        for sess in s.sessions {
            let f = sess.contextFraction
            if f < 0.5 { contextWarned.remove(sess.id); continue }
            guard f >= 0.85, sess.state != .idle, !contextWarned.contains(sess.id) else { continue }
            contextWarned.insert(sess.id)
            guard UserDefaults.standard.bool(forKey: Pref.notifyContext) else { continue }
            post(tr("\(sess.project): kontekst \(Int((f * 100).rounded()))% to'ldi", "\(sess.project): context \(Int((f * 100).rounded()))% full"),
                 "\(Fmt.tokens(Double(sess.contextTokens))) / \(Fmt.tokens(Double(sess.contextWindow))). "
                    + tr("Tez orada suhbat avtomatik xulosa qilinadi — muhim narsalarni hozir ayting yoki ishni bo'lib bering.",
                         "The conversation will soon be auto-summarized — say anything important now or split up the work."),
                 session: sess.id)
        }
    }

    // MARK: - Haqiqiy limit

    /// Har bir oyna (5 soat / hafta) uchun 80% va 95% da bir martadan — oyna tiklanguncha
    private func evaluateRealLimits(_ s: Snapshot) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.notifyRealLimit), let l = s.limits else { return }
        var fired = d.dictionary(forKey: "realLimitFired") as? [String: Double] ?? [:]
        for (name, label, w) in [("5 soatlik", tr("5 soatlik", "5-hour"), l.fiveHour), ("Haftalik", tr("Haftalik", "Weekly"), l.sevenDay)] {
            guard let w else { continue }
            for t in [80.0, 95.0] where w.usedPercentage >= t {
                let key = "\(name)-\(Int(t))"
                guard fired[key] != w.resetsAt.timeIntervalSince1970 else { continue }
                fired[key] = w.resetsAt.timeIntervalSince1970
                let reset = Fmt.hourMinute.string(from: w.resetsAt)
                var body = tr("\(Int(w.usedPercentage.rounded()))% ishlatildi · \(reset) da tiklanadi (\(Self.duration(w.resetsAt.timeIntervalSinceNow))).",
                               "\(Int(w.usedPercentage.rounded()))% used · resets at \(reset) (\(Self.duration(w.resetsAt.timeIntervalSinceNow))).")
                if name == "5 soatlik", case .runsOut(let at) = s.fiveHourForecast {
                    body += tr(" Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi.", " At this pace it runs out at ~\(Fmt.hourMinute.string(from: at)).")
                }
                post(tr("\(label) Claude limiti: \(Int(t))%", "\(label) Claude limit: \(Int(t))%"), body)
            }
        }
        d.set(fired, forKey: "realLimitFired")
    }

    // MARK: - Sessiya hodisalari

    private func evaluateActivity(_ s: Snapshot) {
        let d = UserDefaults.standard
        let cfg = ActivityMonitor.Config(finishMin: d.double(forKey: Pref.notifyFinishedMin),
                                         stuckAfter: d.double(forKey: Pref.notifyStuckSec),
                                         errorStreak: 3)
        // Monitor har doim yuradi (holatni eslab qolishi uchun), xabar esa faqat yoqilgan turlar uchun
        for e in monitor.process(s, config: cfg) {
            switch e.kind {
            case .finished(let duration, let tokens, let steps):
                guard d.bool(forKey: Pref.notifyFinished) else { continue }
                post(tr("\(e.project): Claude tugatdi", "\(e.project): Claude finished"),
                     tr("\(e.title)\n\(Self.duration(duration)) · \(steps) qadam · \(Fmt.tokens(tokens)) token. Javobingizni kutyapti.",
                        "\(e.title)\n\(Self.duration(duration)) · \(steps) \(steps == 1 ? "step" : "steps") · \(Fmt.tokens(tokens)) tokens. Waiting for your reply."),
                     session: e.sessionId)
            case .stuck(let step, let duration):
                // Ruxsat kutilayotgani aniq bo'lsa — u haqda alohida xabar ketgan
                guard d.bool(forKey: Pref.notifyStuck), s.permissionWaits[e.sessionId] == nil else { continue }
                post(tr("\(e.project): qadam \(Self.duration(duration)) dan beri tugamadi", "\(e.project): step hasn't finished for \(Self.duration(duration))"),
                     "\(e.agentTitle) · \(step)\n" + tr("Ruxsat so'rayotgan yoki osilib qolgan bo'lishi mumkin.", "It may be asking for permission or stuck."),
                     session: e.sessionId)
            case .errorStreak(let count, let step):
                guard d.bool(forKey: Pref.notifyErrors) else { continue }
                post(tr("\(e.project): ketma-ket \(count) ta xato", "\(e.project): \(count) errors in a row"),
                     tr("\(e.agentTitle) bir joyda aylanib qolgan bo'lishi mumkin.\nOxirgisi: \(step)",
                        "\(e.agentTitle) may be going in circles.\nLast one: \(step)"),
                     session: e.sessionId)
            }
        }
    }

    static func duration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        if m >= 60 { return tr("\(m / 60) soat \(m % 60) daq", "\(m / 60) h \(m % 60) min") }
        if m > 0 { return tr("\(m) daq", "\(m) min") }
        return "\(Int(s)) s"
    }

    // MARK: - Limit

    /// «Bugun» — har kuni qayta qurollanadi; «5 soat» — sarf 50% dan pastga tushganda.
    private func evaluateBudget(_ s: Snapshot) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.budgetNotify), let b = BudgetStatus.current(s) else { return }

        var epoch = d.integer(forKey: epochKey)
        if b.period == .fiveHours && b.fraction < 0.5 {
            // Oyna bo'shadi — keyingi to'lishda yana ogohlantiramiz
            if (d.dictionary(forKey: firedKey) as? [String: String])?.values.contains(where: { $0.hasPrefix("5h-\(epoch)") }) == true {
                epoch += 1
                d.set(epoch, forKey: epochKey)
            }
        }
        let periodKey = b.period == .day ? "day-" + HistoryStore.key(Date()) : "5h-\(epoch)"

        var fired = d.dictionary(forKey: firedKey) as? [String: String] ?? [:]
        for t in thresholds where b.fraction >= t {
            let k = String(t)
            guard fired[k] != periodKey else { continue }
            fired[k] = periodKey
            let period = b.period == .day ? tr("Bugungi", "Today's") : tr("5 soatlik", "5-hour")
            if t >= 1 {
                post(tr("Token limiti tugadi", "Token limit reached"),
                     tr("\(period) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token.", "\(period) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) weighted tokens."))
            } else {
                post(tr("Token limitining \(Int(t * 100))% ishlatildi", "\(Int(t * 100))% of token limit used"),
                     tr("\(period) sarf: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token.", "\(period) usage: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) weighted tokens."))
            }
        }
        d.set(fired, forKey: firedKey)
    }

    // MARK: - Yuborish va bosish

    private func post(_ title: String, _ body: String, session: String? = nil, section: Section? = nil) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let session {
            content.userInfo = ["session": session]
            content.threadIdentifier = session
        } else if let section {
            content.userInfo = ["section": section.rawValue]
        }
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }

    /// Ilova oynasi ochiq bo'lsa ham banner ko'rinsin
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler done: @escaping (UNNotificationPresentationOptions) -> Void) {
        done([.banner, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler done: @escaping () -> Void) {
        let session = response.notification.request.content.userInfo["session"] as? String
        DispatchQueue.main.async {
            if let session {
                UserDefaults.standard.set(session, forKey: GraphScreen.selectedSessionKey)
                WindowManager.shared.show(.graph)
            } else if let raw = response.notification.request.content.userInfo["section"] as? String, let section = Section(rawValue: raw) {
                WindowManager.shared.show(section)
            } else {
                WindowManager.shared.show(.overview)
            }
            done()
        }
    }
}
