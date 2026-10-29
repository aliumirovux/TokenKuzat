import Foundation
import AppKit
import TokenKuzatCore

/// Yangi sessiya ochish. Avtomatik rejimda xulosa birinchi xabar bo'lib o'zi yuboriladi; «Yangi sessiyada davom ettirish»
/// tugmasi esa xulosani saqlaydi (`arm`) — keyingi yangi sessiyaga SessionStart hook beradi.
enum AutoHandoff {
    private static let queue = DispatchQueue(label: "uz.ali.tokenkuzat.handoff", qos: .userInitiated)

    /// Xulosa `git log` / `git status` ni chaqiradi — asosiy oqimda emas, fonda yasaladi; `done` asosiy oqimda, chaqiruv tartibida
    static func summary(for sess: SessionSnap, _ done: @escaping (String) -> Void) {
        queue.async {
            let text = SavingsAdvisor.handoff(for: sess)
            DispatchQueue.main.async { done(text) }
        }
    }

    /// Xulosani saqlaydi. Muvaffaqiyatsiz bo'lsa — false
    @discardableResult
    static func arm(_ sess: SessionSnap, summary: String) -> Bool {
        do {
            try SessionStartHook.install()
            try HandoffStore.arm(PendingHandoff(text: summary, sourceSession: sess.id,
                                                cwd: SavingsAdvisor.projectFolder(for: sess) ?? sess.cwd, created: Date(),
                                                english: SavingsAdvisor.conversationEnglish(sess)))
            return true
        } catch {
            return false
        }
    }

    /// Yangi sessiyani ochib, xulosani birinchi xabar sifatida o'zi yuboradi — Claude ishni o'zi davom ettiradi.
    /// Xabar havolada (ilova) yoki buyruq argumentida (Terminal) beriladi, shuning uchun papka mos kelmasa ham yetib boradi.
    /// Eski sessiya vaqtinchalik papkada ishlagan bo'lsa ham, yangisi fayllar yozilgan loyiha papkasida ochiladi
    @discardableResult
    static func start(_ sess: SessionSnap, target: AutoHandoffTarget, summary: String) -> Bool {
        let message = AutoHandoffRule.firstMessage(summary: summary, previousContext: sess.contextTokens,
                                                   english: SavingsAdvisor.conversationEnglish(sess))
        return open(sess, target: target, message: message)
    }

    /// Sessiya loyihasida yangi sessiya — berilgan birinchi xabar bilan
    @discardableResult
    static func open(_ sess: SessionSnap, target: AutoHandoffTarget, message: String) -> Bool {
        let dir = SavingsAdvisor.projectFolder(for: sess) ?? sess.cwd
        switch target {
        case .app: return openInApp(cwd: dir, message: message)
        case .terminal: return openInTerminal(cwd: dir, message: message)
        }
    }

    /// Claude ilovasida yangi Code sessiyasi — o'sha papkada (Finder'dagi «New Claude Code Session Here» bilan bir xil havola).
    /// `folder`siz havola ilovani faqat oldinga chiqaradi, sessiya ochmaydi; `q` — birinchi xabar, darhol yuboriladi
    @discardableResult
    static func openInApp(cwd: String?, message: String? = nil) -> Bool {
        var c = URLComponents()
        c.scheme = "claude"
        c.host = "code"
        c.path = "/new"
        var items: [URLQueryItem] = []
        if let dir = projectDir(cwd) { items.append(URLQueryItem(name: "folder", value: dir)) }
        if let message { items.append(URLQueryItem(name: "q", value: message)) }
        items.append(URLQueryItem(name: "source", value: "services"))
        c.queryItems = items
        // «+» va «&» kabi belgilar so'rov qiymatida aniq kodlansin
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        guard let url = c.url else { return false }
        return NSWorkspace.shared.open(url)
    }

    /// Haqiqiy loyiha papkasi (Claude ilovasining vaqtinchalik papkasi yoki yo'q papka — nil)
    static func projectDir(_ cwd: String?) -> String? {
        guard let dir = cwd, !dir.contains("/scratch-workspaces/"), !dir.contains("/claude-code-sessions/"),
              FileManager.default.fileExists(atPath: dir) else { return nil }
        return dir
    }

    /// Terminal.app'da loyiha papkasida `claude "<birinchi xabar>"`. Claude ilovasining vaqtinchalik papkasi bo'lsa — uy papkasida.
    /// `prelude` — `claude` dan oldingi qatorlar (masalan, bepul modellarga yo'naltiruvchi o'zgaruvchilar)
    @discardableResult
    static func openInTerminal(cwd: String?, message: String? = nil, prelude: String? = nil) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = projectDir(cwd) ?? home
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        // Har ochish o'z fayllari bilan: ketma-ket ikki ochish (ikki sessiya, hook va ilova) bir-birining xabarini bosib ketmasin.
        // Skript ishga tushgach xabarni o'qib, ikkala faylni o'chiradi
        let folder = ProjectSavingsHistory.defaultURL.deletingLastPathComponent().appendingPathComponent("new-sessions")
        let id = UUID().uuidString
        let url = folder.appendingPathComponent("new-session-\(id).command")
        let promptURL = folder.appendingPathComponent("new-session-\(id).txt")
        // Eski versiyalarning umumiy fayllari
        for name in ["new-session.command", "new-session-prompt.txt"] {
            try? FileManager.default.removeItem(at: folder.deletingLastPathComponent().appendingPathComponent(name))
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var read = ""
            var run = "exec claude"
            if let message {
                try message.write(to: promptURL, atomically: true, encoding: .utf8)
                read = "P=\"$(cat \(quote(promptURL.path)))\"\n"
                run = "exec claude \"$P\""
            }
            // `claude` topilmasa — Terminal jim yopilmasin, nima qilish kerakligini aytsin
            let missing = tr("Token Kuzatuv: «claude» buyrug'i topilmadi. Claude Code'ni o'rnating yoki PATH'ga qo'shing (~/.zprofile).",
                             "Token Kuzatuv: the «claude» command wasn't found. Install Claude Code or add it to PATH (~/.zprofile).")
            // Ilova Claude sessiyasidan ishga tushirilgan bo'lsa, CLAUDE_* o'zgaruvchilari meros qoladi va yangi sessiya
            // o'zini «bola sessiya» deb biladi (tarix saqlanmaydi) — ularni tozalaymiz
            let extra = prelude.map { $0 + "\n" } ?? ""
            let script = "#!/bin/zsh -l\nunset -m 'CLAUDE*'\n\(extra)\(read)rm -f \(quote(url.path)) \(quote(promptURL.path))\n"
                + "command -v claude >/dev/null || { echo \(quote(missing)); exit 1; }\n"
                + "cd \(quote(dir)) && \(run)\n"
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch { return false }
        // `open` tugaguncha kutiladi: hook rejimida jarayon darhol chiqadi, asinxron ochish esa yarim yo'lda qolardi
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        p.arguments = ["-a", "Terminal", url.path]
        do { try p.run() } catch { return false }
        p.waitUntilExit()
        return p.terminationStatus == 0
    }
}
