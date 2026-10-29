import Foundation
import AppKit
import TokenKuzatCore

/// Yangi sessiya ochish. Avtomatik rejimda xulosa birinchi xabar bo'lib o'zi yuboriladi; «Yangi sessiyada davom ettirish»
/// tugmasi esa xulosani saqlaydi (`arm`) — keyingi yangi sessiyaga SessionStart hook beradi.
enum AutoHandoff {
    /// Xulosani saqlaydi. Muvaffaqiyatsiz bo'lsa — false
    @discardableResult
    static func arm(_ sess: SessionSnap) -> Bool {
        do {
            try SessionStartHook.install()
            try HandoffStore.arm(PendingHandoff(text: SavingsAdvisor.handoff(for: sess), sourceSession: sess.id,
                                                cwd: sess.cwd, created: Date()))
            return true
        } catch {
            return false
        }
    }

    /// Yangi sessiyani ochib, xulosani birinchi xabar sifatida o'zi yuboradi — Claude ishni o'zi davom ettiradi.
    /// Xabar havolada (ilova) yoki buyruq argumentida (Terminal) beriladi, shuning uchun papka mos kelmasa ham yetib boradi
    @discardableResult
    static func start(_ sess: SessionSnap, target: AutoHandoffTarget) -> Bool {
        let message = AutoHandoffRule.firstMessage(summary: SavingsAdvisor.handoff(for: sess), previousContext: sess.contextTokens,
                                                   english: SavingsAdvisor.conversationEnglish(sess))
        switch target {
        case .app: return openInApp(cwd: sess.cwd, message: message)
        case .terminal: return openInTerminal(cwd: sess.cwd, message: message)
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

    /// Terminal.app'da loyiha papkasida `claude "<birinchi xabar>"`. Claude ilovasining vaqtinchalik papkasi bo'lsa — uy papkasida
    @discardableResult
    static func openInTerminal(cwd: String?, message: String? = nil) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = projectDir(cwd) ?? home
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let folder = ProjectSavingsHistory.defaultURL.deletingLastPathComponent()
        let url = folder.appendingPathComponent("new-session.command")
        let promptURL = folder.appendingPathComponent("new-session-prompt.txt")
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var run = "exec claude"
            if let message {
                try message.write(to: promptURL, atomically: true, encoding: .utf8)
                run = "exec claude \"$(cat \(quote(promptURL.path)))\""
            }
            // Ilova Claude sessiyasidan ishga tushirilgan bo'lsa, CLAUDE_* o'zgaruvchilari meros qoladi va yangi sessiya
            // o'zini «bola sessiya» deb biladi (tarix saqlanmaydi) — ularni tozalaymiz
            try "#!/bin/zsh -l\nunset -m 'CLAUDE*'\ncd \(quote(dir)) && \(run)\n".write(to: url, atomically: true, encoding: .utf8)
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
