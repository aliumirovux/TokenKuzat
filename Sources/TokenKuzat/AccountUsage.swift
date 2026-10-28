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
        /// Anthropic «so'rov juda ko'p» (429) dedi — shu paytgacha kutiladi, oxirgi raqamlar ko'rsatib turiladi
        case throttled(Date)
    }

    private let queue = DispatchQueue(label: "uz.ali.tokenkuzat.account")
    private var _latest: RateLimits?
    private var _status: Status = .off
    private var history: [(Date, Double)] = []
    private var timer: DispatchSourceTimer?
    private var inFlight = false
    /// Kalit xotirada saqlanadi: Keychain faqat birinchi marta, muddati tugaganda yoki rad etilganda qayta o'qiladi —
    /// macOS ruxsat oynasi har daqiqada chiqmasin
    private var cached: Credentials?
    /// 429 dan keyin: shu paytgacha so'rov yuborilmaydi; har takror 429 da kutish ikki baravar (15 daqiqagacha)
    private var notBefore = Date.distantPast
    private var backoff: TimeInterval = 0

    /// So'rovlar oralig'i
    static let interval: TimeInterval = 90
    /// Shundan eski hisob ma'lumoti ishlatilmaydi (status line'ga qaytiladi)
    static let maxAge: TimeInterval = 30 * 60

    /// Oxirgi javob diskda — ilova qayta ochilganda darhol ko'rsatiladi va keraksiz so'rov yuborilmaydi
    private static var cacheURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("account-usage.json")
    }

    init() {
        if let d = try? Data(contentsOf: Self.cacheURL),
           let o = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
           let ts = (o["saved_at"] as? NSNumber)?.doubleValue,
           let body = (o["body"] as? String)?.data(using: .utf8),
           var r = AccountUsageAPI.parse(body, at: Date(timeIntervalSince1970: ts)) {
            r.plan = o["plan"] as? String
            _latest = r
            _status = .ok(r.updatedAt)
            // Yaqinda olingan bo'lsa — darhol qayta so'ramaymiz
            notBefore = r.updatedAt.addingTimeInterval(Self.interval)
            if let w = r.fiveHour { history = [(r.updatedAt, w.usedPercentage)] }
        }
    }

    var latest: RateLimits? { queue.sync { _latest } }
    var status: Status { queue.sync { _status } }
    var fiveHourHistory: [(Date, Double)] { queue.sync { history } }

    var isEnabled: Bool { UserDefaults.standard.bool(forKey: Pref.accountUsage) }

    func start() {
        guard isEnabled else { return }
        queue.async { [self] in
            guard timer == nil else { return }
            let t = DispatchSource.makeTimerSource(queue: queue)
            t.schedule(deadline: .now() + 1, repeating: Self.interval, leeway: .seconds(5))
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
            cached = nil
            history.removeAll()
        }
    }

    /// «Hozir yangilash» — 429 kutishini hurmat qiladi
    func refreshNow() { queue.async { [self] in fetch() } }

    // MARK: - So'rov

    private func fetch() {
        guard !inFlight, Date() >= notBefore else { return }
        if let c = cached, let exp = c.expiresAt, exp < Date() { cached = nil }
        if cached == nil { cached = Self.readCredentials() }
        guard let cred = cached else {
            _status = .noCredentials
            return
        }
        if let exp = cred.expiresAt, exp < Date() {
            cached = nil
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
                } else if code == 429 {
                    let header = (resp as? HTTPURLResponse)?.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 0
                    self.backoff = min(15 * 60, max(120, self.backoff * 2))
                    self.notBefore = now.addingTimeInterval(max(header, self.backoff))
                    self._status = .throttled(self.notBefore)
                } else if code == 401 || code == 403 {
                    // Kalit yangilangan bo'lishi mumkin — keyingi safar Keychain'dan qayta o'qiladi
                    self.cached = nil
                    self._status = .expired
                } else if code != 200 {
                    self._status = .failed("HTTP \(code)")
                } else if let data, var r = AccountUsageAPI.parse(data, at: now) {
                    r.plan = cred.plan
                    self._latest = r
                    self._status = .ok(now)
                    self.backoff = 0
                    self.notBefore = now.addingTimeInterval(Self.interval - 5)
                    if let w = r.fiveHour { self.record(w, at: now) }
                    Self.save(data, plan: cred.plan, at: now)
                } else {
                    self._status = .failed(tr("Javobni o'qib bo'lmadi", "Couldn't read the response"))
                }
            }
        }.resume()
    }

    /// Faqat javob tanasi (foizlar va vaqtlar) saqlanadi — kalit emas
    private static func save(_ body: Data, plan: String?, at t: Date) {
        var o: [String: Any] = ["saved_at": t.timeIntervalSince1970, "body": String(decoding: body, as: UTF8.self)]
        if let plan { o["plan"] = plan }
        if let d = try? JSONSerialization.data(withJSONObject: o) { try? d.write(to: cacheURL, options: .atomic) }
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
