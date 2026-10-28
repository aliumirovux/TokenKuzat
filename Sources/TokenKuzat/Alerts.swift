import Foundation
import UserNotifications
import TokenKuzatCore

/// Limitning 80% va 100% iga yetganda bitta bildirishnoma.
/// «Bugun» — har kuni qayta qurollanadi; «5 soat» — sarf 50% dan pastga tushganda.
final class Alerts {
    static let shared = Alerts()

    private let thresholds: [Double] = [0.8, 1.0]
    private let firedKey = "budgetFired"
    private let epochKey = "budgetEpoch"
    private var center: UNUserNotificationCenter? {
        AppInfo.isBundled ? UNUserNotificationCenter.current() : nil
    }

    func requestPermission(_ done: ((Bool) -> Void)? = nil) {
        guard let center else { done?(false); return }
        center.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            DispatchQueue.main.async { done?(ok) }
        }
    }

    func evaluate(_ s: Snapshot) {
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
            post(b, threshold: t)
        }
        d.set(fired, forKey: firedKey)
    }

    private func post(_ b: BudgetStatus, threshold: Double) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        let period = b.period == .day ? "bugungi" : "5 soatlik"
        if threshold >= 1 {
            content.title = "Token limiti tugadi"
            content.body = "\(period.capitalized) limit: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token."
        } else {
            content.title = "Token limitining \(Int(threshold * 100))% ishlatildi"
            content.body = "\(period.capitalized) sarf: \(Fmt.tokens(b.used)) / \(Fmt.tokens(b.limit)) vaznli token."
        }
        content.sound = .default
        center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
    }
}
