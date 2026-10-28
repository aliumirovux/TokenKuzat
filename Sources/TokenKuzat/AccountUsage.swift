import Foundation
import Security
import TokenKuzatCore

/// Claude hisobidagi haqiqiy limit (claude.ai «Usage» sahifasi bilan bir xil manba).
///
/// Claude Code kirish kalitini macOS Keychain'da («Claude Code-credentials») saqlaydi. Ilova shu kalitni o'qib,
/// faqat Anthropic'ning usage manziliga so'rov yuboradi; kalit hech qayerga yozilmaydi va boshqa joyga ketmaydi.
/// Birinchi o'qishda macOS ruxsat so'raydi. Kalit muddati o'tgan bo'lsa — Claude Code uni o'zi yangilaguncha kutiladi.
final class AccountUsage {
    static let shared = AccountUsage()

    enum Status: Equatable {
        case off
        case loading
        case ok(Date)
        /// Keychain'da Claude Code kaliti topilmadi (Claude Code'ga kirilmagan) yoki ruxsat berilmadi
        case noCredentials
        /// Kalit muddati o'tgan — Claude Code'da biror so'rov yuborilsa, u yangilanadi
        case expired
        case failed(String)
    }

    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.account")
    private var _latest: RateLimits?
    private var _status: Status = .off
    private var history: [(Date, Double)] = []
    private var timer: DispatchSourceTimer?
    private var inFlight = false

    /// Shundan eski hisob ma'lumoti ishlatilmaydi (status line'ga qaytiladi)
    static let maxAge: TimeInterval = 15 * 60

    var latest: RateLimits? { queue.sync { _latest } }
    var status: Status { queue.sync { _status } }
    var fiveHourHistory: [(Date, Double)] { queue.sync { history } }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Pref.accountUsage) }

    func start() {
        guard isEnabled else { return }
        queue.async { [self] in
            guard timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now(), repeating: 60, leeway: .seconds(5))
            t.setEventHandler { [weak self] in self?.fetch() }
            t.resume()
            timer = t
        }
    }

    func stop() {
        queue.async { [self] in
            timer?.cancel()
            timer = nil
            _latest = nil
            _status = .off
            history.removeAll()
        }
    }

    func refreshNow() { queue.async { [self] in fetch() } }

    // MARK: - So'rov

    private func fetch() {
        guard !inFlight else { return }
        guard let cred = Self.readCredentials() else {
            _status = .noCredentials
            return
        }
        if let exp = cred.expiresAt, exp < Date() {
            _status = .expired
            return
        }
        inFlight = true
        if _latest == nil { _status = .loading }
        var req = URLRequest(url: AccountUsageAPI.url, timeoutInterval: 20)
        req.setValue("Bearer \(cred.token)", forHTTPHeaderField: "Authorization")
        req.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue("TokenKuzatuv/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
            guard let self else { return }
            self.queue.async {
                self.inFlight = false
                let now = Date()
                let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                if let err {
                    self._status = .failed(err.localizedDescription)
                } else if code == 401 || code == 403 {
                    self._status = .expired
                } else if code != 200 {
                    self._status = .failed("HTTP \(code)")
                } else if let data, var r = AccountUsageAPI.parse(data, at: now) {
                    r.plan = cred.plan
                    self._latest = r
                    self._status = .ok(now)
                    if let w = r.fiveHour { self.record(w, at: now) }
                } else {
                    self._status = .failed("Javobni o'qib bo'lmadi")
                }
            }
        }.resume()
    }

    private func record(_ w: LimitWindow, at t: Date) {
        if let last = history.last, w.usedPercentage + 0.5 < last.1 { history.removeAll() }
        history.append((t, w.usedPercentage))
        history.removeAll { t.timeIntervalSince($0.0) > 3600 }
    }

    // MARK: - Keychain

    private struct Credentials {
        let token: String
        let expiresAt: Date?
        let plan: String?
    }

    private static func readCredentials() -> Credentials? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "Claude Code-credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let data = out as? Data,
              let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let oauth = o["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String, !token.isEmpty else { return nil }
        let exp = (oauth["expiresAt"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue / 1000) }
        let plan = AccountUsageAPI.planName(subscriptionType: oauth["subscriptionType"] as? String,
                                            rateLimitTier: oauth["rateLimitTier"] as? String)
        return Credentials(token: token, expiresAt: exp, plan: plan)
    }
}
