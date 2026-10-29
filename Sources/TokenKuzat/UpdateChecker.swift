import Foundation
import AppKit
import TokenKuzatCore

/// Kuniga bir marta GitHub'dagi so'nggi relizni tekshiradi. Yangi versiya bo'lsa — menyu panelida va Sozlamalarda
/// «yuklab olish» havolasi chiqadi. O'rnatish foydalanuvchida: DMG ochiladi, ilova Applications'ga sudraladi.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum Status: Equatable { case idle, checking, upToDate, failed }

    @Published private(set) var available: ReleaseInfo?
    @Published private(set) var status: Status = .idle
    @Published private(set) var lastCheck: Date?
    private var timer: Timer?

    func start() {
        guard UserDefaults.standard.bool(forKey: Pref.checkUpdates) else { return }
        check()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { [weak self] _ in self?.check() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func check() {
        status = .checking
        var req = URLRequest(url: ReleaseInfo.apiURL, timeoutInterval: 20)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("TokenKuzatuv/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, response, _ in
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            // 404 — hali reliz yo'q: yangilanish ham yo'q
            let info = code == 200 ? data.flatMap(ReleaseInfo.parse) : nil
            DispatchQueue.main.async {
                self.lastCheck = Date()
                if code == 200 || code == 404 {
                    let newer = info.flatMap { AppVersion.isNewer($0.version, than: AppInfo.version) ? $0 : nil }
                    self.available = newer
                    self.status = newer == nil ? .upToDate : .idle
                } else {
                    self.status = .failed
                }
            }
        }.resume()
    }

    func download() {
        guard let r = available else { return }
        NSWorkspace.shared.open(r.downloadURL)
    }
}
