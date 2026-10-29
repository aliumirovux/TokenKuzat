import Foundation
import AppKit
import TokenKuzatCore

/// Yangi sessiya ochish: xulosa saqlanadi (SessionStart hook uni yangi sessiyaga beradi) va
/// Claude ilovasida yoki Terminalda yangi sessiya ochiladi. «Yangi sessiyada davom ettirish» tugmasi ham shundan foydalanadi.
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

    /// Xulosani saqlab, yangi sessiyani ochadi. Xulosa saqlanmasa — hech narsa ochilmaydi
    @discardableResult
    static func start(_ sess: SessionSnap, target: AutoHandoffTarget) -> Bool {
        guard arm(sess) else { return false }
        switch target {
        case .app: openInApp(cwd: sess.cwd)
        case .terminal: openInTerminal(cwd: sess.cwd)
        }
        return true
    }

    /// Claude ilovasida yangi Code sessiyasi — o'sha papkada (Finder'dagi «New Claude Code Session Here» bilan bir xil havola).
    /// `folder`siz havola ilovani faqat oldinga chiqaradi, sessiya ochmaydi
    static func openInApp(cwd: String?) {
        var c = URLComponents()
        c.scheme = "claude"
        c.host = "code"
        c.path = "/new"
        var items: [URLQueryItem] = []
        if let dir = projectDir(cwd) { items.append(URLQueryItem(name: "folder", value: dir)) }
        items.append(URLQueryItem(name: "source", value: "services"))
        c.queryItems = items
        guard let url = c.url else { return }
        NSWorkspace.shared.open(url)
    }

    /// Haqiqiy loyiha papkasi (Claude ilovasining vaqtinchalik papkasi yoki yo'q papka — nil)
    static func projectDir(_ cwd: String?) -> String? {
        guard let dir = cwd, !dir.contains("/scratch-workspaces/"), !dir.contains("/claude-code-sessions/"),
              FileManager.default.fileExists(atPath: dir) else { return nil }
        return dir
    }

    /// Terminal.app'da loyiha papkasida `claude`. Claude ilovasining vaqtinchalik papkasi bo'lsa — uy papkasida
    static func openInTerminal(cwd: String?) {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dir = projectDir(cwd) ?? home
        let quoted = "'" + dir.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let script = "#!/bin/zsh -l\ncd \(quoted) && exec claude\n"
        let url = ProjectSavingsHistory.defaultURL.deletingLastPathComponent().appendingPathComponent("new-session.command")
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        } catch { return }
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([url], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
    }
}
