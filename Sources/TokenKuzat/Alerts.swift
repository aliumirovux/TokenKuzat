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
                   Pref.notifyPermission, Pref.notifyContext].contains { d.bool(forKey: $0) }
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
            self.post("Token Kuzatuv: bildirishnomalar ishlayapti",
                      "Claude ishni tugatganda, qadam osilib qolganda yoki xatolar takrorlanganda shunday xabar keladi.")
        }
    }

    func evaluate(_ s: Snapshot) {
        evaluateBudget(s)
        evaluateActivity(s)
        evaluateRealLimits(s)
        evaluatePermission(s)
        evaluateContext(s)
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
            post("\(project): Claude ruxsatingizni kutyapti",
                 (n.message.isEmpty ? "Asbobdan foydalanish uchun ruxsat kerak." : Self.uz(n.message)) + "\nClaude Code oynasida javob bering.",
                 session: sid)
        }
    }

    /// Hook xabarini o'zbekchaga: «Claude needs your permission to use Bash» → «Bash uchun ruxsat so'rayapti»
    static func uz(_ message: String) -> String {
        let p = "Claude needs your permission to use "
        if message.hasPrefix(p) { return "\(message.dropFirst(p.count)) uchun ruxsat so'rayapti." }
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
            post("\(sess.project): kontekst \(Int((f * 100).rounded()))% to'ldi",
                 "\(Fmt.tokens(Double(sess.contextTokens))) / \(Fmt.tokens(Double(sess.contextWindow))). Tez orada suhbat avtomatik xulosa qilinadi — muhim narsalarni hozir ayting yoki ishni bo'lib bering.",
                 session: sess.id)
        }
    }

    // MARK: - Haqiqiy limit

    /// Har bir oyna (5 soat / hafta) uchun 80% va 95% da bir martadan — oyna tiklanguncha
    private func evaluateRealLimits(_ s: Snapshot) {
        let d = UserDefaults.standard
        guard d.bool(forKey: Pref.notifyRealLimit), let l = s.limits else { return }
        var fired = d.dictionary(forKey: "realLimitFired") as? [String: Double] ?? [:]
        for (name, w) in [("5 soatlik", l.fiveHour), ("Haftalik", l.sevenDay)] {
            guard let w else { continue }
            for t in [80.0, 95.0] where w.usedPercentage >= t {
                let key = "\(name)-\(Int(t))"
                guard fired[key] != w.resetsAt.timeIntervalSince1970 else { continue }
                fired[key] = w.resetsAt.timeIntervalSince1970
                let reset = Fmt.hourMinute.string(from: w.resetsAt)
                var body = "\(Int(w.usedPercentage.rounded()))% ishlatildi · \(reset) da tiklanadi (\(Self.duration(w.resetsAt.timeIntervalSinceNow)))."
                if name == "5 soatlik", case .runsOut(let at) = s.fiveHourForecast {
                    body += " Shu tezlikda ~\(Fmt.hourMinute.string(from: at)) da tugaydi."
                }
                post("\(name) Claude limiti: \(Int(t))%", body)
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
                post("\(e.project): Claude tugatdi",
                     "\(e.title)\n\(Self.duration(duration)) · \(steps) qadam · \(Fmt.tokens(tokens)) token. Javobingizni kutyapti.",
                     session: e.sessionId)
            case .stuck(let step, let duration):
                // Ruxsat kutilayotgani aniq bo'lsa — u haqda alohida xabar ketgan
                guard d.bool(forKey: Pref.notifyStuck), s.permissionWaits[e.sessionId] == nil else { continue }
                post("\(e.project): qadam \(Self.duration(duration)) dan beri tugamadi",
                     "\(e.agentTitle) · \(step)\nRuxsat so'rayotgan yoki osilib qolgan bo'lishi mumkin.",
                     session: e.sessionId)
            case .errorStreak(let count, let step):
                guard d.bool(forKey: Pref.notifyErrors) else { continue }
                post("\(e.project): ketma-ket \(count) ta xato",
                     "\(e.agentTitle) bir joyda aylanib qolgan bo'lishi mumkin.\nOxirgisi: \(step)",
                     session: e.sessionId)
            }
        }
    }

    static func duration(_ s: TimeInterval) -> String {
        let m = Int(s) / 60
        if m >= 60 { return "\(m / 60) soat \(m % 60) daq" }
        if m > 0 { return "\(m) daq" }
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
            let period = b.period == .day ? "Bugungi" : "5 soatlik"
            if t >= 1 {
                post("Token limiti tugadi", "\(period) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token.")
            } else {
                post("Token limitining \(Int(t * 100))% ishlatildi",
                     "\(period) sarf: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token.")
            }
        }
        d.set(fired, forKey: firedKey)
    }

    // MARK: - Yuborish va bosish

    private func post(_ title: String, _ body: String, session: String? = nil) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if let session {
            content.userInfo = ["session": session]
            content.threadIdentifier = session
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
            } else {
                WindowManager.shared.show(.overview)
            }
            done()
        }
    }
}
