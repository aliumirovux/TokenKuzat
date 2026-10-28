import Foundation
import TokenKuzatCore

/// Claude Code «Notification» hook'iga ulanish: Claude ruxsat so'raganda xabar shu yerga keladi.
///
/// ~/.claude/settings.json → hooks.Notification ga bizning skript qo'shiladi (boshqa hook'lar tegilmaydi).
/// Skript JSON'ni ilovaning `--hook` rejimiga beradi: u hooks/<session_id>.json ga yozadi va darhol chiqadi.
enum Hooks {
    static let flag = "--hook"
    private static let marker = "TokenKuzat/notify.sh"

    private static var scriptURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("notify.sh")
    }

    private static var command: String { "\"\(scriptURL.path)\"" }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code Notification hook (ilova yaratgan; Sozlamalarda o'chirilsa olib tashlanadi)
        T="${TMPDIR:-/tmp}/tokenkuzat-hook.$$"
        cat > "$T"
        if [ -x "\(exe)" ]; then "\(exe)" \(flag) < "$T" >/dev/null 2>&1; fi
        rm -f "$T"
        exit 0

        """
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    // MARK: - Holat

    static var isInstalled: Bool {
        guard let s = try? StatusLine.readSettings() else { return false }
        return entries(s).contains { isOurs($0) }
    }

    private static func entries(_ s: [String: Any]) -> [[String: Any]] {
        ((s["hooks"] as? [String: Any])?["Notification"] as? [[String: Any]]) ?? []
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        ((entry["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
    }

    // MARK: - Ulash / uzish

    static func install() throws {
        var s = try StatusLine.readSettings()
        try writeScript()
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        var list = entries(s).filter { !isOurs($0) }
        list.append(["matcher": "", "hooks": [["type": "command", "command": command]]])
        hooks["Notification"] = list
        s["hooks"] = hooks
        try StatusLine.backupOnce()
        try StatusLine.writeSettings(s)
    }

    static func uninstall() throws {
        var s = try StatusLine.readSettings()
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        let list = entries(s).filter { !isOurs($0) }
        if list.isEmpty { hooks.removeValue(forKey: "Notification") } else { hooks["Notification"] = list }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        try StatusLine.writeSettings(s)
        try? FileManager.default.removeItem(at: scriptURL)
    }

    // MARK: - `--hook` rejimi (Claude Code chaqiradi)

    /// JSON'ni qabul vaqti bilan sessiya fayliga yozadi va chiqadi. Hech narsa chiqarmaydi — Claude Code'ga xalaqit bermaydi.
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        guard var o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let sid = o["session_id"] as? String, !sid.isEmpty, !sid.contains("/") else { exit(0) }
        o["received_at"] = Date().timeIntervalSince1970
        let dir = HookEvents.defaultDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        if let out = try? JSONSerialization.data(withJSONObject: o) {
            try? out.write(to: dir.appendingPathComponent(sid + ".json"), options: .atomic)
        }
        exit(0)
    }
}

/// Claude Code «SessionStart» hook'i: «Yangi sessiyada davom ettirish» bosilgan bo'lsa, xulosani yangi sessiyaga beradi.
///
/// Skript avval xulosa fayli borligini tekshiradi — yo'q bo'lsa darhol chiqadi (har sessiya ochilishiga ta'sir qilmaydi).
/// Bor bo'lsa, ilovaning `--session-start` rejimi xulosani additionalContext sifatida qaytaradi va faylni o'chiradi.
enum SessionStartHook {
    static let flag = "--session-start"
    private static let event = "SessionStart"
    private static let marker = "TokenKuzat/session-start.sh"

    private static var scriptURL: URL {
        RateLimitsReader.defaultDirectory.deletingLastPathComponent().appendingPathComponent("session-start.sh")
    }

    private static func writeScript() throws {
        let exe = Bundle.main.executablePath ?? CommandLine.arguments[0]
        let script = """
        #!/bin/sh
        # Token Kuzatuv — Claude Code SessionStart hook (ilova yaratgan): faqat «Yangi sessiyada davom ettirish» bosilganda ishlaydi
        [ -f "\(HandoffStore.defaultURL.path)" ] || exit 0
        [ -x "\(exe)" ] || exit 0
        "\(exe)" \(flag) 2>/dev/null
        exit 0

        """
        try FileManager.default.createDirectory(at: scriptURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    static var isInstalled: Bool {
        guard let s = try? StatusLine.readSettings() else { return false }
        return entries(s).contains { isOurs($0) } && FileManager.default.isExecutableFile(atPath: scriptURL.path)
    }

    private static func entries(_ s: [String: Any]) -> [[String: Any]] {
        ((s["hooks"] as? [String: Any])?[event] as? [[String: Any]]) ?? []
    }

    private static func isOurs(_ entry: [String: Any]) -> Bool {
        ((entry["hooks"] as? [[String: Any]]) ?? []).contains { ($0["command"] as? String)?.contains(marker) == true }
    }

    /// Skript har safar yangilanadi (ilova boshqa joyga ko'chirilgan bo'lishi mumkin); settings.json — faqat kerak bo'lsa
    static func install() throws {
        try writeScript()
        var s = try StatusLine.readSettings()
        guard !entries(s).contains(where: { isOurs($0) }) else { return }
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        var list = entries(s)
        list.append(["hooks": [["type": "command", "command": "\"\(scriptURL.path)\""]]])
        hooks[event] = list
        s["hooks"] = hooks
        try StatusLine.backupOnce()
        try StatusLine.writeSettings(s)
    }

    static func uninstall() throws {
        var s = try StatusLine.readSettings()
        var hooks = s["hooks"] as? [String: Any] ?? [:]
        let list = entries(s).filter { !isOurs($0) }
        if list.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = list }
        if hooks.isEmpty { s.removeValue(forKey: "hooks") } else { s["hooks"] = hooks }
        try StatusLine.writeSettings(s)
        try? FileManager.default.removeItem(at: scriptURL)
        HandoffStore.cancel()
    }

    /// `--session-start` rejimi (Claude Code chaqiradi): xulosa bo'lsa — JSON chiqaradi, aks holda hech narsa
    static func runAndExit() -> Never {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        if let out = HandoffStore.handleSessionStart(input: data) {
            FileHandle.standardOutput.write(Data(out.utf8))
        }
        exit(0)
    }
}
