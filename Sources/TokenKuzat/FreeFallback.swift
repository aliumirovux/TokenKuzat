import Foundation
import TokenKuzatCore

/// Bepul modellar (FreeLLMAPI) — ilova tomoni: serverni tekshirish, Claude limiti tugaganda ishni terminalda
/// bepul modelda davom ettirish va limit tiklanganda Claude'ga qaytarish. Claude ilovasidagi sessiyalarni
/// boshqa serverga yo'naltirib bo'lmaydi — bepul model faqat Terminal'dagi `claude` da ishlaydi.
enum FreeFallback {
    enum Check: Equatable {
        case ok(models: Int)
        case badKey
        case unreachable(String)
        case notConfigured
    }

    /// `GET /v1/models` — server ishlayaptimi va kalit to'g'rimi. Ulanib bo'lmasa — FreeLLMAPI ilovasini ochib, yana bir marta. `done` asosiy oqimda
    static func check(_ c: FreeModels.Config?, _ done: @escaping (Check) -> Void) {
        probe(c) { r in
            guard case .unreachable = r, let c, FreeModels.isLocal(c.url) else { done(r); return }
            DispatchQueue.global(qos: .userInitiated).async {
                let launched = launchIfNeeded(c)
                DispatchQueue.main.async { launched ? probe(c, done) : done(r) }
            }
        }
    }

    private static func probe(_ c: FreeModels.Config?, _ done: @escaping (Check) -> Void) {
        guard let c, let url = URL(string: FreeModels.rootURL(c.url) + "/v1/models") else { done(.notConfigured); return }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.setValue("Bearer \(c.key)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, resp, err in
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            let r: Check
            if let err {
                r = .unreachable(err.localizedDescription)
            } else if code == 401 || code == 403 {
                r = .badKey
            } else if code == 200, let data, let n = FreeModels.modelCount(data) {
                r = .ok(models: n)
            } else {
                r = .unreachable(data.flatMap(FreeModels.errorText) ?? "HTTP \(code)")
            }
            DispatchQueue.main.async { done(r) }
        }.resume()
    }

    /// FreeLLMAPI ilovasi yopiq bo'lsa — orqa fonda ochadi va server javob berguncha kutadi (ko'pi bilan `timeout`).
    /// Bloklaydi — asosiy oqimda chaqirilmasin. Manzil boshqa kompyuterda yoki ilova o'rnatilmagan bo'lsa — false
    @discardableResult
    static func launchIfNeeded(_ c: FreeModels.Config, timeout: TimeInterval = 25) -> Bool {
        if isUp(c) { return true }
        guard FreeModels.isLocal(c.url) else { return false }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-g", "-b", FreeModels.desktopBundleID]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        guard p.terminationStatus == 0 else { return false }
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            Thread.sleep(forTimeInterval: 0.5)
            if isUp(c) { return true }
        }
        return false
    }

    /// Kutmasdan: ilova ochilganda va ish bepul modelga ko'chayotganda — Claude Code ishga tushguncha server ham tayyor bo'ladi
    static func wake() {
        guard let c = FreeModels.load(), FreeModels.isLocal(c.url) else { return }
        DispatchQueue.global(qos: .utility).async { launchIfNeeded(c) }
    }

    /// Server javob beryaptimi: har qanday HTTP javob (hatto 401) — ishlayapti, ulanib bo'lmasa — yo'q
    private static func isUp(_ c: FreeModels.Config) -> Bool {
        guard let url = URL(string: FreeModels.rootURL(c.url) + "/v1/models") else { return false }
        var up = false
        let done = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 2)) { _, resp, _ in
            up = resp is HTTPURLResponse
            done.signal()
        }.resume()
        done.wait()
        return up
    }

    /// Bepul modelda davom etadigan ish: berilgan sessiya yoki so'nggi 3 soatda ishlagan eng yangi Claude sessiyasi
    static func source(in s: Snapshot, preferred: String? = nil, now: Date = Date()) -> SessionSnap? {
        if let preferred, let sess = s.sessions.first(where: { $0.id == preferred }), sess.isClaude { return sess }
        return s.sessions.first { $0.isClaude && ($0.lastActivity ?? .distantPast) >= now.addingTimeInterval(-3 * 3600) }
    }

    /// Terminalda Claude Code bepul modellarda ochiladi: sessiya bo'lsa — uning xulosasi birinchi xabar bo'ladi
    static func start(from sess: SessionSnap?, resetsAt: Date?, _ done: @escaping (Bool) -> Void) {
        guard let c = FreeModels.load() else { done(false); return }
        wake()
        let prelude = FreeModels.shellPrelude(url: c.url, configPath: FreeModels.configURL.path)
        guard let sess else { done(AutoHandoff.openInTerminal(cwd: nil, prelude: prelude)); return }
        AutoHandoff.summary(for: sess) { summary in
            let message = FreeModels.fallbackMessage(summary: summary, resetsAt: resetsAt,
                                                     english: SavingsAdvisor.conversationEnglish(sess))
            done(AutoHandoff.openInTerminal(cwd: SavingsAdvisor.projectFolder(for: sess) ?? sess.cwd,
                                            message: message, prelude: prelude))
        }
    }

    /// Xulosasiz, bo'sh sessiya — berilgan sessiya loyihasida (bo'lmasa — uy papkasida)
    static func openBlank(near sess: SessionSnap?) -> Bool {
        guard let c = FreeModels.load() else { return false }
        wake()
        return AutoHandoff.openInTerminal(cwd: sess.flatMap { SavingsAdvisor.projectFolder(for: $0) ?? $0.cwd },
                                          prelude: FreeModels.shellPrelude(url: c.url, configPath: FreeModels.configURL.path))
    }

    /// Limit tiklandi: bepul modelda ishlagan eng so'nggi sessiya xulosasi bilan Claude'da yangi sessiya
    /// (avtomatik ko'chirish sozlamasidagi joyda — ilova yoki terminal). `since` — limit tugagan vaqt: undan oldingi
    /// bepul sessiya bu limit davriga tegishli emas. Bunday sessiya bo'lmasa — false
    static func returnToClaude(in s: Snapshot, since: Date?, _ done: @escaping (Bool) -> Void) {
        guard let sess = s.sessions.first(where: { !$0.isClaude && ($0.lastActivity ?? .distantPast) >= (since ?? .distantPast) })
        else { done(false); return }
        let target = AutoHandoffTarget(rawValue: UserDefaults.standard.string(forKey: Pref.autoHandoffTarget) ?? "") ?? .app
        AutoHandoff.summary(for: sess) { summary in
            let message = FreeModels.returnMessage(summary: summary, english: SavingsAdvisor.conversationEnglish(sess))
            done(AutoHandoff.open(sess, target: target, message: message))
        }
    }
}
