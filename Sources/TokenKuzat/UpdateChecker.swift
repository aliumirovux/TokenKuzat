import Foundation
import AppKit
import CryptoKit
import TokenKuzatCore

/// Kuniga bir marta GitHub'dagi so'nggi relizni tekshiradi. Yangi versiya bo'lsa — menyu panelida va Sozlamalarda
/// «Yangilash» tugmasi chiqadi: DMG yuklanadi, `.sha256` bilan tekshiriladi, ilova o'rnida almashtirilib qayta ochiladi.
/// Ilova ichida o'rnatib bo'lmasa (papkaga yozish ruxsati yo'q, DMG'dan ochilgan) — avvalgidek DMG ochiladi.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum Status: Equatable { case idle, checking, upToDate, failed }
    enum Install: Equatable { case none, downloading, installing, failed(String) }

    @Published private(set) var available: ReleaseInfo?
    @Published private(set) var status: Status = .idle
    @Published private(set) var install: Install = .none
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

    /// Ilova shu yerda o'zini almashtira oladimi: .app ichida, DMG yoki «translocation» dan emas, papkasiga yozsa bo'ladi
    var canInstallInPlace: Bool {
        guard AppInfo.isBundled, available?.canInstall == true else { return false }
        let app = Bundle.main.bundleURL
        guard !app.path.contains("/AppTranslocation/"), !app.path.hasPrefix("/Volumes/") else { return false }
        return FileManager.default.isWritableFile(atPath: app.deletingLastPathComponent().path)
    }

    /// Yuklaydi, tekshiradi, o'rnatadi va qayta ochadi. O'rnida almashtirib bo'lmasa — DMG'ni ochadi.
    func installUpdate() {
        guard let r = available, install != .downloading, install != .installing else { return }
        guard canInstallInPlace else { return download() }
        install = .downloading
        Task.detached(priority: .userInitiated) {
            do {
                let staged = try await Self.prepare(r)
                await MainActor.run { self.install = .installing }
                try Self.swapAndRelaunch(staged: staged)
                await MainActor.run { NSApp.terminate(nil) }
            } catch {
                let msg = (error as? UpdateError)?.message ?? error.localizedDescription
                await MainActor.run { self.install = .failed(msg) }
            }
        }
    }

    struct UpdateError: Error { let message: String }

    /// DMG'ni yuklab, tekshirib, yangi ilovani joriy ilova yonidagi yashirin papkaga ko'chiradi
    private static func prepare(_ r: ReleaseInfo) async throws -> URL {
        guard let sumURL = r.checksumURL else { throw UpdateError(message: tr("Relizda SHA-256 fayli yo'q", "The release has no SHA-256 file")) }
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("TokenKuzatUpdate-\(UUID().uuidString)")
        try fm.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }

        let (sumData, sumResp) = try await retrying { try await URLSession.shared.data(from: sumURL) }
        guard (sumResp as? HTTPURLResponse)?.statusCode == 200,
              let expected = ReleaseInfo.parseChecksum(String(decoding: sumData, as: UTF8.self)) else {
            throw UpdateError(message: tr("SHA-256 faylini o'qib bo'lmadi", "Couldn't read the SHA-256 file"))
        }
        let (tmp, resp) = try await retrying { try await URLSession.shared.download(from: r.downloadURL) }
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateError(message: tr("DMG yuklanmadi", "The DMG didn't download"))
        }
        let dmg = work.appendingPathComponent("update.dmg")
        try fm.moveItem(at: tmp, to: dmg)
        let actual = SHA256.hash(data: try Data(contentsOf: dmg, options: .mappedIfSafe)).map { String(format: "%02x", $0) }.joined()
        guard actual == expected else { throw UpdateError(message: tr("DMG buzilgan (SHA-256 mos emas)", "The DMG is corrupt (SHA-256 mismatch)")) }

        let mount = work.appendingPathComponent("mnt")
        guard run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path]) else {
            throw UpdateError(message: tr("DMG ochilmadi", "Couldn't open the DMG"))
        }
        defer { _ = run("/usr/bin/hdiutil", ["detach", mount.path, "-force"]) }

        let current = Bundle.main.bundleURL
        guard let newApp = (try? fm.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil))?
                .first(where: { $0.pathExtension == "app" }),
              let info = Bundle(url: newApp)?.infoDictionary,
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              info["CFBundleShortVersionString"] as? String == r.version else {
            throw UpdateError(message: tr("DMG ichida kutilgan ilova yo'q", "The DMG doesn't hold the expected app"))
        }
        guard run("/usr/bin/codesign", ["--verify", "--strict", newApp.path]) else {
            throw UpdateError(message: tr("Yangi ilova imzosi buzilgan", "The new app's signature is broken"))
        }

        // Joriy ilova bilan bir diskda — almashtirish bitta `mv` bo'lsin
        let staged = current.deletingLastPathComponent().appendingPathComponent(".TokenKuzat-update-\(r.version).app")
        try? fm.removeItem(at: staged)
        guard run("/usr/bin/ditto", [newApp.path, staged.path]) else {
            throw UpdateError(message: tr("Yangi ilovani ko'chirib bo'lmadi", "Couldn't copy the new app"))
        }
        _ = run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", staged.path])
        return staged
    }

    /// Tarmoq uzilishida bir marta qayta urinadi (GitHub CDN ulanishni ba'zan uzib qo'yadi)
    private static func retrying<T>(_ op: () async throws -> T) async throws -> T {
        do { return try await op() } catch let e as URLError where e.code != .cancelled {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return try await op()
        }
    }

    /// Ilova yopilgach eski .app'ni yangisiga almashtirib, qayta ochadigan alohida jarayon. Almashtirish
    /// muvaffaqiyatsiz bo'lsa eski ilova joyiga qaytariladi va o'sha ochiladi.
    private static func swapAndRelaunch(staged: URL) throws {
        let app = Bundle.main.bundleURL.path
        let script = """
            while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
            rm -rf "$2.old"
            if mv "$2" "$2.old" && mv "$3" "$2"; then rm -rf "$2.old"
            else [ -d "$2" ] || mv "$2.old" "$2"; rm -rf "$3"; fi
            open "$2"
            """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script, "tk-update", String(ProcessInfo.processInfo.processIdentifier), app, staged.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> Bool {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
